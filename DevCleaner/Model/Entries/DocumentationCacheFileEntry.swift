import SwiftUI

public final class DocumentationCacheFileEntry: XcodeFileEntry {
    // MARK: Properties
    public let version: Version
    
    public init(version: Version, selected: Bool) {
        self.version = version
        
        super.init(
            label: "Cache from Xcode \(version)",
            tooltipText: "Documentation cache files from Xcode \(version)",
            icon: .system(name: NSImage.multipleDocumentsName),
            tooltip: true,
            selected: selected
        )
    }
}
