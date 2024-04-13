import Foundation

public final class Files {
    // MARK: Paths to common folders
    public static var userDeveloperFolder: URL {
        let userHomeDirectory = FileManager.default.realHomeDirectoryForCurrentUser
        let userDeveloperFolder = userHomeDirectory.appendingPathComponent("Library/Developer", isDirectory: true)
        
        return userDeveloperFolder
    }
    
    // MARK: Acquire folder permissions
    private static func acquireFolderPermissions(folderUrl: URL, allowCancel: Bool = true, openPanelMessage: String? = nil) -> URL? {
        let message = openPanelMessage ?? "DevCleaner needs permission to this folder to scan its contents. Folder should be already selected and all you need to do is to click \"Open\"."
        
        return folderUrl.acquireAccessFromSandbox(
            bookmark: Preferences.shared.folderBookmark(for: folderUrl),
            allowCancel: allowCancel,
            openPanelMessage: message
        )
    }
    
    public static func acquireUserDeveloperFolderPermissions() -> URL? {
        acquireFolderPermissions(
            folderUrl: Files.userDeveloperFolder,
            openPanelMessage: "DevCleaner needs permission to your Developer folder to scan Xcode cache files. Folder should be already selected and all you need to do is to click \"Open\"."
        )
    }
    
    public static func acquireCustomDerivedDataFolderPermissions() -> URL? {
        guard let customDerivedDataFolder = Preferences.shared.customDerivedDataFolder else {
            return nil
        }
        
        return acquireFolderPermissions(folderUrl: customDerivedDataFolder)
    }
    
    public static func acquireCustomArchivesFolderPermissions() -> URL? {
        guard let customArchivesFolder = Preferences.shared.customArchivesFolder else {
            return nil
        }
        
        return acquireFolderPermissions(folderUrl: customArchivesFolder)
    }
}
