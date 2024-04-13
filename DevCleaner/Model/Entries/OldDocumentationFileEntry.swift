import SwiftUI

public final class OldDocumentationFileEntry: XcodeFileEntry {
    public override var fullDescription: String {
        ""
    }
    
    public init(selected: Bool) {
        super.init(
            label: "Old Documentation Downloads",
            tooltipText: "Old offline documentations, not used anymore in modern Xcodes",
            icon: .none,
            tooltip: true,
            selected: selected
        )
    }
}
