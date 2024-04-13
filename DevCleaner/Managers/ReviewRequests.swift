import StoreKit

public final class ReviewRequests {
    // MARK: Properties
    public static let shared = ReviewRequests()
    
    // MARK: Constants
    private static let bytesNeededForReviewRequest: Int64 = 21474836480 // 20 * 1024 * 1024 * 1024 = 20GB
    private static let cleansNeededForReviewRequest = 3
    
    // MARK: Showing review request
    public func requestReviewIfNeeded() {
        let totalBytesCleaned = Preferences.shared.totalBytesCleaned
        let totalCleansPerformedSinceLastRequest = Preferences.shared.cleansSinceLastReview
        
        // desired rules:
        // we show it either if we passed TOTAL of 20GB of cleaned bytes, which may be even on the first run of the app
        // or, if we clean smaller amounts, after 3 cleans
        // after we pass those 20GB total cleaned amount, we ask everytime we clean basically (limits according to system)
        if totalBytesCleaned > ReviewRequests.bytesNeededForReviewRequest || totalCleansPerformedSinceLastRequest >= ReviewRequests.cleansNeededForReviewRequest {
            SKStoreReviewController.requestReview()
            
            Preferences.shared.cleansSinceLastReview = 0
        }
    }
    
    public func showReviewOnTheAppStore() {
        guard let appStoreUrl = URL(string: "macappstore://apps.apple.com/app/id1388020431?action=write-review") else {
            log.error("ReviewRequests: Can't make a review URL!")
            return
        }
        
        NSWorkspace.shared.open(appStoreUrl)
    }
}
