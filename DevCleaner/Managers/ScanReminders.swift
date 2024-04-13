import NotificationCenter

public final class ScanReminders {
    // MARK: Types
    public enum Period: Int {
        case everyWeek, 
             every2weeks, 
             everyMonth,
             every2Months
        
        private var dateComponents: DateComponents {
            var result = DateComponents()
            
            switch self {
            case .everyWeek:
                result.day = 7
                
            case .every2weeks:
                result.day = 14
                
            case .everyMonth:
                result.month = 1
                
            case .every2Months:
                result.month = 2
            }
            
            return result
        }
        
        internal var repeatInterval: DateComponents {
            var result = DateComponents()
            
#if DEBUG
            if Preferences.shared.envKeyPresent(key: "DCNotificationsTest") {
                result.day = 1 // for debug we change our periods to one day
            } else {
                result = dateComponents
            }
#else
            result = dateComponents
#endif
            
            return result
        }
    }
    
    // MARK: Properties
    public static var dateOfNextReminder: Date? {
        if let firstScheduledNotification = NSUserNotificationCenter.default.scheduledNotifications.first {
            firstScheduledNotification.deliveryDate
        } else {
            nil
        }
    }
    
    // MARK: Constants
    private static let reminderIdentifier = "com.oneminutegames.DevCleaner.scanReminder"
    
    // MARK: Manage reminders
    public static func scheduleReminder(period: Period) {
        // notification
        let notification = NSUserNotification()
        notification.identifier = reminderIdentifier
        notification.title = "Scan Xcode cache?"
        notification.informativeText = "It's been a while since your last scan, check if you can reclaim some storage."
        notification.soundName = NSUserNotificationDefaultSoundName
        
        // buttons
        notification.hasActionButton = true
        notification.otherButtonTitle = "Close"
        notification.actionButtonTitle = "Scan"
        
        // schedule & repeat periodically
        if let initialDeliveryDate = NSCalendar.current.date(byAdding: period.repeatInterval, to: Date()) {
            notification.deliveryDate = initialDeliveryDate
            notification.deliveryRepeatInterval = period.repeatInterval
        }
        
        // schedule a notification
        let notificationCenter = NSUserNotificationCenter.default
        notificationCenter.scheduleNotification(notification)
    }
    
    public static func disableReminder() {
        NSUserNotificationCenter.default.scheduledNotifications = []
    }
}
