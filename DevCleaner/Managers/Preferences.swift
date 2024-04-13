import Foundation
import CryptoKit

// MARK: Preferences Observer
@objc public protocol PreferencesObserver: AnyObject {
    func preferenceDidChange(key: String)
}

// MARK: - Preferences Class
public final class Preferences {
    // MARK: Keys
    public struct Keys {
        public static let notificationsEnabled = "DCNotificationsEnabledKey"
        public static let notificationsPeriod = "DCNotificationsPeriodKey"
        public static let dryRunEnabled = "DCDryRunEnabledKey"
        public static let totalBytesCleaned = "DCTotalBytesCleaned"
        public static let cleansSinceLastReview = "DCCleansSinceLastReview"
        public static let customArchivesFolder = "DCCustomArchivesFolderKey"
        public static let customDerivedDataFolder = "DCCustomDerivedDataFolderKey"
        public static let appFolder = "DCAppFolder"
        public static let showXcodeWarning = "DCShowXcodeWarning"
        
        fileprivate static func folderBookmarkKey(for url: URL) -> String {
            let urlStringData = Data(url.path.utf8)
            let sha256hash = SHA256.hash(data: urlStringData)
            
            return "DCFolderBookmark_\(sha256hash.hexStr)"
        }
    }
    
    // MARK: Properties & constants
    public static let shared = Preferences()
    
    private var observers = [Weak<PreferencesObserver>]()
    
    // MARK: Initialization
    public init() {
        
    }
    
    // MARK: Observers
    public func addObserver(_ observer: PreferencesObserver) {
        let weakObserver = Weak(value: observer)
        
        if !observers.contains(weakObserver) {
            observers.append(weakObserver)
        }
    }
    
    public func removeObserver(_ observer: PreferencesObserver) {
        let weakObserverToRemove = Weak(value: observer)
        
        observers.removeAll { (observer) -> Bool in
            return observer == weakObserverToRemove
        }
    }
    
    private func informAllObserversAboutChange(keyThatChanged: String) {
        for observer in observers {
            observer.value?.preferenceDidChange(key: keyThatChanged)
        }
    }
    
    // MARK: Environment
    public func envValue(key: String) -> String? {
        ProcessInfo.processInfo.environment[key]
    }
    
    public func envKeyPresent(key: String) -> Bool {
        ProcessInfo.processInfo.environment.keys.contains(key)
    }
    
    // MARK: Options
    public var notificationsEnabled: Bool {
        get {
            guard UserDefaults.standard.object(forKey: Keys.notificationsEnabled) != nil else {
                return true // default value
            }
            
            return UserDefaults.standard.bool(forKey: Keys.notificationsEnabled)
        }
        
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.notificationsEnabled)
            informAllObserversAboutChange(keyThatChanged: Keys.notificationsEnabled)
        }
    }
    
    public var notificationsPeriod: ScanReminders.Period {
        get {
            guard UserDefaults.standard.object(forKey: Keys.notificationsPeriod) != nil else {
                return .everyMonth
            }
            
            let periodInt = UserDefaults.standard.integer(forKey: Keys.notificationsPeriod)
            
            guard let period = ScanReminders.Period(rawValue: periodInt) else {
                return .everyMonth
            }
            
            return period
        }
        
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Keys.notificationsPeriod)
            informAllObserversAboutChange(keyThatChanged: Keys.notificationsPeriod)
        }
    }
    
    public var dryRunEnabled: Bool {
        get {
            guard UserDefaults.standard.object(forKey: Keys.dryRunEnabled) != nil else {
#if DEBUG
                return true // default value
#else
                return false
#endif
            }
            
            return UserDefaults.standard.bool(forKey: Keys.dryRunEnabled)
        }
        
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.dryRunEnabled)
            informAllObserversAboutChange(keyThatChanged: Keys.dryRunEnabled)
        }
    }
    
    public var totalBytesCleaned: Int64 {
        get {
            if let value = UserDefaults.standard.object(forKey: Keys.totalBytesCleaned) as? NSNumber {
                return value.int64Value
            }
            
            return 0
        }
        
        set {
            let numberValue = NSNumber(value: newValue)
            UserDefaults.standard.set(numberValue, forKey: Keys.totalBytesCleaned)
            
            informAllObserversAboutChange(keyThatChanged: Keys.totalBytesCleaned)
        }
    }
    
    public var cleansSinceLastReview: Int {
        get {
            if let value = UserDefaults.standard.object(forKey: Keys.cleansSinceLastReview) as? NSNumber {
                return value.intValue
            }
            
            return 0
        }
        
        set {
            let numberValue = NSNumber(value: newValue)
            UserDefaults.standard.set(numberValue, forKey: Keys.cleansSinceLastReview)
            
            informAllObserversAboutChange(keyThatChanged: Keys.cleansSinceLastReview)
        }
    }
    
    public var customArchivesFolder: URL? {
        get {
            if let archivesPath = UserDefaults.standard.object(forKey: Keys.customArchivesFolder) as? String {
                return URL(fileURLWithPath: archivesPath)
            }
            
            return nil
        }
        
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.customArchivesFolder)
            informAllObserversAboutChange(keyThatChanged: Keys.customArchivesFolder)
        }
    }
    
    public var customDerivedDataFolder: URL? {
        get {
            if let derivedDataPath = UserDefaults.standard.object(forKey: Keys.customDerivedDataFolder) as? String {
                return URL(fileURLWithPath: derivedDataPath)
            }
            
            return nil
        }
        
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.customDerivedDataFolder)
            informAllObserversAboutChange(keyThatChanged: Keys.customDerivedDataFolder)
        }
    }
    
    public var appFolder: URL {
        get {
            if let appFolderPath = UserDefaults.standard.object(forKey: Keys.appFolder) as? String {
                return URL(fileURLWithPath: appFolderPath)
            }
            
            return Bundle.main.bundleURL
        }
        
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.appFolder)
            informAllObserversAboutChange(keyThatChanged: Keys.appFolder)
        }
    }
    
    public var showXcodeWarning: Bool {
        get {
            guard UserDefaults.standard.object(forKey: Keys.showXcodeWarning) != nil else {
                return true
            }
            
            return UserDefaults.standard.bool(forKey: Keys.showXcodeWarning)
        }
        
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.showXcodeWarning)
            informAllObserversAboutChange(keyThatChanged: Keys.showXcodeWarning)
        }
    }
    
    // MARK: Folder bookmarks
    public func folderBookmark(for url: URL) -> Data? {
        let key = Keys.folderBookmarkKey(for: url)
        
        return UserDefaults.standard.data(forKey: key)
    }
    
    public func setFolderBookmark(bookmarkData: Data?, for url: URL) {
        let key = Keys.folderBookmarkKey(for: url)
        
        UserDefaults.standard.set(bookmarkData, forKey: key)
    }
}
