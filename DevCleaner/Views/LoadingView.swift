import Cocoa

public class LoadingView: NSView {
    // MARK: Properties
    private let progressIndicator = NSProgressIndicator()
    
    // MARK: Constants
    private let indicatorSize: CGFloat = 32
    
    // MARK: Initialization & overrides
    public convenience init() {
        self.init(frame: .zero)
    }
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        // set background
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        // add loading indicator
        progressIndicator.style = .spinning
        progressIndicator.controlSize = .regular
        progressIndicator.frame = indicatorFrame(size: indicatorSize, in: frameRect)
        
        addSubview(progressIndicator)
    }
    
    public required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func layout() {
        progressIndicator.frame = indicatorFrame(size: indicatorSize, in: frame)
        
        super.layout()
    }
    
    public override func viewWillMove(toSuperview newSuperview: NSView?) {
        if newSuperview == nil {
            progressIndicator.stopAnimation(self)
        } else {
            progressIndicator.startAnimation(self)
        }
    }
    
    // MARK: Helpers
    private func indicatorFrame(size: CGFloat, in frameRect: CGRect) -> CGRect {
        .init(
            x: (frameRect.width - size) / 2,
            y: (frameRect.height - size) / 2,
            width: size, height: size
        )
    }
}
