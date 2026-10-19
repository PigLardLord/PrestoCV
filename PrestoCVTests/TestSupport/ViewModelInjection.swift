import Foundation
@testable import PrestoCV
@testable import PrestoCVCore

extension CVListViewModel {
    /// A list whose stored CVs change through `cvManagementUseCase`, as the app's do.
    convenience init(
        cvManagementUseCase: CVManagementUseCaseProtocol,
        now: @escaping () -> Date = { Date() },
        calendar: @escaping () -> Calendar = { .autoupdatingCurrent },
        sleep: @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.init(
            cvManagementUseCase: cvManagementUseCase,
            storedCVChanges: .init(cvs: ManagedStoredCVs(cvs: cvManagementUseCase)),
            now: now,
            calendar: calendar,
            sleep: sleep
        )
    }
}
