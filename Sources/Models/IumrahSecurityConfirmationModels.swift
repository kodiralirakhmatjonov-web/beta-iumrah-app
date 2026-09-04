import Foundation

struct IumrahSecurityConfirmation: Codable, Hashable {
    let bookingID: String
    let status: String
    let firstName: String
    let lastName: String
    let passportLast4: String
    let verificationMethod: String
    let reusedIdentity: Bool
    let hasPassportPhoto: Bool
    let reviewNote: String
    let submittedAt: String
    let updatedAt: String

    var normalizedStatus: String { status.lowercased() }
    var isConfirmed: Bool { normalizedStatus == "confirmed" }
    var isPendingReview: Bool { ["submitted", "under_review"].contains(normalizedStatus) }
    var needsResubmission: Bool { ["rejected", "needs_resubmission"].contains(normalizedStatus) }
    var isDraft: Bool { normalizedStatus == "draft" }
    var isSubmitted: Bool { isPendingReview || isConfirmed }
    var canEdit: Bool { !isConfirmed && !isPendingReview }
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
