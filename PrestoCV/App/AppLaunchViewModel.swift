import Combine
import Foundation
import PrestoCVCore
import os

private let launchLogger = Logger(subsystem: "com.PigLardLord.prestocv", category: "launch")

/// The long-lived objects behind the root screens, built once from one dependency container.
struct RootDependencies {
    let onboardingViewModel: OnboardingViewModel
    let cvListViewModel: CVListViewModel
    let viewModelFactory: ViewModelFactory
    /// Stores what earlier versions kept of unsaved editor work; nil when their folder cannot be reached.
    let leftoverEdits: LeftoverEditsImportProtocol?
}

/// Builds the app's dependencies and runs its start-up work.
///
/// A container that cannot be built is a state the user can retry, not a crash. Every retry asks
/// for a new container, because a container remembers the failure of its first attempt.
@MainActor
final class AppLaunchViewModel: ObservableObject {

    enum Phase {
        case ready(RootDependencies)
        case failed(message: String)
    }

    // MARK: - Published Properties
    @Published private(set) var phase: Phase

    // MARK: - Private Properties
    private let makeDependencyContainer: @MainActor () -> PrestoCVCore.DependencyContainerProtocol
    private let makeLeftoverEdits: LeftoverEditsMaker
    private let environment: AppEnvironment
    private let bootstrapTemplates: @Sendable () async -> Void

    /// Gives the import of what earlier versions kept, into the CVs it is given.
    typealias LeftoverEditsMaker = @MainActor (CVManagementUseCaseProtocol) throws -> LeftoverEditsImportProtocol

    // MARK: - Initialization
    /// - Parameters:
    ///   - makeLeftoverEdits: Gives the import of the unsaved edits earlier versions kept.
    ///   - environment: What the view models read from the device.
    ///   - bootstrapTemplates: Installs the templates that ship with the app.
    init(
        makeDependencyContainer: @escaping @MainActor () -> PrestoCVCore.DependencyContainerProtocol,
        makeLeftoverEdits: @escaping LeftoverEditsMaker,
        environment: AppEnvironment,
        bootstrapTemplates: @escaping @Sendable () async -> Void
    ) {
        self.makeDependencyContainer = makeDependencyContainer
        self.makeLeftoverEdits = makeLeftoverEdits
        self.environment = environment
        self.bootstrapTemplates = bootstrapTemplates
        self.phase = Self.compose(from: makeDependencyContainer(), leftoverEdits: makeLeftoverEdits, environment: environment)
    }

    // MARK: - Public Methods

    /// Stores what earlier versions kept of unsaved editor work, then checks what the root should show, while the
    /// bundled templates are installed, so a slow install never holds the list of CVs back.
    func start() async {
        guard case .ready(let dependencies) = phase else { return }

        let bootstrapTemplates = bootstrapTemplates
        async let templatesInstalled: Void = bootstrapTemplates()
        if let leftoverEdits = dependencies.leftoverEdits {
            do {
                Self.log(try await leftoverEdits.importLeftovers())
            } catch {
                // Cancelled with the launch: what is not stored yet stays for the next launch
                return
            }
        }
        await dependencies.onboardingViewModel.checkOnboardingStatus()
        await templatesInstalled
    }

    func retry() {
        phase = Self.compose(from: makeDependencyContainer(), leftoverEdits: makeLeftoverEdits, environment: environment)
    }

    // MARK: - Private Methods
    private static func compose(
        from container: PrestoCVCore.DependencyContainerProtocol,
        leftoverEdits makeLeftoverEdits: LeftoverEditsMaker,
        environment: AppEnvironment
    ) -> Phase {
        do {
            let cvManagementUseCase = LaunchEnvironment.cvs(try container.makeCVManagementUseCase(), arguments: environment.arguments)
            let viewModelFactory = try ViewModelFactory(
                dependencyContainer: container,
                cvManagementUseCase: cvManagementUseCase,
                environment: environment
            )
            return .ready(
                RootDependencies(
                    onboardingViewModel: try viewModelFactory.makeOnboardingViewModel(),
                    cvListViewModel: viewModelFactory.makeCVListViewModel(),
                    viewModelFactory: viewModelFactory,
                    leftoverEdits: leftoverEditsIfAvailable(into: cvManagementUseCase, from: makeLeftoverEdits)
                )
            )
        } catch {
            return .failed(message: error.localizedAppErrorDescription)
        }
    }

    /// The import of what earlier versions kept, or nil when their folder cannot be reached. The CVs and the editor
    /// work without it, so the launch goes on, and the next launch tries again.
    private static func leftoverEditsIfAvailable(
        into cvs: CVManagementUseCaseProtocol,
        from makeLeftoverEdits: LeftoverEditsMaker
    ) -> LeftoverEditsImportProtocol? {
        do {
            return try makeLeftoverEdits(cvs)
        } catch {
            launchLogger.error("Leftover unsaved edits cannot be reached: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Logs what the import could not do, with its step and cause, so that a full disk, a locked file and a file nobody
    /// can read are told apart.
    private static func log(_ report: LeftoverEditsImportReport) {
        for failure in report.failures {
            launchLogger.error("Leftover unsaved edits: \(String(describing: failure.step), privacy: .public) failed: \(failure.cause.localizedDescription, privacy: .private)")
        }
        if report.keptCount > 0 {
            launchLogger.error("\(report.keptCount, privacy: .public) leftover unsaved edits stay for the next launch")
        }
        if report.unreadableFiles > 0 {
            launchLogger.error("\(report.unreadableFiles, privacy: .public) leftover files could not be read as edits, and are kept")
        }
    }
}
