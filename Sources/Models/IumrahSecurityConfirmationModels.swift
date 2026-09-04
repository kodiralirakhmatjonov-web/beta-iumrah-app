import Foundation

struct IumrahSecurityConfirmation: Codable, Hashable {
    let bookingID: String
    let status: String
    let firstName: String
    let lastName: String
    let passportLast4: String
    let verificationMethod: String
    let reusedIdentity: Bool
    let submittedAt: String
    let updatedAt: String

    var isSubmitted: Bool {
        ["submitted", "confirmed", "manual_review"].contains(status.lowercased())
    }
}

struct IumrahSecurityConfirmationResponse: Decodable {
    let ok: Bool
    let confirmation: IumrahSecurityConfirmation?
}

struct IumrahSecurityConfirmationRequest: Encodable {
    let firstName: String
    let lastName: String
    let passportNumber: String
    let holderConfirmed: Bool
}
