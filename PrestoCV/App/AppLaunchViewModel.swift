import Combine
import Foundation
import PrestoCVCore
import CVPDFExporter
import os

private let launchLogger = Logger(subsystem: "com.PigLardLord.prestocv", category: "launch")

/// Installs the templates that ship with the app. A failure is logged and does not block the launch.
func installBundledTemplates() async {
    do {
        let bootstrapService = try TemplateBootstrapService()
        try await bootstrapService.syncBundledTemplates()
    } catch {
        launchLogger.error("Bundled templates were not installed: \(error.localizedDescription, privacy: .public)")
    }
}

/// The long-lived objects behind the root screens, built once from one dependency container.
struct RootDependencies {
    let onboardingViewModel: OnboardingViewModel
    let cvListViewModel: CVListViewModel
    let unsavedEditsOfferViewModel: UnsavedEditsOfferViewModel
    let cvManagementUseCase: CVManagementUseCaseProtocol
    /// Nil when the unsaved edits cannot be kept on this device: the app works without them.
    let unsavedEditsUseCase: UnsavedEditsUseCaseProtocol?
    let viewModelFactory: ViewModelFactory
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
    private let makeUnsavedEdits: @MainActor () throws -> UnsavedEditsUseCaseProtocol
    private let bootstrapTemplates: @Sendable () async -> Void

    // MARK: - Initialization
    /// - Parameter makeUnsavedEdits: Gives the unsaved edits of the app, which every window shares.
    init(
        makeDependencyContainer: @escaping @MainActor () -> PrestoCVCore.DependencyContainerProtocol,
        makeUnsavedEdits: @escaping @MainActor () throws -> UnsavedEditsUseCaseProtocol,
        bootstrapTemplates: @escaping @Sendable () async -> Void = { await installBundledTemplates() }
    ) {
        self.makeDependencyContainer = makeDependencyContainer
        self.makeUnsavedEdits = makeUnsavedEdits
        self.bootstrapTemplates = bootstrapTemplates
        self.phase = Self.compose(from: makeDependencyContainer(), unsavedEdits: makeUnsavedEdits)
    }

    // MARK: - Public Methods

    /// Checks what the root should show while the bundled templates are installed, so a slow
    /// install never holds the list of CVs back.
    func start() async {
        guard case .ready(let dependencies) = phase else { return }

        let bootstrapTemplates = bootstrapTemplates
        async let templatesInstalled: Void = bootstrapTemplates()
        await dependencies.onboardingViewModel.checkOnboardingStatus()
        await templatesInstalled
    }

    func retry() {
        phase = Self.compose(from: makeDependencyContainer(), unsavedEdits: makeUnsavedEdits)
    }

    // MARK: - Private Methods
    private static func compose(
        from container: PrestoCVCore.DependencyContainerProtocol,
        unsavedEdits makeUnsavedEdits: @MainActor () throws -> UnsavedEditsUseCaseProtocol
    ) -> Phase {
        do {
            let viewModelFactory = try ViewModelFactory(dependencyContainer: container)
            let cvManagementUseCase = try container.makeCVManagementUseCase()
            let unsavedEditsUseCase = unsavedEditsIfAvailable(from: makeUnsavedEdits)
            return .ready(
                RootDependencies(
                    onboardingViewModel: try viewModelFactory.makeOnboardingViewModel(),
                    cvListViewModel: CVListViewModel(cvManagementUseCase: cvManagementUseCase),
                    unsavedEditsOfferViewModel: UnsavedEditsOfferViewModel(useCase: unsavedEditsUseCase, cvs: cvManagementUseCase),
                    cvManagementUseCase: cvManagementUseCase,
                    unsavedEditsUseCase: unsavedEditsUseCase,
                    viewModelFactory: viewModelFactory
                )
            )
        } catch {
            return .failed(message: error.localizedAppErrorDescription)
        }
    }

    /// The unsaved edits of the app, or nil when they cannot be kept, as when their folder cannot be made. Keeping
    /// them is a safety net: the CVs and the editor work without it, so the launch goes on.
    private static func unsavedEditsIfAvailable(
        from makeUnsavedEdits: @MainActor () throws -> UnsavedEditsUseCaseProtocol
    ) -> UnsavedEditsUseCaseProtocol? {
        do {
            return try makeUnsavedEdits()
        } catch {
            launchLogger.error("Unsaved edits will not be kept: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
