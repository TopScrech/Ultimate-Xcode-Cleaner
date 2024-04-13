import SwiftUI

public final class DeviceLogsFileEntry: XcodeFileEntry {
    // MARK: Properties
    public let version: Version
    
    public init(version: Version, selected: Bool) {
        self.version = version
        
        super.init(
            label: "Logs from Xcode \(version)",
            tooltipText: "Old logs from Xcode \(version)",
            icon: .system(name: NSImage.multipleDocumentsName),
            tooltip: true,
            selected: selected
        )
    }
}

