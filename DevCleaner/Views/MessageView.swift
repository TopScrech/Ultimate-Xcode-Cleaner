import Cocoa

public class MessageView: NSView {
    // MARK: Properties
    private let label = NSTextField()
    
    public var message: String = String() {
        didSet {
            label.stringValue = message
        }
    }
    
    public var backgroundColor: NSColor = .windowBackgroundColor {
        didSet {
            wantsLayer = true
            layer?.backgroundColor = backgroundColor.cgColor
        }
    }
    
    // MARK: Initialization & overrides
    public convenience init() {
        self.init(frame: .zero)
    }
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        // set background
        backgroundColor = NSColor.windowBackgroundColor
        
        // set message label
        label.font = NSFont.systemFont(ofSize: 17.0, weight: .bold)
        label.isEditable = false
        label.isSelectable = false
        label.drawsBackground = false
        label.isBordered = false
        label.isBezeled = false
        label.usesSingleLineMode = true
        label.alignment = .center
        
        addSubview(self.label)
    }
    
    public required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func layout() {
        let targetHeight: CGFloat = 30
        label.frame = NSRect(
            x: 0,
            y: (frame.height - targetHeight) / 2,
            width: frame.width, height: targetHeight
        )
        
        super.layout()
    }
}
