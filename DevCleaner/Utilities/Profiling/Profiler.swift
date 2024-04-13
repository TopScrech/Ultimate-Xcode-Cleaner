import QuartzCore
import os

public final class Profiler {
    private typealias ProfilerEntry = (name: StaticString, description: String, usingSignpost: Bool, start: CFTimeInterval)
    private static var starts = [ProfilerEntry]()
    
    private static let signpostLog: OSLog = {
        guard let bundleId = Bundle.main.bundleIdentifier else {
            fatalError("Profiler: No bundleId defined in main bundle Infp.plist file?")
        }
        
        return OSLog(subsystem: bundleId + ".Profiler", category: .pointsOfInterest)
    }()
    
    public static func tick(name: StaticString = StaticString(), description: String = String(), useSignpost: Bool = false) {
        let tickTime = CACurrentMediaTime()
        let entry = (name: name, description: description, usingSignpost: useSignpost, start: tickTime)
        
        if useSignpost {
            os_signpost(.begin, dso: #dsohandle, log: Profiler.signpostLog, name: name, "%@", description as NSString)
        }
        
        starts.append(entry)
    }
    
    @discardableResult
    public static func tock(noLog silent: Bool = false) -> TimeInterval {
        let tockTime = CACurrentMediaTime() // get time here to avoid any influence of "tock" function logic
        var time: TimeInterval = 0
        
        if let lastEntry = starts.popLast() {
            time = tockTime - lastEntry.start
            
            if !silent {
                if lastEntry.usingSignpost {
                    if #available(iOS 12, *) {
                        os_signpost(.end, dso: #dsohandle, log: Profiler.signpostLog, name: lastEntry.name)
                    }
                }
                
                let number = starts.count
                let finalMessage: String
                
                if !lastEntry.name.description.isEmpty && !lastEntry.description.isEmpty {
                    finalMessage = "[Profile: \(number)][\(lastEntry.name) - \(lastEntry.description)]"
                } else if !lastEntry.name.description.isEmpty {
                    finalMessage = "[Profile: \(number)][\(lastEntry.name)]"
                } else {
                    finalMessage = "[Profile: \(number)]"
                }
                
                print(String(format: "\(finalMessage): %.f ms", time * 1000))
            }
        } else {
            print("Cannot stop profiling that haven't started yet!")
        }
        
        return time
    }
}
