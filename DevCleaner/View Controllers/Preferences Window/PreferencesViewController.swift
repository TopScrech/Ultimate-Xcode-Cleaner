import Cocoa

final class PreferencesViewController: NSViewController {
    // MARK: Types
    private enum CustomLocation {
        case `default`,
             custom
    }
    
    // MARK: Properties & outlets
    @IBOutlet private weak var notificationsEnabledButton: NSButton!
    @IBOutlet private weak var notificationsPeriodPopUpButton: NSPopUpButton!
    
    @IBOutlet private weak var dryRunEnabledButton: NSButton!
    @IBOutlet private weak var xcodeWarningButton: NSButton!
    
    @IBOutlet private weak var customDerivedDataTextField: NSTextField!
    @IBOutlet private weak var customArchivesTextField: NSTextField!
    
    @IBOutlet private weak var archivesPopUpButton: NSPopUpButton!
    @IBOutlet private weak var derivedDataPopUpButton: NSPopUpButton!
    
    @IBOutlet private weak var changeCustomDerivedDataButton: NSButton!
    @IBOutlet private weak var changeCustomArchivesButton: NSButton!
    
    // MARK: Initialization & overrides
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // load preferences
        setNotificationsEnabled(Preferences.shared.notificationsEnabled)
        setNotificationsPeriod(Preferences.shared.notificationsPeriod)
        setDryRunEnabled(Preferences.shared.dryRunEnabled)
        setXcodeWarningEnabled(Preferences.shared.showXcodeWarning)
        setCustomDerivedData(folder: Preferences.shared.customDerivedDataFolder)
        setCustomArchives(folder: Preferences.shared.customArchivesFolder)
    }
    
    // MARK: Helpers
    private func chooseAndBookmarkFolder(startWith folder: URL) -> URL? {
        func doWeHaveAccess(for path: String) -> Bool {
            let fm = FileManager.default
            
            return fm.isReadableFile(atPath: path) && fm.isWritableFile(atPath: path)
        }
        
        let openPanel = NSOpenPanel()
        openPanel.directoryURL = folder
        openPanel.message = "Choose a new location"
        openPanel.prompt = "Choose"
        
        openPanel.allowedContentTypes = []
        openPanel.allowsOtherFileTypes = false
        openPanel.canChooseDirectories = true
        
        openPanel.runModal()
        
        // check if we get proper file & save bookmark to it
        if let folderUrl = openPanel.urls.first {
            if doWeHaveAccess(for: folderUrl.path) {
                if let bookmarkData = try? folderUrl.bookmarkData(options: [.withSecurityScope]) {
                    Preferences.shared.setFolderBookmark(bookmarkData: bookmarkData, for: folderUrl)
                    return folderUrl
                } else {
                    Alerts.infoAlert(
                        title: "Can't choose this folder",
                        message: "Some problem with security."
                    )
                    
                    return nil
                }
            } else {
                Alerts.infoAlert(
                    title: "Can't choose this folder",
                    message: "Access to this folder is denied."
                )
                
                return nil
            }
        }
        
        return nil
    }
    
    private func xcodeDefaultFolder(appending path: String) -> URL {
        let userName = NSUserName()
        let userHomeDirectory = URL(fileURLWithPath: "/Users/\(userName)")
        let xcodeDeveloperFolder = userHomeDirectory.appendingPathComponent("Library/Developer/Xcode", isDirectory: true)
        
        return xcodeDeveloperFolder.appendingPathComponent(path)
    }
    
    private func customFolderLocationFromTitle(_ title: String) -> CustomLocation? {
        let result: CustomLocation?
        
        switch title {
        case "Default":
            result = .default
            
        case "Custom":
            result = .custom
            
        default:
            result = nil
        }
        
        return result
    }
    
    private func titleFromCustomFolderLocation(_ location: CustomLocation) -> String {
        let result: String
        
        switch location {
        case .custom:
            result = "Custom"
            
        case .default:
            result = "Default"
        }
        
        return result
    }
    
    private func titleFromPeriod(_ period: ScanReminders.Period) -> String {
        let result: String
        switch period {
        case .everyWeek:
            result = "Every week"
        case .every2weeks:
            result = "Every 2 weeks"
        case .everyMonth:
            result = "Every month"
        case .every2Months:
            result = "Every 2 months"
            
        }
        
        return result
    }
    
    private func periodFromTitle(_ title: String) -> ScanReminders.Period? {
        let result: ScanReminders.Period?
        
        switch title {
        case "Every week":
            result = .everyWeek
            
        case "Every 2 weeks":
            result = .every2weeks
            
        case "Every month":
            result = .everyMonth
            
        case "Every 2 months":
            result = .every2Months
            
        default:
            result = nil
        }
        
        return result
    }
    
    private func setNotificationsEnabled(_ value:  Bool) {
        notificationsEnabledButton.state = value ? .on : .off
        notificationsPeriodPopUpButton.isEnabled = value
    }
    
    private func setNotificationsPeriod(_ period: ScanReminders.Period) {
        let periodTitle = titleFromPeriod(period)
        
        notificationsPeriodPopUpButton.selectItem(withTitle: periodTitle)
    }
    
    private func setDryRunEnabled(_ value: Bool) {
        dryRunEnabledButton.state = value ? .on : .off
    }
    
    private func setXcodeWarningEnabled(_ value: Bool) {
        xcodeWarningButton.state = value ? .on : .off
    }
    
    private func setCustomDerivedData(folder: URL?) {
        if let customFolder = folder {
            customDerivedDataTextField.stringValue = customFolder.path
            customDerivedDataTextField.toolTip = customFolder.path
            
            derivedDataPopUpButton.selectItem(withTitle: titleFromCustomFolderLocation(.custom))
            customDerivedDataTextField.isEnabled = true
            changeCustomDerivedDataButton.isEnabled = true
        } else {
            let defaultFolder = xcodeDefaultFolder(appending: "DerivedData").path
            customDerivedDataTextField.stringValue = defaultFolder
            customDerivedDataTextField.toolTip = defaultFolder
            
            derivedDataPopUpButton.selectItem(withTitle: titleFromCustomFolderLocation(.default))
            changeCustomDerivedDataButton.isEnabled = false
            customDerivedDataTextField.isEnabled = false
        }
    }
    
    private func setCustomArchives(folder: URL?) {
        if let customFolder = folder {
            customArchivesTextField.stringValue = customFolder.path
            customArchivesTextField.toolTip = customFolder.path
            
            archivesPopUpButton.selectItem(withTitle: titleFromCustomFolderLocation(.custom))
            customArchivesTextField.isEnabled = true
            changeCustomArchivesButton.isEnabled = true
        } else {
            let defaultFolder = xcodeDefaultFolder(appending: "Archives").path
            customArchivesTextField.stringValue = defaultFolder
            customArchivesTextField.toolTip = defaultFolder
            
            archivesPopUpButton.selectItem(withTitle: titleFromCustomFolderLocation(.default))
            customArchivesTextField.isEnabled = false
            changeCustomArchivesButton.isEnabled = false
        }
    }
    
    // MARK: Actions
    @IBAction func updateNotificationsEnabled(_ sender: NSButton) {
        let enabled = sender.state == .on
        
        setNotificationsEnabled(enabled)
        
        Preferences.shared.notificationsEnabled = enabled
        
        if enabled {
            ScanReminders.scheduleReminder(period: Preferences.shared.notificationsPeriod)
        } else {
            ScanReminders.disableReminder()
        }
    }
    
    @IBAction func updatePeriod(_ sender: NSPopUpButton) {
        guard let selectedItem = sender.selectedItem else {
            return
        }
        
        guard let selectedPeriod = periodFromTitle(selectedItem.title) else {
            return
        }
        
        Preferences.shared.notificationsPeriod = selectedPeriod
        ScanReminders.scheduleReminder(period: Preferences.shared.notificationsPeriod)
    }
    
    @IBAction func updateDryRun(_ sender: NSButton) {
        let enabled = sender.state == .on
        
        setDryRunEnabled(enabled)
        
        Preferences.shared.dryRunEnabled = enabled
    }
    
    @IBAction func updateXcodeWarning(_ sender: NSButton) {
        let enabled = sender.state == .on
        
        setXcodeWarningEnabled(enabled)
        
        Preferences.shared.showXcodeWarning = enabled
    }
    
    @IBAction func changeDerivedDataFolder(_ sender: NSPopUpButton) {
        guard let selectedItem = sender.selectedItem else {
            return
        }
        
        guard let location = customFolderLocationFromTitle(selectedItem.title) else {
            return
        }
        
        switch location {
        case .default:
            Preferences.shared.customDerivedDataFolder = nil
            
            changeCustomDerivedDataButton.isEnabled = false
            customDerivedDataTextField.isEnabled = false
            customDerivedDataTextField.stringValue = xcodeDefaultFolder(appending: "DerivedData").path
        case .custom:
            let folderUrl = URL(fileURLWithPath: customDerivedDataTextField.stringValue, isDirectory: true)
            Preferences.shared.customDerivedDataFolder = folderUrl
            
            customDerivedDataTextField.isEnabled = true
            changeCustomDerivedDataButton.isEnabled = true
        }
    }
    
    @IBAction func changeArchivesFolder(_ sender: NSPopUpButton) {
        guard let selectedItem = sender.selectedItem else {
            return
        }
        
        guard let location = customFolderLocationFromTitle(selectedItem.title) else {
            return
        }
        
        switch location {
        case .default:
            Preferences.shared.customArchivesFolder = nil
            
            changeCustomArchivesButton.isEnabled = false
            customArchivesTextField.isEnabled = false
            customArchivesTextField.stringValue = xcodeDefaultFolder(appending: "Archives").path
            
        case .custom:
            let folderUrl = URL(fileURLWithPath: customArchivesTextField.stringValue, isDirectory: true)
            Preferences.shared.customArchivesFolder = folderUrl
            
            customArchivesTextField.isEnabled = true
            changeCustomArchivesButton.isEnabled = true
        }
    }
    
    @IBAction func selectCustomDerivedDataFolder(_ sender: NSButton) {
        let startFolder = URL(fileURLWithPath: customDerivedDataTextField.stringValue, isDirectory: true)
        
        if let selectedDerivedDataFolder = chooseAndBookmarkFolder(startWith: startFolder) {
            Preferences.shared.customDerivedDataFolder = selectedDerivedDataFolder
            
            customDerivedDataTextField.stringValue = selectedDerivedDataFolder.path
        }
    }
    
    @IBAction func selectCustomArchivesFolder(_ sender: NSButton) {
        let startFolder = URL(fileURLWithPath: customArchivesTextField.stringValue, isDirectory: true)
        
        if let selectedArchivesFolder = chooseAndBookmarkFolder(startWith: startFolder) {
            Preferences.shared.customArchivesFolder = selectedArchivesFolder
            
            customArchivesTextField.stringValue = selectedArchivesFolder.path
        }
    }
}
