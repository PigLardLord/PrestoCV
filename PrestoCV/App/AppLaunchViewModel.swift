import Combine
import Foundation
import PrestoCVCore
import os

private let launchLogger = Logger(subsystem: "com.PigLardLord.prestocv", category: "launch")

/// The long-lived objects behind the root screens, built once from one dependency container.
struct RootDependencies {
    let onboardingViewModel: OnboardingViewModel
    let cvListViewModel: CVListViewModel
    let unsavedEditsOfferViewModel: UnsavedEditsOfferViewModel
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
    private let environment: AppEnvironment
    private let bootstrapTemplates: @Sendable () async -> Void

    // MARK: - Initialization
    /// - Parameters:
    ///   - makeUnsavedEdits: Gives the unsaved edits of the app, which every window shares.
    ///   - environment: What the view models read from the device.
    ///   - bootstrapTemplates: Installs the templates that ship with the app.
    init(
        makeDependencyContainer: @escaping @MainActor () -> PrestoCVCore.DependencyContainerProtocol,
        makeUnsavedEdits: @escaping @MainActor () throws -> UnsavedEditsUseCaseProtocol,
        environment: AppEnvironment,
        bootstrapTemplates: @escaping @Sendable () async -> Void
    ) {
        self.makeDependencyContainer = makeDependencyContainer
        self.makeUnsavedEdits = makeUnsavedEdits
        self.environment = environment
        self.bootstrapTemplates = bootstrapTemplates
        self.phase = Self.compose(from: makeDependencyContainer(), unsavedEdits: makeUnsavedEdits, environment: environment)
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
        phase = Self.compose(from: makeDependencyContainer(), unsavedEdits: makeUnsavedEdits, environment: environment)
    }

    // MARK: - Private Methods
    private static func compose(
        from container: PrestoCVCore.DependencyContainerProtocol,
        unsavedEdits makeUnsavedEdits: @MainActor () throws -> UnsavedEditsUseCaseProtocol,
        environment: AppEnvironment
    ) -> Phase {
        do {
            let cvManagementUseCase = try container.makeCVManagementUseCase()
            let unsavedEditsUseCase = unsavedEditsIfAvailable(from: makeUnsavedEdits)
            let viewModelFactory = try ViewModelFactory(
                dependencyContainer: container,
                cvManagementUseCase: cvManagementUseCase,
                unsavedEditsUseCase: unsavedEditsUseCase,
                environment: environment
            )
            return .ready(
                RootDependencies(
                    onboardingViewModel: try viewModelFactory.makeOnboardingViewModel(),
                    cvListViewModel: viewModelFactory.makeCVListViewModel(),
                    unsavedEditsOfferViewModel: viewModelFactory.makeUnsavedEditsOfferViewModel(),
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
