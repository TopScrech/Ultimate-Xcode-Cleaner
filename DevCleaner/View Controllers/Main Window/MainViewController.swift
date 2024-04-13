import StoreKit

final class MainViewController: NSViewController {
    // MARK: Types
    private enum OutlineViewColumnsIdentifiers: String {
        case itemColumn = "ItemColumn",
             sizeColumn = "SizeColumn"
        
        var identifier: NSUserInterfaceItemIdentifier {
            .init(rawValue)
        }
    }
    
    private enum OutlineViewCellIdentifiers: String {
        case itemCell = "ItemCell",
             sizeCell = "SizeCell"
        
        var identifier: NSUserInterfaceItemIdentifier {
            .init(rawValue)
        }
    }
    
    private enum Segue: String {
        case showCleaningView = "ShowCleaningView",
             showDonateView = "ShowDonateView"
        
        var segueIdentifier: NSStoryboardSegue.Identifier {
            rawValue
        }
    }
    
    // MARK: Properties & outlets
    @IBOutlet private weak var bytesSelectedTextField: NSTextField!
    @IBOutlet private weak var totalBytesTextField: NSTextField!
    
    @IBOutlet private weak var progressIndicator: NSProgressIndicator!
    @IBOutlet private weak var cleanButton: NSButton!
    @IBOutlet private weak var benefitsTextField: NSTextField!
    @IBOutlet private weak var tipMeButton: NSButton!
    
    @IBOutlet weak var accessWarningsView: NSView!
    @IBOutlet weak var accessWarningTitle: NSTextField!
    @IBOutlet weak var accessWarningContent: NSTextField!
    @IBOutlet weak var accessWarningButton: NSButton!
    
    @IBOutlet private weak var outlineView: NSOutlineView!
    
    private weak var dryModeView: NSView!
    
    private var xcodeFiles: XcodeFiles?
    private var loaded = false
    
    // MARK: Initialization & overrides
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // observe preferences
        Preferences.shared.addObserver(self)
        
        disableAccessWarnings()
        
        // open ~/Library/Developer folder, create XcodeFiles instance and start scanning
        if XcodeFiles.isDeveloperFolderExists() {
            setupXcodeFilesAndStartScanningIfNeeded()
        } else {
            enableAccessWarnings(
                title: "\"~/Developer\" folder cannot be found",
                content: "DevCleaner main function is to clean unnecessary files in this folder. Without it, it won't be very useful. This folder is usually created by Xcode during work. Make sure you've installed it.",
                buttonTitle: "Download Xcode",
                buttonActionSelector: #selector(downloadXcode(_:))
            )
        }
        
        // set all time saved bytes label
        benefitsTextField.attributedStringValue = benefitsLabelAttributedString(totalBytesCleaned: Preferences.shared.totalBytesCleaned)
    }
    
    deinit {
        Preferences.shared.removeObserver(self)
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        // UI refresh
        updateButtonsAndLabels()
        
        // notify about Xcode being open
        let showXcodeWarning = Preferences.shared.showXcodeWarning
        
        if showXcodeWarning && XcodeFiles.isXcodeRunning() {
            Alerts.warningAlert(
                title: "Xcode is open",
                message: "DevCleaner can run with Xcode being opened, but cleaning some files may affect Xcode functions and maybe even cause its crash.",
                okButtonText: "Continue",
                cancelButtonText: "Close DevCleaner"
            ) { messageResult in
                if messageResult == .alertSecondButtonReturn {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        
        view.window?.delegate = self
    }
    
    override func keyUp(with event: NSEvent) {
        if event.keyCode == 49 { // spacebar
            let selectedRow = outlineView.selectedRow
            
            if let selectedEntry = outlineView.item(atRow: selectedRow) as? XcodeFileEntry,
               let selectedCellView = outlineView.view(atColumn: 0, row: selectedRow, makeIfNecessary: false) as? XcodeEntryCellView {
                let targetStateValue: NSControl.StateValue
                
                switch selectedEntry.selection {
                case .on:
                    targetStateValue = .off
                    
                case .off:
                    targetStateValue = .on
                    
                case .mixed:
                    targetStateValue = .on
                }
                
                xcodeEntryCellSelectedChanged(selectedCellView, state: targetStateValue, xcodeEntry: selectedEntry)
                
                outlineView.selectRowIndexes([selectedRow], byExtendingSelection: false)
            }
        }
        
        super.keyUp(with: event)
    }
    
    // MARK: Navigation
    private func prepareCleaningView(with segue: NSStoryboardSegue) {
        if let cleaningViewController = segue.destinationController as? CleaningViewController {
            cleaningViewController.state = .idle(title: "Initialization...", progress: 0.0)
            cleaningViewController.delegate = self
            
            xcodeFiles?.deleteDelegate = cleaningViewController
        }
    }
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        guard let identifier = segue.identifier, let segueId = Segue(rawValue: identifier) else {
            log.warning("MainViewController: Unrecognized segue: \(segue)")
            return
        }
        
        switch segueId {
        case .showCleaningView:
            prepareCleaningView(with: segue)
            
        case .showDonateView:
            break // nothing to be done here
        }
    }
    
    // MARK: Helpers
    private func setupXcodeFilesAndStartScanningIfNeeded() {
        guard xcodeFiles == nil else {
            return
        }
        
        // reset custom folders to default if they don't exists
        let fm = FileManager.default
        if let customDerivedDataPath = Preferences.shared.customDerivedDataFolder?.path, !fm.fileExists(atPath: customDerivedDataPath) {
            log.warning("Custom derived data folder no longer exists, resetting to default!")
            Preferences.shared.customDerivedDataFolder = nil
        }
        
        if let customArchivesPath = Preferences.shared.customArchivesFolder?.path, !fm.fileExists(atPath: customArchivesPath) {
            log.warning("Custom archives folder no longer exists, resetting to default!")
            Preferences.shared.customArchivesFolder = nil
        }
        
        
        // open ~/Library/Developer folder & create XcodeFiles instance
        if let developerLibraryFolder = Files.acquireUserDeveloperFolderPermissions(),
           let xcodeFiles = XcodeFiles(
            developerFolder: developerLibraryFolder,
            customDerivedDataFolder: Files.acquireCustomDerivedDataFolderPermissions(),
            customArchivesFolder: Files.acquireCustomArchivesFolderPermissions()
           ) {
            xcodeFiles.scanDelegate = self
            self.xcodeFiles = xcodeFiles
            
            disableAccessWarnings()
            
            // start initial scan
            startScan()
        } else {
            log.warning("MainViewController: Cannot acquire \"Developer\" folder access! Showing access warning!")
            
            enableAccessWarnings(
                title: "Access to \"~/Developer\" folder is needed",
                content: "DevCleaner needs permission to your Developer folder to scan Xcode cache files & archives",
                buttonTitle: "Give Access",
                buttonActionSelector: #selector(selectDeveloperFolder(_:))
            )
        }
    }
    
    private func updateCustomFolders() {
        guard let xcodeFiles else {
            return
        }
        
        let derivedDataFolder = Files.acquireCustomDerivedDataFolderPermissions()
        let archivesFolder = Files.acquireCustomArchivesFolderPermissions()
        
        xcodeFiles.updateCustomFolders(
            customDerivedDataFolder: derivedDataFolder,
            customArchivesFolder: archivesFolder
        )
    }
    
    private func updateButtonsAndLabels() {
        let fileManager = FileManager.default
        
        // dry mode label
        if let window = view.window {
            if window.titlebarAccessoryViewControllers.count == 0 {
                let dryLabelAccessoryVc = NSTitlebarAccessoryViewController()
                dryLabelAccessoryVc.layoutAttribute = .trailing
                dryLabelAccessoryVc.view = NSView(frame: NSRect(x: 0.0, y: 0.0, width: 80.0, height: 0.0))
                
                let dryModeView = NSView(frame: NSRect(x: 10.0, y: 6.0, width: 60.0, height: 16.0))
                dryModeView.wantsLayer = true
                dryModeView.layer?.backgroundColor = NSColor.systemOrange.cgColor
                dryModeView.layer?.cornerRadius = 4.0
                dryModeView.layer?.masksToBounds = true
                
                let dryModeLabel = NSTextField(labelWithString: "DRY MODE")
                dryModeLabel.frame = NSRect(x: 0.0, y: -2.0, width: 60.0, height: 16.0)
                dryModeLabel.font = NSFont.labelFont(ofSize: 9.0)
                dryModeLabel.textColor = .white
                dryModeLabel.alignment = .center
                dryModeLabel.lineBreakMode = .byClipping
                dryModeView.addSubview(dryModeLabel)
                
                dryLabelAccessoryVc.view.addSubview(dryModeView)
                view.window?.addTitlebarAccessoryViewController(dryLabelAccessoryVc)
                
                self.dryModeView = dryModeView
            }
            
            dryModeView.isHidden = !Preferences.shared.dryRunEnabled
        }
        
        // total size & free disk space
        let bytesFreeOnDisk = (try? fileManager.volumeFreeDiskSpace(at: Files.userDeveloperFolder)) ?? 0
        let bytesFreeOnDiskString = formatBytesToString(bytes: bytesFreeOnDisk)
        
        if let xcodeFiles, xcodeFiles.state == .scanComplete {
            let totalSizeAvailableToCleanString = formatBytesToString(bytes: xcodeFiles.totalSize)
            
            totalBytesTextField.stringValue = "Total: \(totalSizeAvailableToCleanString)"
            view.window?.title = "DevCleaner - \(totalSizeAvailableToCleanString) available to clean; \(bytesFreeOnDiskString) free on disk"
        } else {
            let zeroBytesAvailableToCleanString = formatBytesToString(bytes: 0)
            
            totalBytesTextField.stringValue = "Total: \(zeroBytesAvailableToCleanString)"
            view.window?.title = "DevCleaner - \(bytesFreeOnDiskString) free on disk"
        }
        
        // selected size
        let selectedSize = xcodeFiles?.selectedSize ?? 0
        bytesSelectedTextField.stringValue = "Selected: \(formatBytesToString(bytes: selectedSize))"
        
        // clean button disabled when we selected nothing
        cleanButton.isEnabled = selectedSize > 0
        
        // all time size / donate button
        benefitsTextField.attributedStringValue = benefitsLabelAttributedString(totalBytesCleaned: Preferences.shared.totalBytesCleaned)
        tipMeButton.isEnabled = Donations.shared.canMakeDonations
    }
    
    private func startScan() {
        guard let xcodeFiles else {
            return
        }
        
        // clear data
        xcodeFiles.cleanAllEntries()
        
        updateButtonsAndLabels()
        
        // start scan asynchronously
        DispatchQueue.global(qos: .userInitiated).async {
            xcodeFiles.scanFiles(in: xcodeFiles.locations.keys.map { $0 })
        }
    }
    
    private func formatBytesToString(bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
    
    private func benefitsLabelAttributedString(totalBytesCleaned: Int64) -> NSAttributedString {
        let totalBytesString = ByteCountFormatter.string(fromByteCount: totalBytesCleaned, countStyle: .file)
        
        let fontSize: CGFloat = 12
        let result = NSMutableAttributedString()
        
        if totalBytesCleaned > 0 {
            let partOne = NSAttributedString(
                string: "You saved total of ",
                attributes: [.font : NSFont.systemFont(ofSize: fontSize)]
            )
            result.append(partOne)
            
            let partTwo = NSAttributedString(
                string: "\(totalBytesString)",
                attributes: [.font : NSFont.boldSystemFont(ofSize: fontSize)]
            )
            result.append(partTwo)
            
            let partThree = NSAttributedString(
                string: "! Tip me or share it:",
                attributes: [.font : NSFont.systemFont(ofSize: fontSize)]
            )
            result.append(partThree)
        } else {
            let oneAndOnlyPart = NSAttributedString(
                string: "Like this app? You can tip me or share it!",
                attributes: [.font : NSFont.systemFont(ofSize: fontSize)]
            )
            
            result.append(oneAndOnlyPart)
        }
        
        return result
    }
    
    // MARK: Loading
    private func startLoading() {
        loaded = false
        
        outlineView.reloadData()
        
        progressIndicator.isHidden = false
        progressIndicator.startAnimation(nil)
        
        cleanButton.isEnabled = false
    }
    
    private func stopLoading() {
        loaded = true
        
        progressIndicator.stopAnimation(nil)
        progressIndicator.isHidden = true
        
        cleanButton.isEnabled = true
        
        outlineView.reloadData()
    }
    
    // MARK: Access Warnings
    private func disableAccessWarnings() {
        accessWarningsView.isHidden = true
    }
    
    private func enableAccessWarnings(title: String, content: String, buttonTitle: String, buttonActionSelector: Selector) {
        accessWarningTitle.stringValue = title
        accessWarningContent.stringValue = content
        
        accessWarningButton.title = buttonTitle
        accessWarningButton.target = self
        accessWarningButton.action = buttonActionSelector
        
        accessWarningsView.isHidden = false
    }
    
    // MARK: Actions
    @IBAction func startCleaning(_ sender: NSButton) {
        guard let xcodeFiles else {
            return
        }
        
        // show warning message with question if we want to proceed and continue only if we agree
        let dryRunEnabled = Preferences.shared.dryRunEnabled
        let warningMessage = dryRunEnabled ? "DevCleaner is running in \"dry run\" mode. It means that files won't be deleted and nothing will change. If you want to clean files for real, go to \"Preferences\" and disable dry run mode."
        : "Are you sure to proceed? This can't be undone."
        Alerts.warningAlert(title: "Clean Xcode cache files", message: warningMessage, okButtonText: "Clean", window: view.window) { messageResult in
            if messageResult == .alertFirstButtonReturn {
                self.performSegue(withIdentifier: Segue.showCleaningView.segueIdentifier, sender: nil)
                
                // in debug "dry" cleaned bytes are added to total bytes clean
#if DEBUG
                Preferences.shared.totalBytesCleaned += xcodeFiles.selectedSize
#else
                if !dryRunEnabled {
                    Preferences.shared.totalBytesCleaned += xcodeFiles.selectedSize
                }
#endif
                
                log.info("MainViewController: Total bytes cleaned - \(self.formatBytesToString(bytes: Preferences.shared.totalBytesCleaned))")
                
                DispatchQueue.global(qos: .userInitiated).async {
                    xcodeFiles.deleteSelectedEntries(dryRun: dryRunEnabled)
                }
            }
        }
    }
    
    @IBAction func showInFinder(_ sender: Any) {
        guard let clickedEntry = outlineView.item(atRow: outlineView.clickedRow) as? XcodeFileEntry else {
            return
        }
        
        if clickedEntry.paths.count > 0 {
            NSWorkspace.shared.activateFileViewerSelecting(clickedEntry.paths)
        }
    }
    
    @IBAction func rescan(_ sender: Any) {
        startScan()
    }
    
    @IBAction func share(_ sender: Any) {
        guard let shareUrl = URL(string: "https://itunes.apple.com/app/devcleaner/id1388020431") else {
            return
        }
        
        guard let shareView = sender as? NSView else {
            return
        }
        
        let sharingService = NSSharingServicePicker(items: [shareUrl])
        sharingService.show(relativeTo: .zero, of: shareView, preferredEdge: .minX)
    }
    
    @IBAction func openAppReview(_ sender: Any) {
        ReviewRequests.shared.showReviewOnTheAppStore()
    }
    
    @IBAction func openFollowMenu(_ sender: NSButton) {
        guard let followMenu = sender.menu else {
            return
        }
        
        guard let event = NSApplication.shared.currentEvent else {
            return
        }
        
        NSMenu.popUpContextMenu(followMenu, with: event, for: sender)
    }
    
    @IBAction func followMeOnTwitter(_ sender: Any) {
        guard let myTwitterUrl = URL(string: "https://twitter.com/intent/follow?screen_name=vashpan") else {
            return
        }
        
        NSWorkspace.shared.open(myTwitterUrl)
    }
    
    @IBAction func followMeOnMastodon(_ sender: Any) {
        guard let myMastodonUrl = URL(string: "https://mastodon.social/@kkolakowski") else {
            return
        }
        
        NSWorkspace.shared.open(myMastodonUrl)
    }
    
    @IBAction func downloadXcode(_ sender: Any) {
        guard let xcodeUrl = URL(string: "https://apps.apple.com/pl/app/xcode/id497799835?") else {
            return
        }
        
        NSWorkspace.shared.open(xcodeUrl)
    }
    
    @IBAction func selectDeveloperFolder(_ sender: Any) {
        setupXcodeFilesAndStartScanningIfNeeded()
    }
}

// MARK: NSOutlineViewDataSource implementation
extension MainViewController: NSOutlineViewDataSource {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        // no items if not loaded
        if !loaded {
            return 0
        }
        
        guard let xcodeFiles else {
            fatalError("MainViewController: Cannot create XcodeFiles instance!")
        }
        
        // for child items
        if let xcodeFileEntry = item as? XcodeFileEntry {
            return xcodeFileEntry.items.count
        }
        
        // for root items
        return xcodeFiles.locations.count
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        guard let xcodeFiles else {
            fatalError("MainViewController: Cannot create XcodeFiles instance!")
        }
        
        // for child items
        if let xcodeFileEntry = item as? XcodeFileEntry {
            return xcodeFileEntry.items[index]
        }
        
        // for root items
        if let location = XcodeFiles.Location(rawValue: index), let xcodeFileEntry = xcodeFiles.locations[location] {
            return xcodeFileEntry
        } else {
            fatalError("MainViewController: Wrong location from index for XcodeFiles!")
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        // every item that has child items
        if let xcodeFileEntry = item as? XcodeFileEntry {
            xcodeFileEntry.items.count > 0
        } else {
            false
        }
    }
}

// MARK: NSOutlineViewDelegate implementation
extension MainViewController: NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        var view: NSTableCellView?
        
        if let xcodeFileEntry = item as? XcodeFileEntry, let column = tableColumn {
            if column.identifier == OutlineViewColumnsIdentifiers.itemColumn.identifier {
                if let itemView = outlineView.makeView(withIdentifier: OutlineViewCellIdentifiers.itemCell.identifier, owner: self) as? XcodeEntryCellView {
                    itemView.setup(with: xcodeFileEntry, delegate: self)
                    
                    view = itemView
                }
            } else if column.identifier == OutlineViewColumnsIdentifiers.sizeColumn.identifier {
                if let sizeView = outlineView.makeView(withIdentifier: OutlineViewCellIdentifiers.sizeCell.identifier, owner: self) as? SizeCellView {
                    sizeView.setup(with: xcodeFileEntry)
                    
                    view = sizeView
                }
            }
        }
        
        return view
    }
}

extension MainViewController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        xcodeFiles = nil
    }
}

// MARK: NSMenuDelegate implementation
extension MainViewController: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu == outlineView.menu else {
            return
        }
        
        guard let showInFinderMenuItem = menu.item(at: 0) else {
            return
        }
        
        guard let clickedEntry = outlineView.item(atRow: outlineView.clickedRow) as? XcodeFileEntry else {
            return
        }
        
        if clickedEntry.paths.count > 0 {
            showInFinderMenuItem.isEnabled = true
        } else {
            showInFinderMenuItem.isEnabled = false
        }
    }
}

// MARK: XcodeEntryCellViewDelegate implementation
extension MainViewController: XcodeEntryCellViewDelegate {
    func xcodeEntryCellSelectedChanged(_ cell: XcodeEntryCellView, state: NSControl.StateValue, xcodeEntry: XcodeFileEntry?) {
        if let item = xcodeEntry {
            if state == .on {
                item.selectWithChildItems()
            } else if state == .off {
                item.deselectWithChildItems()
            }
            
            // create a list of current and parent items
            var rootEntry: XcodeFileEntry = item.parent ?? item
            var itemsToRefresh: [XcodeFileEntry] = [rootEntry]
            
            while let parentEntry = rootEntry.parent {
                itemsToRefresh.append(parentEntry)
                rootEntry = parentEntry
            }
            
            rootEntry.recalculateSelection()
            
            // refresh parent items and current item
            for itemToRefresh in itemsToRefresh {
                outlineView.reloadItem(itemToRefresh, reloadChildren: false)
            }
            
            outlineView.reloadItem(item, reloadChildren: true)
            
            updateButtonsAndLabels()
        }
    }
}

// MARK: CleaningViewControllerDelegate implememntation
extension MainViewController: CleaningViewControllerDelegate {
    func cleaningDidFinish(_ vc: CleaningViewController) {
        startScan()
        
        // ask after a little delay to let user enjoy their finished clean
        DispatchQueue.main.asyncAfter(wallDeadline: DispatchWallTime.now() + 2) {
            ReviewRequests.shared.requestReviewIfNeeded()
        }
    }
}

// MARK: XcodeFilesScanDelegate implementation
extension MainViewController: XcodeFilesScanDelegate {
    func scanWillBegin(xcodeFiles: XcodeFiles) {
        startLoading()
        
        updateButtonsAndLabels()
    }
    
    func scanDidFinish(xcodeFiles: XcodeFiles) {
        stopLoading()
        
        updateButtonsAndLabels()
    }
}

// MARK: PreferencesObserver implementation
extension MainViewController: PreferencesObserver {
    func preferenceDidChange(key: String) {
        if key == Preferences.Keys.customArchivesFolder || key == Preferences.Keys.customDerivedDataFolder {
            updateCustomFolders()
            startScan()
        }
        
        updateButtonsAndLabels()
    }
}
