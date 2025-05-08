import Foundation
import os

public final class Signposts {
    // MARK: Properties
    private static var signpostLog: OSLog = {
        guard let bundleId = Bundle.main.bundleIdentifier else {
            fatalError("Signposts: No bundleId defined in main bundle Infp.plist file?")
        }
        
        return OSLog(subsystem: bundleId + ".Signposts", category: .pointsOfInterest)
    }()
    
    // MARK: Helpers
    private static func placeSignpost(type: OSSignpostType, name: StaticString, details: String, object: AnyObject?) {
        let spid: OSSignpostID
        
        if let objectForSpid = object {
            spid = OSSignpostID(log: Signposts.signpostLog, object: objectForSpid)
        } else {
            spid = OSSignpostID(log: Signposts.signpostLog)
        }
        
        os_signpost(type, dso: #dsohandle, log: Signposts.signpostLog, name: name, signpostID: spid, "%@", details)
    }
    
    // MARK: Placing signposts
    public static func begin(name: StaticString, details: String = String(), object: AnyObject? = nil) {
        placeSignpost(type: .begin, name: name, details: details, object: object)
    }
    
    public static func end(name: StaticString, details: String = String(), object: AnyObject? = nil) {
        placeSignpost(type: .end, name: name, details: details, object: object)
    }
    
    public static func event(name: StaticString, details: String = String(), object: AnyObject? = nil) {
        placeSignpost(type: .event, name: name, details: details, object: object)
    }
}
