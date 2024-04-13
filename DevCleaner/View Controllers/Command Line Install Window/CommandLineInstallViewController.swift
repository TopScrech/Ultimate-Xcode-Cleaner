import Cocoa

final class CommandLineInstallViewController: NSViewController {
    // MARK: Properties & outlets
    @IBOutlet weak var commandTextField: NSTextField!
    
    private var commandString: String {
        let appPath = Bundle.main.bundlePath
        
        return "sudo ln -sf \(appPath)/Contents/Resources/dev-cleaner.sh /usr/local/bin/dev-cleaner"
    }
    
    // MARK: Initialization & overrides
    override func viewDidLoad() {
        super.viewDidLoad()
        
        commandTextField.stringValue = "$ " + commandString
        commandTextField.isSelectable = true
    }
    
    // MARK: Actions
    @IBAction func copyCommand(_ sender: Any) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        pasteboard.setString(commandString, forType: .string)
    }
}
