import Foundation
import Testing
@testable import Unhook

struct FounderLinksTests {
    @Test func writeReviewURLUsesTheNumericAppID() {
        let url = FounderLinks.writeReviewURL(appID: "1234567890")
        #expect(url?.absoluteString == "https://apps.apple.com/app/id1234567890?action=write-review")
    }

    @Test func writeReviewURLIsNilWithoutAValidAppID() {
        #expect(FounderLinks.writeReviewURL(appID: nil) == nil)
        #expect(FounderLinks.writeReviewURL(appID: "") == nil)
        #expect(FounderLinks.writeReviewURL(appID: "<APPLE_ID>") == nil)
    }

    @Test func writeReviewMatchesTheConfiguredAppID() {
        #expect(FounderLinks.writeReview == FounderLinks.writeReviewURL(appID: FounderLinks.appStoreID))
    }
}
