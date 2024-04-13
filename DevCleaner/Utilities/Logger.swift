import Foundation

public class Logger {
    // MARK: Types
    public enum Level {
        case info,
             warning,
             error
    }
    
    // MARK: Properties
    public let level: Level
    public let name: String
    
    public var consoleLogging: Bool
    public var fileLogging: Bool {
        return self.logFileHandle != nil
    }
    
    public let logFilePath: URL?
    public let oldLogFilePath: URL?
    
    private let logFileHandle: FileHandle?
    
    // MARK: Initialization
    public init(name: String, level: Level = .error, toFile: Bool = false) {
        self.name = name
        self.level = level
        self.consoleLogging = true
        
        if toFile {
            // create logfile path
            let bundleId = Bundle.main.bundleIdentifier ?? "UnknownApp"
            let newLogFileName = "\(bundleId)-\(self.name)-LogFile-latest.log"
            let oldLogFileName = "\(bundleId)-\(self.name)-LogFile-previous.log"
            let documentsFolder = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            
            // create if needed & open log file to write
            if let newLogFilePath = documentsFolder?.appendingPathComponent(newLogFileName), let oldLogFilePath = documentsFolder?.appendingPathComponent(oldLogFileName) {
                // first rename current log to old if exists
                if FileManager.default.fileExists(atPath: newLogFilePath.path) {
                    try? FileManager.default.moveItem(at: newLogFilePath, to: oldLogFilePath)
                    self.oldLogFilePath = oldLogFilePath
                } else {
                    self.oldLogFilePath = nil
                }
                
                do {
                    FileManager.default.createFile(atPath: newLogFilePath.path, contents: nil, attributes: nil)
                    logFileHandle = try FileHandle(forWritingTo: newLogFilePath)
                    logFilePath = newLogFilePath
                } catch(let error) {
                    logFileHandle = nil
                    logFilePath = nil
                    NSLog("❌ Can't create log file: \(newLogFilePath.path). Error: \(error)")
                }
            } else {
                logFileHandle = nil
                logFilePath = nil
                oldLogFilePath = nil
            }
        } else {
            logFileHandle = nil
            logFilePath = nil
            oldLogFilePath = nil
        }
    }
    
    deinit {
        logFileHandle?.closeFile()
    }
    
    // MARK: Helpers
    private func writeLog(text: String, level: Level) {
        if self.consoleLogging {
            NSLog(text)
        }
        
        if let fileHandle = self.logFileHandle {
            let textToLogToFile = text + "\n" // add new line for each entry
            if let logData = textToLogToFile.data(using: .utf8) {
                fileHandle.write(logData)
                fileHandle.synchronizeFile()
            }
        }
    }
    
    // MARK: Log methods
    public func info(_ message: String) {
        switch self.level {
        case .info:
            writeLog(text: "❕ \(message)", level: .info)
            
        default:
            return
        }
    }
    
    public func warning(_ message: String) {
        switch self.level {
        case .info, .warning:
            writeLog(text: "⚠️ \(message)", level: .warning)
            
        default:
            return
        }
    }
    
    public func error(_ message: String) {
        switch self.level {
        case .info, .warning, .error:
            writeLog(text: "❌ \(message)", level: .error)
        }
    }
}
