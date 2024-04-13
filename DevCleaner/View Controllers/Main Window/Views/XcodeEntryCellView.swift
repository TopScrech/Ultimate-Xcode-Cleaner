import Cocoa

// MARK: Xcode Entry Cell View Delegate
protocol XcodeEntryCellViewDelegate: AnyObject {
    func xcodeEntryCellSelectedChanged(_ cell: XcodeEntryCellView, state: NSControl.StateValue, xcodeEntry: XcodeFileEntry?)
}

// MARK: Xcode Entry Cell View
final class XcodeEntryCellView: NSTableCellView {
    // MARK: Properties & outlets
    @IBOutlet private weak var checkBox: NSButton!
    
    internal weak var delegate: XcodeEntryCellViewDelegate? = nil
    
    private weak var entry: XcodeFileEntry?
    
    // MARK: Setup
    internal func setup(with xcodeEntry: XcodeFileEntry, delegate: XcodeEntryCellViewDelegate) {
        // reassing entry
        entry = xcodeEntry
        
        // delegate
        self.delegate = delegate
        
        // checkbox
        checkBox.state = entrySelectionToControlState(xcodeEntry.selection)
        
        // label
        textField?.font = NSFont.monospacedDigitSystemFont(ofSize: textField?.font?.pointSize ?? 13, weight: .regular)
        textField?.attributedStringValue = attributedString(for: xcodeEntry)
        textField?.sizeToFit()
        
        // tooltip
        if xcodeEntry.tooltip {
            toolTip = xcodeEntry.tooltipText
        } else {
            toolTip = nil
        }
        
        // icon
        imageView?.image = iconForEntry(xcodeEntry)
        
        // disable if no children and path
        if xcodeEntry.isEmpty {
            checkBox.isEnabled = false
            checkBox.state = .off
            
            imageView?.isEnabled = false
            textField?.isEnabled = false
        }
    }
    
    // MARK: Helpers
    override func prepareForReuse() {
        super.prepareForReuse()
        
        checkBox.isEnabled = true
        checkBox.state = .off
        
        imageView?.isEnabled = true
        textField?.isEnabled = true
    }
    
    private func attributedString(for xcodeEntry: XcodeFileEntry) -> NSAttributedString {
        let result = NSMutableAttributedString()
        
        // label
        let label = NSAttributedString(string: xcodeEntry.label)
        result.append(label)
        
        // extra info if present
        if !xcodeEntry.extraInfo.isEmpty {
            let extraInfo = NSAttributedString(string: " " + xcodeEntry.extraInfo, attributes: [
                NSAttributedString.Key.foregroundColor: NSColor.secondaryLabelColor
            ])
            
            result.append(extraInfo)
        }
        
        // add truncating options
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        result.addAttributes([NSAttributedString.Key.paragraphStyle: style], range: NSRange(location: 0, length: result.length))
        
        return result
    }
    
    private func entrySelectionToControlState(_ entrySelection: XcodeFileEntry.Selection) -> NSControl.StateValue {
        switch entrySelection {
        case .on: .on
            
        case .off: .off
            
        case .mixed: .mixed
        }
    }
    
    private func iconForEntry(_ xcodeEntry: XcodeFileEntry) -> NSImage? {
        let result: NSImage?
        
        if let entryIcon = xcodeEntry.icon {
            switch entryIcon {
            case .path(let url):
                result = NSImage(byReferencing: url)
                
            case .image(let name):
                result = NSImage(imageLiteralResourceName: name)
                
            case .system(let name):
                result = NSImage(named: name)
            }
        } else {
            result = nil
        }
        
        return result
    }
    
    // MARK: Actions
    @IBAction func checkBoxSwitched(_ sender: NSButton) {
        // when we click, disallow mixed state
        if sender.state == .mixed {
            sender.setNextState()
        }
        
        delegate?.xcodeEntryCellSelectedChanged(self, state: sender.state, xcodeEntry: entry)
    }
}
