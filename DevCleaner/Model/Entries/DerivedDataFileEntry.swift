import SwiftUI

public final class DerivedDataFileEntry: XcodeFileEntry {
    // MARK: Properties
    public let projectName: String
    public let pathUrl: URL
    
    // MARK: Initialization
    public init(projectName: String, pathUrl: URL, selected: Bool) {
        self.projectName = projectName
        self.pathUrl = pathUrl
        
        super.init(
            label: projectName,
            extraInfo: pathUrl.path,
            icon: .system(name: NSImage.folderName),
            tooltip: true,
            selected: selected
        )
    }
}
