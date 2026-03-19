import Foundation
import SwiftData

@Model
final class UserProfile {
    var appleUserID: String
    var fullName: String
    var email: String
    var createdAt: Date
    var hasCompletedOnboarding: Bool

    init(
        appleUserID: String,
        fullName: String = "",
        email: String = "",
        createdAt: Date = Date(),
        hasCompletedOnboarding: Bool = false
    ) {
        self.appleUserID = appleUserID
        self.fullName = fullName
        self.email = email
        self.createdAt = createdAt
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }
}
