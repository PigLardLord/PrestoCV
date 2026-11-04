import Foundation
import os.log

/// Manages a pool of PDF renderers for optimal resource usage
/// Implements renderer recycling to avoid repeated initialization overhead
public actor PDFRendererPool {

    // MARK: - Properties

    private let logger = Logger(subsystem: "CVPDFExporter", category: "RendererPool")
    private var availableRenderers: [PDFRendererProtocol] = []
    private var activeRenderers: Set<ObjectIdentifier> = []
    private let maxPoolSize: Int
    private let configuration: RendererConfiguration
    private var totalCreated = 0
    private var reusedCount = 0

    // MARK: - Initialization

    public init(maxPoolSize: Int = 3, configuration: RendererConfiguration = .production) {
        self.maxPoolSize = maxPoolSize
        self.configuration = configuration
        logger.debug("Renderer pool initialized with max size: \(maxPoolSize)")
    }

    // MARK: - Public Methods

    /// Acquires a renderer from the pool
    /// - Returns: A PDF renderer ready for use
    public func acquire() async -> PDFRendererProtocol {
        // Try to reuse an existing renderer
        if !availableRenderers.isEmpty {
            let renderer = availableRenderers.removeFirst()
            activeRenderers.insert(ObjectIdentifier(renderer))
            reusedCount += 1
            logger.debug("Reusing renderer from pool (reused: \(self.reusedCount) times)")
            return renderer
        }

        // Create new renderer if under limit
        if totalCreated < maxPoolSize {
            let renderer = await PDFRendererFactory.createRenderer(configuration: configuration)
            activeRenderers.insert(ObjectIdentifier(renderer))
            totalCreated += 1
            logger.debug("Created new renderer (total: \(self.totalCreated))")
            return renderer
        }

        // Wait for a renderer to become available
        logger.info("Pool exhausted, waiting for renderer...")
        while availableRenderers.isEmpty {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }

        return await acquire()
    }

    /// Returns a renderer to the pool for reuse
    /// - Parameter renderer: The renderer to return
    public func release(_ renderer: PDFRendererProtocol) {
        let id = ObjectIdentifier(renderer)

        guard activeRenderers.contains(id) else {
            logger.warning("Attempted to release unknown renderer")
            return
        }

        activeRenderers.remove(id)

        // Clean up renderer if needed
        if let cleanable = renderer as? CleanableRenderer {
            Task {
                await cleanable.cleanup()
            }
        }

        // Return to pool if under limit
        if availableRenderers.count < maxPoolSize {
            availableRenderers.append(renderer)
            logger.debug("Renderer returned to pool (available: \(self.availableRenderers.count))")
        } else {
            logger.debug("Pool full, discarding renderer")
        }
    }

    /// Drains the pool, releasing all resources
    public func drain() async {
        logger.info("Draining renderer pool...")

        // Clean up available renderers
        for renderer in availableRenderers {
            if let cleanable = renderer as? CleanableRenderer {
                await cleanable.cleanup()
            }
        }

        availableRenderers.removeAll()
        activeRenderers.removeAll()

        logger.info("Pool drained (created: \(self.totalCreated), reused: \(self.reusedCount) times)")
    }

    /// Gets current pool statistics
    public func getStatistics() -> PoolStatistics {
        PoolStatistics(
            totalCreated: totalCreated,
            reusedCount: reusedCount,
            available: availableRenderers.count,
            active: activeRenderers.count,
            maxSize: maxPoolSize
        )
    }
}

// MARK: - Supporting Types

/// Statistics about renderer pool usage
public struct PoolStatistics: Sendable {
    public let totalCreated: Int
    public let reusedCount: Int
    public let available: Int
    public let active: Int
    public let maxSize: Int

    public var reuseRate: Double {
        guard totalCreated > 0 else { return 0 }
        return Double(reusedCount) / Double(totalCreated + reusedCount)
    }
}

/// Protocol for renderers that can be cleaned up
protocol CleanableRenderer: AnyObject, Sendable {
    func cleanup() async
}

// MARK: - Renderer Pool Manager

/// Manages multiple renderer pools for different use cases
public actor RendererPoolManager {

    private let logger = Logger(subsystem: "CVPDFExporter", category: "PoolManager")
    private var pools: [String: PDFRendererPool] = [:]

    /// Gets or creates a pool for the specified key
    public func pool(for key: String, maxSize: Int = 3) -> PDFRendererPool {
        if let existingPool = pools[key] {
            return existingPool
        }

        let newPool = PDFRendererPool(maxPoolSize: maxSize)
        pools[key] = newPool
        logger.debug("Created new pool for key: \(key)")
        return newPool
    }

    /// Drains all pools
    public func drainAll() async {
        logger.info("Draining all pools...")
        for (key, pool) in pools {
            logger.debug("Draining pool: \(key)")
            await pool.drain()
        }
        pools.removeAll()
    }

    /// Gets statistics for all pools
    public func getAllStatistics() async -> [String: PoolStatistics] {
        var stats: [String: PoolStatistics] = [:]
        for (key, pool) in pools {
            stats[key] = await pool.getStatistics()
        }
        return stats
    }
}

// MARK: - Convenience Extensions

public extension PDFRendererPool {

    /// Executes a closure with a renderer from the pool
    /// - Parameter block: The closure to execute with the renderer
    /// - Returns: The result of the closure
    func withRenderer<T>(_ block: (PDFRendererProtocol) async throws -> T) async rethrows -> T {
        let renderer = await acquire()
        // The pool is an actor and release is synchronous: the renderer is back as soon as the block ends.
        defer { release(renderer) }
        return try await block(renderer)
    }
}