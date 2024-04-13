import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: App configuration
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
    
    // MARK: App lifetime events
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // register as transactions observer
        Donations.shared.startObservingTransactionsQueue()
        
        // update notifications
        if Preferences.shared.notificationsEnabled {
            ScanReminders.scheduleReminder(period: Preferences.shared.notificationsPeriod)
        } else {
            ScanReminders.disableReminder()
        }
        
        // information about upcoming notifications
        if let upcomingReminderDate = ScanReminders.dateOfNextReminder {
            log.info("Next reminder: \(upcomingReminderDate.description(with: Locale.current))")
        } else {
            log.info("No reminder scheduled!")
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    // MARK: Actions
    @IBAction func openAppReview(_ sender: Any) {
        ReviewRequests.shared.showReviewOnTheAppStore()
    }
    
    @IBAction func showLogFiles(_ sender: Any) {
        // logs folder
        guard let logsUrl = log.logFilePath?.deletingLastPathComponent() else {
            return
        }
        
        NSWorkspace.shared.open(logsUrl)
    }
    
    @IBAction func installCommandLineTool(_ sender: Any) {
        guard let commandLineToolInstallInstructionsURL = URL(string: "https://github.com/vashpan/xcode-dev-cleaner/blob/566afe767c90001ba397f5907df11e09c68a1634/Documentation/Command%20Line%20Tool.md") else { return }
        NSWorkspace.shared.open(commandLineToolInstallInstructionsURL)
    }
    
    @IBAction func sendFeedback(_ sender: Any) {
        FeedbackMailer.shared.sendFeedback()
    }
    
    @IBAction func reportAnIssue(_ sender: Any) {
        FeedbackMailer.shared.reportAnIssue()
    }
}
