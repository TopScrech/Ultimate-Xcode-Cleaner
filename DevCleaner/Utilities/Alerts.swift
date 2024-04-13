import Cocoa

public class Alerts {
    class public func fatalErrorAlertAndQuit(title: String, message: String) {
        // display a popup that tells us that this is basically a fatal error, and quit!
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "Quit")
        
        alert.runModal()
        NSApp.terminate(nil)
    }
    
    class public func warningAlert(title: String, message: String, okButtonText: String = "OK", cancelButtonText: String = "Cancel", window: NSWindow? = nil, completionHandler: ((NSApplication.ModalResponse) -> Void)? = nil) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: okButtonText)
        alert.addButton(withTitle: cancelButtonText)
        
        if let currentWindow = window {
            alert.beginSheetModal(for: currentWindow, completionHandler: completionHandler)
        } else {
            let response = alert.runModal()
            completionHandler?(response)
        }
    }
    
    class public func infoAlert(title: String, message: String, okButtonText: String = "OK") {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: okButtonText)
        
        alert.runModal()
    }
}
