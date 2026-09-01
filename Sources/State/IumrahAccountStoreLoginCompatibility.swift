import Foundation

// Compatibility bridge for repositories where IumrahAccountView still uses
// the older `login(iumrahID:password:)` call site while IumrahAccountStore
// has already migrated to `login(identifier:password:locale:)`.
//
// This keeps the hotfix surgical: it does not replace Account UI or account
// state files and can safely remain after those call sites are migrated.
extension IumrahAccountStore {
    @discardableResult
    func login(iumrahID: String, password: String) async throws -> IumrahAccountProfile {
        try await login(identifier: iumrahID, password: password)
    }
}
