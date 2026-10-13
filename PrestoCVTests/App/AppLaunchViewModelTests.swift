import Testing
import Foundation
@testable import PrestoCV
@testable import PrestoCVCore

// MARK: - Test Doubles

private struct StubSampleCVRepository: SampleCVRepositoryProtocol {
    func getDefaultSample() async throws -> CVModel { CVModel() }
    func getAllSamples() async throws -> [CVModel] { [] }
    func getSample(by name: String) async throws -> CVModel? { nil }
}

private struct StubOnboardingUseCase: OnboardingUseCaseProtocol {
    var onCheck: @Sendable () -> Void = {}

    func checkOnboardingRequired() async -> OnboardingState {
        onCheck()
        return .firstTime
    }

    func createFirstCV(from template: CVModel) async throws -> CVModel { template }
}

private struct StubDependencyContainer: DependencyContainerProtocol {
    var failure: Error?
    var onboardingUseCase = StubOnboardingUseCase()

    func makeOnboardingUseCase() throws -> OnboardingUseCaseProtocol {
        try failIfNeeded()
        return onboardingUseCase
    }

    func makeCVManagementUseCase() throws -> CVManagementUseCaseProtocol {
        try failIfNeeded()
        return MockCVManagementUseCase()
    }

    func makeSampleCVRepository() throws -> SampleCVRepositoryProtocol {
        try failIfNeeded()
        return StubSampleCVRepository()
    }

    func makeTemplateCategoryService() throws -> TemplateCategoryServiceProtocol {
        try failIfNeeded()
        return TemplateCategoryService()
    }

    private func failIfNeeded() throws {
        if let failure {
            throw failure
        }
    }
}

private actor CallCounter {
    private(set) var count = 0

    func increment() {
        count += 1
    }
}

@MainActor
private final class ContainerSupplier {
    private var failures: [Error?]
    private(set) var suppliedCount = 0

    /// Each call hands out the next entry: a failure makes that container refuse to build.
    init(failures: [Error?]) {
        self.failures = failures
    }

    func next() -> DependencyContainerProtocol {
        suppliedCount += 1
        let failure = failures.isEmpty ? nil : failures.removeFirst()
        return StubDependencyContainer(failure: failure)
    }
}

private let storageFailure = DependencyError.serviceCreationFailed("StorageService", AppError.unknown("disk full"))

/// Waits for the first element of the stream; false when the timeout passes first.
private func receives(_ stream: AsyncStream<Void>, within timeout: Duration) async -> Bool {
    await withTaskGroup(of: Bool.self) { group in
        group.addTask {
            for await _ in stream {
                return true
            }
            return false
        }
        group.addTask {
            try? await Task.sleep(for: timeout)
            return false
        }
        let first = await group.next() ?? false
        group.cancelAll()
        return first
    }
}

// MARK: - AppLaunchViewModel Tests

@MainActor
@Suite("AppLaunchViewModel Tests - launch without a crash")
struct AppLaunchViewModelTests {

    @Test("A container that builds gives the root dependencies")
    func containerThatBuildsGivesDependencies() {
        let supplier = ContainerSupplier(failures: [nil])

        let viewModel = AppLaunchViewModel(makeDependencyContainer: supplier.next, bootstrapTemplates: {})

        guard case .ready = viewModel.phase else {
            Issue.record("Expected the ready phase")
            return
        }
    }

    @Test("A container that cannot be built gives the reason instead of crashing")
    func containerThatFailsGivesTheReason() {
        let supplier = ContainerSupplier(failures: [storageFailure])

        let viewModel = AppLaunchViewModel(makeDependencyContainer: supplier.next, bootstrapTemplates: {})

        guard case .failed(let message) = viewModel.phase else {
            Issue.record("Expected the failed phase")
            return
        }
        #expect(message.contains("StorageService"), "The message must name what could not be built")
        #expect(message.contains("disk full"), "The message must carry the underlying reason")
    }

    @Test("Retry asks for a new container and recovers when it builds")
    func retryAsksForNewContainerAndRecovers() {
        let supplier = ContainerSupplier(failures: [storageFailure, nil])
        let viewModel = AppLaunchViewModel(makeDependencyContainer: supplier.next, bootstrapTemplates: {})

        viewModel.retry()

        guard case .ready = viewModel.phase else {
            Issue.record("Expected the ready phase after a successful retry")
            return
        }
        #expect(supplier.suppliedCount == 2, "A container remembers its first failure, so retry needs a new one")
    }

    @Test("Retry keeps showing the failure while the container still cannot be built")
    func retryKeepsFailureWhileStillFailing() {
        let supplier = ContainerSupplier(failures: [storageFailure, storageFailure])
        let viewModel = AppLaunchViewModel(makeDependencyContainer: supplier.next, bootstrapTemplates: {})

        viewModel.retry()

        guard case .failed = viewModel.phase else {
            Issue.record("Expected the failed phase")
            return
        }
    }

    @Test("start checks the onboarding state without waiting for the templates to install")
    func startDoesNotWaitForTemplates() async {
        let templatesReleased = AsyncStream<Void>.makeStream()
        let checkStarted = AsyncStream<Void>.makeStream()
        let onboardingUseCase = StubOnboardingUseCase(onCheck: { checkStarted.continuation.yield() })
        let viewModel = AppLaunchViewModel(
            makeDependencyContainer: { StubDependencyContainer(onboardingUseCase: onboardingUseCase) },
            bootstrapTemplates: {
                for await _ in templatesReleased.stream {
                    return
                }
            }
        )

        let starting = Task { await viewModel.start() }
        let checkedWhileTemplatesWereBlocked = await receives(checkStarted.stream, within: .seconds(5))
        templatesReleased.continuation.yield()
        await starting.value

        #expect(checkedWhileTemplatesWereBlocked, "The onboarding check must run while the templates are still installing")
    }

    @Test("start installs the bundled templates once and resolves the onboarding state")
    func startInstallsTemplatesAndResolvesState() async {
        let installs = CallCounter()
        let supplier = ContainerSupplier(failures: [nil])
        let viewModel = AppLaunchViewModel(
            makeDependencyContainer: supplier.next,
            bootstrapTemplates: { await installs.increment() }
        )

        await viewModel.start()

        #expect(await installs.count == 1)
        guard case .ready(let dependencies) = viewModel.phase else {
            Issue.record("Expected the ready phase")
            return
        }
        #expect(dependencies.onboardingViewModel.onboardingState == .firstTime)
    }

    @Test("start does nothing when the dependencies could not be built")
    func startDoesNothingWhenCompositionFailed() async {
        let installs = CallCounter()
        let supplier = ContainerSupplier(failures: [storageFailure])
        let viewModel = AppLaunchViewModel(
            makeDependencyContainer: supplier.next,
            bootstrapTemplates: { await installs.increment() }
        )

        await viewModel.start()

        #expect(await installs.count == 0)
    }
}
