import Cocoa

// MARK: Cleaning view controller delegate
internal protocol CleaningViewControllerDelegate: AnyObject {
    func cleaningDidFinish(_ vc: CleaningViewController)
}

// MARK: - Cleaning view controller
internal final class CleaningViewController: NSViewController {
    // MARK: Types
    internal enum State {
        case undefined
        
        case idle(title: String, progress: Double)
        case working(title: String, details: String, progress: Double)
    }
    
    // MARK: Properties & outlets
    @IBOutlet private weak var headerLabel: NSTextField!
    @IBOutlet private weak var currentFileLabel: NSTextField!
    @IBOutlet private weak var progressIndicator: NSProgressIndicator!
    
    internal weak var delegate: CleaningViewControllerDelegate?
    
    internal var state: State = .undefined {
        didSet {
            if isViewLoaded {
                update(state: state)
            }
        }
    }
    
    // MARK: Initialization & overrides
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // update first state we set
        update(state: state)
        
        // check if we are in dry run and mark it
        let dryRunText = Preferences.shared.dryRunEnabled ? "(Dry run) " : String()
        headerLabel.stringValue = "\(dryRunText)Cleaning Xcode cache files..."
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        view.window?.styleMask.remove(.resizable)
    }
    
    // MARK: Updating state
    private func update(state: State) {
        switch state {
        case .idle(let title, let progress):
            currentFileLabel.stringValue = title
            
            progressIndicator.isIndeterminate = false
            progressIndicator.stopAnimation(self)
            
            progressIndicator.doubleValue = progress
            
        case .working(let title, let details, let progress):
            currentFileLabel.stringValue = "\(title): \(details)"
            
            progressIndicator.isIndeterminate = false
            progressIndicator.stopAnimation(self)
            
            progressIndicator.doubleValue = progress
            
        case .undefined:
            assert(false, "CleaningViewController: Cannot update to state 'undefined'")
        }
    }
    
    // MARK: Action
    @IBAction func dismissCleaningView(_ sender: Any) {
        dismiss(sender)
        
        delegate?.cleaningDidFinish(self)
    }
    
    @IBAction func stopCleaning(_ sender: Any) {
        dismiss(sender)
        
        delegate?.cleaningDidFinish(self)
    }
}

extension CleaningViewController: XcodeFilesDeleteDelegate {
    func deleteWillBegin(xcodeFiles: XcodeFiles) {
        DispatchQueue.main.async {
            self.state = .idle(title: "Initialization...", progress: 0)
        }
    }
    
    func deleteInProgress(xcodeFiles: XcodeFiles, location: String, label: String, url: URL?, current: Int, total: Int) {
        let progress = Double(current) / Double(total) * 100
        
        DispatchQueue.main.async {
            self.state = .working(title: location.capitalized, details: label, progress: progress)
        }
    }
    
    func deleteItemFailed(xcodeFiles: XcodeFiles, error: Error, location: String, label: String, url: URL?) {
        // prepare error message
        let message = """
        Following file couldn't be removed:\n\(location.capitalized): \(url?.path ?? "-")\n\n
        \(error.localizedDescription)
        """
        
        // show error message
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = "Failed to delete item"
            alert.informativeText = message
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    func deleteDidFinish(xcodeFiles: XcodeFiles) {
        DispatchQueue.main.async {
            self.state = .idle(title: "Finished!", progress: 100)
            
            // wait a little bit and then dismiss to avoid too abtrupt transition
            DispatchQueue.main.asyncAfter(wallDeadline: DispatchWallTime.now() + 0.5) {
                self.dismiss(self)
                self.delegate?.cleaningDidFinish(self)
            }
        }
    }
}
