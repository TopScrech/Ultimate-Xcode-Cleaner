import Foundation

// MARK: Xcode scan delegate
public protocol XcodeFilesScanDelegate: AnyObject {
    func scanWillBegin(xcodeFiles: XcodeFiles)
    func scanDidFinish(xcodeFiles: XcodeFiles)
}

// MARK: - Xcode delete delegate
public protocol XcodeFilesDeleteDelegate: AnyObject {
    func deleteWillBegin(xcodeFiles: XcodeFiles)
    func deleteInProgress(xcodeFiles: XcodeFiles, location: String, label: String, url: URL?, current: Int, total: Int)
    func deleteItemFailed(xcodeFiles: XcodeFiles, error: Error, location: String, label: String, url: URL?)
    func deleteDidFinish(xcodeFiles: XcodeFiles)
}

// MARK: - Xcode files
final public class XcodeFiles {
    // MARK: Types
    public enum Location: Int, CaseIterable {
        case deviceSupport,
             archives,
             derivedData,
             documentationCache,
             logs,
             oldDocumentation
    }
    
    public enum State {
        case initial,
             scanning,
             scanComplete
    }
    
    // MARK: Constants
    private static let scanFileEnumerationOptions: FileManager.DirectoryEnumerationOptions = [
        .skipsHiddenFiles,
        .skipsPackageDescendants
    ]
    
    // MARK: Properties
    public private(set) var state: State
    
    private var userDeveloperFolderUrl: URL
    private var customDerivedDataFolderUrl: URL?
    private var customArchivesFolderUrl: URL?
    
    public weak var scanDelegate: XcodeFilesScanDelegate?
    public weak var deleteDelegate: XcodeFilesDeleteDelegate?
    
    public private(set) var locations: [Location : XcodeFileEntry]
    
    public var totalSize: Int64 {
        locations.values.reduce(0) { (result, entry) -> Int64 in
            result + (entry.size.numberOfBytes ?? 0)
        }
    }
    
    public var selectedSize: Int64 {
        locations.values.reduce(0) { (result, entry) -> Int64 in
            result + entry.selectedSize
        }
    }
    
    // MARK: Initialization
    public init?(developerFolder: URL, customDerivedDataFolder: URL?, customArchivesFolder: URL?) {
        state = .initial
        
        userDeveloperFolderUrl = developerFolder
        customDerivedDataFolderUrl = customDerivedDataFolder
        customArchivesFolderUrl = customArchivesFolder
        
        let _ = userDeveloperFolderUrl.startAccessingSecurityScopedResource()
        let _ = customDerivedDataFolderUrl?.startAccessingSecurityScopedResource()
        let _ = customArchivesFolderUrl?.startAccessingSecurityScopedResource()
        
        guard XcodeFiles.checkForXcodeDataFolders(location: developerFolder) else {
            log.error("XcodeFiles: Cannot create because Xcode cache folders doesn't seem to exist or we don't have proper access to them!")
            return nil
        }
        
        locations = [
            .deviceSupport: XcodeFileEntry(label: "Device Support", tooltipText: "Systems debug symbols that are retained every version, usually you need only the newer ones", tooltip: true, selected: false),
            .archives: XcodeFileEntry(label: "Archives", tooltipText: "Archived apps, delete only if you sure you don't need them", tooltip: true, selected: false),
            .derivedData: XcodeFileEntry(label: "Derived Data", tooltipText: "Cached projects data & symbol index", tooltip: true, selected: false),
            .documentationCache: XcodeFileEntry(label: "Documentation Cache", tooltipText: "Documentation cache for each Xcode version", tooltip: true, selected: false),
            .logs: XcodeFileEntry(label: "Old Simulator & Device Logs", tooltipText: "Old device logs & crashes databases, only most recent ones are usually needed as they are copies of previous ones.", tooltip: true, selected: false),
            .oldDocumentation: OldDocumentationFileEntry(selected: false)
        ]
    }
    
    deinit {
        userDeveloperFolderUrl.stopAccessingSecurityScopedResource()
        customDerivedDataFolderUrl?.stopAccessingSecurityScopedResource()
        customArchivesFolderUrl?.stopAccessingSecurityScopedResource()
    }
    
    // MARK: Helpers
    public static func isDeveloperFolderExists() -> Bool {
        let developerFolder = Files.userDeveloperFolder.path
        
        return FileManager.default.fileExists(atPath: developerFolder)
    }
    
    public static func isXcodeRunning() -> Bool {
#if DEBUG
        return false
#else
        
        let runningXcodeApp = NSWorkspace.shared.runningApplications.first {
            return $0.bundleIdentifier == "com.apple.dt.Xcode"
        }
        
        return runningXcodeApp != nil
#endif
    }
    
    private static func checkForXcodeDataFolders(location: URL) -> Bool {
        // check if folder exists
        let folderExists = FileManager.default.fileExists(atPath: location.path)
        
        // more checks, like folders structure
        var structureProper = true
        
        let foldersToCheck = ["Xcode", "CoreSimulator"]
        for folder in foldersToCheck {
            let folderPath = location.appendingPathComponent(folder)
            
            if !FileManager.default.fileExists(atPath: folderPath.path) {
                structureProper = false
                break
            }
            
            if !FileManager.default.isWritableFile(atPath: folderPath.path) {
                structureProper = false
                break
            }
        }
        
        return folderExists && structureProper
    }
    
    // runs shell command synchronously and returns an output
    @discardableResult
    private static func runShellCommand(_ command: String) -> String {
        let pipe = Pipe()
        let process = Process()
        
        process.launchPath = "/bin/sh"
        process.arguments = ["-c", command]
        process.standardOutput = pipe
        process.standardError = pipe
        
        let file = pipe.fileHandleForReading
        
        process.launch()
        
        guard let result = String(data: file.readDataToEndOfFile(), encoding: .utf8) else {
            log.error("XcodeFiles: Error while reading output from shell command: \(command)")
            return ""
        }
        
        return result
    }
    
    public func debugRepresentation() -> String {
        var result = String()
        
        for entry in locations.values {
            result += entry.debugRepresentation()
            result += "\n"
        }
        
        return result
    }
    
    // MARK: Creating entries
    private func deviceSupportEntry(from url: URL, osLabel: String) -> DeviceSupportFileEntry? {
        // Sample paths:
        // Watch2,7 5.2.1 (16U113)
        // iPad 10.2 (11C203)
        // 12.3 (16F156) arm64e
        // 12.3.1 (16F203)
        // 12.0 (16A367) arm64e
        // 10.16
        
        let string = url.lastPathComponent
        let splitted = string.split(separator: " ", maxSplits: 4, omittingEmptySubsequences: true)
        
        guard splitted.count >= 1 else { // iOS and others have usually two parts, macOS just one
            return nil
        }
        
        let device: String?
        let version: Version
        let buildString: String?
        let creationDate: Date = FileManager.default.dateCreated(for: url)
        let arch: String?
        
        // check if we have version first (then we may have additional architecture here)
        if let foundVersion = Version(describing: String(splitted[0])) {
            device = nil
            version = foundVersion
            
            if splitted.count > 1 {
                buildString = String(splitted[1])
                if splitted.count > 2 {
                    arch = String(splitted[2])
                } else {
                    arch = nil
                }
            } else {
                buildString = nil
                arch = nil
            }
        } else if splitted.count > 1, let foundVersion = Version(describing: String(splitted[1])) { // if version is second, we may have extra device info
            device = String(splitted[0])
            version = foundVersion
            
            if splitted.count > 2 {
                buildString = String(splitted[2])
                
                if splitted.count > 3 {
                    arch = String(splitted[3])
                } else {
                    arch = nil
                }
            } else {
                buildString = nil
                arch = nil
            }
        } else {
            log.warning("XcodeFiles: No version for device support: \(string), skipping")
            return nil
        }
        
        // create build version
        let build: AppleBuild?
        
        if let buildString {
            build = AppleBuild(string: buildString)
        } else {
            build = nil
        }
        
        return DeviceSupportFileEntry(
            device: device,
            osType: DeviceSupportFileEntry.OSType(label: osLabel),
            version: version,
            build: build,
            date: creationDate,
            arch: arch,
            selected: false
        )
    }
    
    private func derivedDataEntry(from location: URL) -> DerivedDataFileEntry? {
        // drop last part that's the kind of id of a project
        let splitted = location.lastPathComponent.split(separator: "-", omittingEmptySubsequences: true).dropLast()
        
        // create project name
        let name = splitted.joined(separator: "-").replacingOccurrences(of: "_", with: " ") // replace all dashes with spaces
        
        // find project folder path
        let infoPath = location.appendingPathComponent("info.plist")
        
        if let projectInfoDict = NSDictionary(contentsOf: infoPath) {
            // try to get project folder path from .plist dictionary
            if let projectRealPath = projectInfoDict["WorkspacePath"] as? String {
                let projectRealPathUrl = URL(fileURLWithPath: projectRealPath)
                
                return DerivedDataFileEntry(projectName: name, pathUrl: projectRealPathUrl, selected: false)
            }
        }
        
        return nil
    }
    
    private func archiveFileEntry(from location: URL) -> ArchiveFileEntry? {
        guard location.pathExtension == "xcarchive" else {
            return nil
        }
        
        // open archive info.plist for more informations
        let projectName: String
        let bundleName: String
        let bundleVersionString: String
        let bundleBuild: String
        let archiveDate: Date
        var status: ArchiveFileEntry.SubmissionStatus = .undefined
        
        let infoPath = location.appendingPathComponent("Info.plist")
        if let archiveInfoDict = NSDictionary(contentsOf: infoPath) {
            // project name
            if let name = archiveInfoDict["Name"] as? String {
                projectName = name
            } else {
                log.warning("XcodeFiles: Cannot get project name from archive: \(location.path)")
                return nil
            }
            
            // archive date
            if let date = archiveInfoDict["CreationDate"] as? Date {
                archiveDate = date
            } else {
                log.warning("XcodeFiles: Cannot get archive date from archive: \(location.path)")
                return nil
            }
            
            // submission status
            if let distributionsData = archiveInfoDict["Distributions"] as? [[String: Any]] {
                // first we have an array of dictionaries
                //     for each submission, we check for upload event dict
                //          check if "state" is "success" - in other case it will be failure
                var uploadStatusFound = false
                for distribution in distributionsData {
                    if let uploadEvent = distribution["uploadEvent"] as? [String: Any] {
                        if let state = uploadEvent["state"] as? String {
                            if state == "success" {
                                status = .success
                                uploadStatusFound = true
                                break
                            }
                        }
                    }
                }
                
                if !uploadStatusFound {
                    status = .failure
                }
            }
            
            if let archiveProperties = archiveInfoDict["ApplicationProperties"] as? [String : Any] {
                // bundle name
                if let bundle = archiveProperties["CFBundleIdentifier"] as? String {
                    bundleName = bundle
                } else {
                    log.warning("XcodeFiles: Cannot get bundle name from archive: \(location.path)")
                    return nil
                }
                
                // version
                if let versionString = archiveProperties["CFBundleShortVersionString"] as? String {
                    bundleVersionString = versionString
                } else {
                    log.info("XcodeFiles: Cannot get bundle version from archive: \(location.path)")
                    return nil
                }
                
                // build
                if let build = archiveProperties["CFBundleVersion"] as? String {
                    bundleBuild = build
                } else {
                    log.warning("XcodeFiles: Cannot get bundle build from archive: \(location.path)")
                    return nil
                }
            } else {
                log.warning("XcodeFiles: Cannot get 'ApplicationProperties' from archive Info.plist file: \(location.path)")
                return nil
            }
        } else {
            log.warning("XcodeFiles: Cannot open Info.plist file from archive: \(location.path)")
            return nil
        }
        
        return ArchiveFileEntry(
            projectName: projectName,
            bundleName: bundleName,
            version: bundleVersionString,
            build: bundleBuild,
            date: archiveDate,
            submissionStatus: status,
            location: location,
            selected: false
        )
    }
    
    // MARK: Clearing items
    public func cleanAllEntries() {
        for location in locations.values {
            location.clear()
        }
    }
    
    // MARK: Updating required data
    public func updateCustomFolders(customDerivedDataFolder: URL?, customArchivesFolder: URL?) {
        // clear old security access
        customDerivedDataFolderUrl?.stopAccessingSecurityScopedResource()
        customArchivesFolderUrl?.stopAccessingSecurityScopedResource()
        
        // update folders
        customDerivedDataFolderUrl = customDerivedDataFolder
        customArchivesFolderUrl = customArchivesFolder
        
        // restart security scope access
        let _ = customDerivedDataFolderUrl?.startAccessingSecurityScopedResource()
        let _ = customArchivesFolderUrl?.startAccessingSecurityScopedResource()
    }
    
    // MARK: Scan files
    public func scanFiles(in locations: [Location]) {
        state = .scanning
        
        DispatchQueue.main.async { [weak self] in
            if let strongSelf = self {
                strongSelf.scanDelegate?.scanWillBegin(xcodeFiles: strongSelf)
            }
        }
        
        cleanAllEntries()
        
        for location in locations {
            scanFiles(in: location)
        }
        
        state = .scanComplete
        
        DispatchQueue.main.async { [weak self] in
            if let strongSelf = self {
                strongSelf.scanDelegate?.scanDidFinish(xcodeFiles: strongSelf)
            }
        }
    }
    
    private func scanFiles(in location: Location) {
        guard let entry = locations[location] else {
            precondition(locations.keys.contains(location), "❌ No entry found for location: \(location)")
            return
        }
        
        // remove previous entries
        entry.clear()
        
        // scan and find files
        switch location {
        case .deviceSupport:
            entry.addChildren(items: scanDeviceSupportLocations())
            
        case .archives:
            entry.addChildren(items: scanArchivesLocations())
            
        case .derivedData:
            entry.addChildren(items: scanDerivedDataLocations())
            
        case .documentationCache:
            entry.addChildren(items: scanDocumentationCacheLocations())
            
        case .logs:
            entry.addChildren(items: scanLogsLocations())
            
            // different for those, as we don't have an option to select separate entries here
        case .oldDocumentation:
            entry.addPaths(paths: scanOldDocumentationLocations())
        }
        
        // check for those files sizes
        entry.recalculateSizeIfNeeded()
        
        // check for selections
        entry.recalculateSelection()
    }
    
    private func scanDeviceSupportLocations() -> [XcodeFileEntry] {
        let deviceSupportEntries = [
            (entry: XcodeFileEntry(label: "iOS", icon: .image(name: "Devices/iPadIcon"), selected: true), path: "iOS DeviceSupport"),
            (entry: XcodeFileEntry(label: "watchOS", icon: .image(name: "Devices/WatchIcon"), selected: true), path: "watchOS DeviceSupport"),
            (entry: XcodeFileEntry(label: "tvOS", icon: .image(name: "Devices/AppleTVIcon"), selected: true), path: "tvOS DeviceSupport"),
            (entry: XcodeFileEntry(label: "visionOS", icon: .image(name: "Devices/VisionProIcon"), selected: true), path: "visionOS DeviceSupport"),
            (entry: XcodeFileEntry(label: "macOS", icon: .image(name: "Devices/MacBookIcon"), selected: true), path: "macOS DeviceSupport")
        ]
        
        let xcodeLocation = userDeveloperFolderUrl.appendingPathComponent("Xcode")
        var entries: [XcodeFileEntry] = []
        for osEntry in deviceSupportEntries {
            let entryUrl = xcodeLocation.appendingPathComponent(osEntry.path)
            
            // scan for versions
            if let symbols = try? FileManager.default.contentsOfDirectory(at: entryUrl, includingPropertiesForKeys: nil, options: Self.scanFileEnumerationOptions) {
                var deviceSupportEntries = [DeviceSupportFileEntry]()
                for symbolUrl in symbols {
                    if let deviceSupportEntry = deviceSupportEntry(from: symbolUrl, osLabel: osEntry.entry.label) {
                        deviceSupportEntry.addPath(path: symbolUrl)
                        
                        deviceSupportEntries.append(deviceSupportEntry)
                    }
                }
                
                // sort
                deviceSupportEntries = deviceSupportEntries.sorted { (lhs, rhs) -> Bool in
                    if lhs.version == rhs.version {
                        let lhsBuild = lhs.build ?? AppleBuild.empty
                        let rhsBuild = rhs.build ?? AppleBuild.empty
                        
                        return lhsBuild > rhsBuild
                    } else {
                        return lhs.version > rhs.version
                    }
                }
                
                // merge (in case we have different architectures)
                var duplicatedEntries = [DeviceSupportFileEntry]()
                let entriesWithArch = deviceSupportEntries.filter { $0.architecture != nil }
                let entriesWithoutArch = deviceSupportEntries.filter { $0.architecture == nil }
                for entryWithoutArch in entriesWithoutArch {
                    for entryWithArch in entriesWithArch {
                        if entryWithoutArch.version == entryWithArch.version && entryWithoutArch.build == entryWithArch.build {
                            entryWithoutArch.addPaths(paths: entryWithArch.paths)
                            duplicatedEntries.append(entryWithArch)
                        }
                    }
                }
                for entryToRemove in duplicatedEntries {
                    deviceSupportEntries.removeAll {
                        $0.version == entryToRemove.version &&
                        $0.build == entryToRemove.build &&
                        $0.architecture == entryToRemove.architecture &&
                        $0.device == entryToRemove.device
                    }
                }
                
                // deselect first one (we usually will want those symbols)
                if let firstEntry = deviceSupportEntries.first {
                    firstEntry.deselectWithChildItems()
                }
                
                osEntry.entry.addChildren(items: deviceSupportEntries)
                
            } else {
                log.warning("XcodeFiles: Cannot check contents of '\(entryUrl.path)', skipping")
            }
            
            entries.append(osEntry.entry)
        }
        
        return entries
    }
    
    private func scanArchivesLocations() -> [XcodeFileEntry] {
        var archiveLocations = [URL]()
        archiveLocations.append(userDeveloperFolderUrl.appendingPathComponent("Xcode/Archives"))
        
        if let customArchivesLocation = customArchivesFolderUrl {
            if !archiveLocations.contains(customArchivesLocation) {
                archiveLocations.append(customArchivesLocation)
            }
        }
        
        // gather various projects, create entries for each of them
        var archiveInfos = [String : [ArchiveFileEntry]]()
        for archivesLocation in archiveLocations {
            if let datesFolders = try? FileManager.default.contentsOfDirectory(at: archivesLocation, includingPropertiesForKeys: nil, options: Self.scanFileEnumerationOptions) {
                for dateFolder in datesFolders {
                    if let xcarchives = try? FileManager.default.contentsOfDirectory(at: dateFolder, includingPropertiesForKeys: nil, options: Self.scanFileEnumerationOptions) {
                        for xcarchive in xcarchives {
                            if let xcarchiveEntry = archiveFileEntry(from: xcarchive) {
                                if archiveInfos.keys.contains(xcarchiveEntry.bundleName) {
                                    archiveInfos[xcarchiveEntry.bundleName]?.append(xcarchiveEntry)
                                } else {
                                    archiveInfos[xcarchiveEntry.bundleName] = [xcarchiveEntry]
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // convert archive infos for project entries
        return archiveInfos.compactMap { (arg) -> XcodeFileEntry? in
            let (_, archiveEntries) = arg
            
            guard let projectName = archiveEntries.first?.projectName else {
                return nil
            }
            
            // root project
            let projectEntry = XcodeFileEntry(label: projectName, icon: .image(name: "Files/XCArchive"), selected: false)
            
            // sort by version & build
            let projectArchiveEntries = archiveEntries.sorted { (lhs, rhs) -> Bool in
                if let lhsVersion = lhs.version, let rhsVersion = rhs.version {
                    if lhsVersion == rhsVersion {
                        return lhs.build.localizedStandardCompare(rhs.build) == .orderedDescending
                    } else {
                        return lhsVersion > rhsVersion
                    }
                } else {
                    return lhs.versionString.localizedStandardCompare(rhs.versionString) == .orderedDescending
                }
            }
            
            projectEntry.addChildren(items: projectArchiveEntries)
            
            return projectEntry
        }
    }
    
    private func scanDerivedDataLocations() -> [XcodeFileEntry] {
        var derivedDataLocations = [URL]()
        derivedDataLocations.append(userDeveloperFolderUrl.appendingPathComponent("Xcode/DerivedData"))
        
        if let customDerivedDataLocation = customDerivedDataFolderUrl {
            if !derivedDataLocations.contains(customDerivedDataLocation) {
                derivedDataLocations.append(customDerivedDataLocation)
            }
        }
        
        // scan for derived data projects
        var results: [XcodeFileEntry] = []
        for derivedDataLocation in derivedDataLocations {
            if let projectsFolders = try? FileManager.default.contentsOfDirectory(at: derivedDataLocation, includingPropertiesForKeys: nil, options: Self.scanFileEnumerationOptions) {
                for projectFolder in projectsFolders {
                    // ignore "ModuleCache" folder
                    if projectFolder.lastPathComponent == "ModuleCache" {
                        continue
                    }
                    
                    if let projectEntry = derivedDataEntry(from: projectFolder) {
                        projectEntry.addPath(path: projectFolder)
                        
                        results.append(projectEntry)
                    }
                }
            }
        }
        
        // sort
        for entry in results {
            entry.recalculateSize()
        }
        
        results = results.sorted { lhs, rhs in
            return lhs.size > rhs.size
        }
        
        return results
    }
    
    private func scanDocumentationCacheLocations() -> [XcodeFileEntry] {
        let docsCacheLocation = userDeveloperFolderUrl.appendingPathComponent("Xcode/DocumentationCache")
        
        var entries = [DocumentationCacheFileEntry]()
        
        // get documentation cache locations
        if let cacheFolders = try? FileManager.default.contentsOfDirectory(at: docsCacheLocation, includingPropertiesForKeys: nil, options: Self.scanFileEnumerationOptions) {
            for cacheFolder in cacheFolders {
                if let xcodeDocsCaches = try? FileManager.default.contentsOfDirectory(at: cacheFolder, includingPropertiesForKeys: nil, options: Self.scanFileEnumerationOptions) {
                    for xcodeDocsCache in xcodeDocsCaches {
                        if let xcodeVersion = Version(describing: xcodeDocsCache.lastPathComponent) {
                            // check if we already have entry for this Xcode version, and create it if not
                            if let oldXcodeEntryIndex = entries.firstIndex(where: { $0.version == xcodeVersion }) {
                                entries[oldXcodeEntryIndex].addPath(path: xcodeDocsCache)
                            } else {
                                let newEntry = DocumentationCacheFileEntry(version: xcodeVersion, selected: false)
                                newEntry.addPath(path: xcodeDocsCache)
                                
                                entries.append(newEntry)
                            }
                        } else {
                            log.warning("XcodeFiles: Invalid Xcode version while searching for documentation caches: \(xcodeDocsCache.lastPathComponent)")
                        }
                    }
                }
            }
        }
        
        // sort
        entries.sort { lhs, rhs in
            return lhs.version > rhs.version
        }
        
        // deselect first one
        if let firstEntry = entries.first {
            firstEntry.deselectWithChildItems()
        }
        
        return entries
    }
    
    private func scanLogsLocations() -> [XcodeFileEntry] {
        struct LogEntry {
            let path: URL
            let version: Version
            
            init?(path: URL) {
                self.path = path
                
                // parse path to get a version
                let filename = path.deletingPathExtension().lastPathComponent
                let components = filename.split(separator: " ")
                
                var foundVersion: Version?
                for component in components {
                    if let version = Version(describing: String(component)) {
                        if foundVersion == nil {
                            foundVersion = version
                            break
                        }
                    }
                }
                
                if let finalFoundVersion = foundVersion {
                    version = finalFoundVersion
                } else {
                    log.warning("XcodeFiles: Wrong log entry? Version not found (path: \(filename)")
                    return nil
                }
            }
        }
        
        // get location
        let logsLocation = userDeveloperFolderUrl.appendingPathComponent("Xcode/iOS Device Logs")
        
        // get all log entries from logs folder
        var logs = [LogEntry]()
        if let logFiles = try? FileManager.default.contentsOfDirectory(at: logsLocation, includingPropertiesForKeys: nil, options: Self.scanFileEnumerationOptions) {
            for logFile in logFiles {
                if let logEntry = LogEntry(path: logFile) {
                    logs.append(logEntry)
                }
            }
        }
        logs.sort { (lws, rws) -> Bool in lws.version > rws.version }
        
        // group logs by version numbers
        var entries = [DeviceLogsFileEntry]()
        var lastVersion: Version? = nil
        for logEntry in logs {
            if logEntry.version == lastVersion {
                if let lastEntry = entries.last {
                    lastEntry.addPath(path: logEntry.path)
                }
            } else {
                let newEntry = DeviceLogsFileEntry(version: logEntry.version, selected: true)
                newEntry.addPath(path: logEntry.path)
                entries.append(newEntry)
                
                lastVersion = logEntry.version
            }
        }
        
        // deselect first one
        if let firstEntry = entries.first {
            firstEntry.deselectWithChildItems()
        }
        
        return entries
    }
    
    private func scanOldDocumentationLocations() -> [URL] {
        // get location
        let docsLocation = userDeveloperFolderUrl.appendingPathComponent("Shared/Documentation")
        
        return [docsLocation]
    }
    
    // MARK: Deleting files
    public func deleteSelectedEntries(dryRun: Bool) {
        deleteDelegate?.deleteWillBegin(xcodeFiles: self)
        
        // gather a list of items to delete
        typealias DeletionItem = (location: String, label: String, path: URL)
        var itemsToDelete = [DeletionItem]()
        
        for location in locations.values where location.isSelected {
            var searchStack = Stack<XcodeFileEntry>()
            searchStack.push(location)
            
            // simple iterative pre-order tree search algorithm
            while !searchStack.isEmpty {
                if let currentEntry = searchStack.pop() {
                    if currentEntry.isSelected && currentEntry.paths.count > 0 {
                        let pathsFromNode = currentEntry.paths.map { 
                            DeletionItem(location: location.label, label: currentEntry.fullDescription, path: $0)
                        }
                        
                        itemsToDelete.append(contentsOf: pathsFromNode)
                    }
                    
                    for nextEntry in currentEntry.items {
                        searchStack.push(nextEntry)
                    }
                }
            }
        }
        
        // perform deletions
        let dryRunInfo = dryRun ? "[DRY RUN!]" : String()
        
        let itemsCount = itemsToDelete.count
        var ordinal = 0
        
        for itemToDelete in itemsToDelete {
            ordinal += 1
            
            deleteDelegate?.deleteInProgress(
                xcodeFiles: self,
                location: itemToDelete.location,
                label: itemToDelete.label,
                url: itemToDelete.path,
                current: ordinal,
                total: itemsCount
            )
            
            log.info("Deleting \(dryRunInfo): \(itemToDelete.location): \(itemToDelete.label) (\(itemToDelete.path.path))")
            
            if dryRun {
                Thread.sleep(forTimeInterval: 0.15)
            } else {
                do {
                    try FileManager.default.removeItem(at: itemToDelete.path)
                } catch(let error) {
                    deleteDelegate?.deleteItemFailed(
                        xcodeFiles: self,
                        error: error,
                        location: itemToDelete.location,
                        label: itemToDelete.label,
                        url: itemToDelete.path
                    )
                }
            }
        }
        
        deleteDelegate?.deleteDidFinish(xcodeFiles: self)
    }
}
