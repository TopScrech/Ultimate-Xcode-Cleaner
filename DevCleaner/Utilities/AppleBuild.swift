import Foundation

// MARK: AppleBuild struct
public struct AppleBuild {
    // MARK: Properties
    public let textual: String
    
    public let major: Int?
    public let minor: Character?
    public let daily: String?
    
    // MARK: Constants
    public static let empty = AppleBuild()
    
    // MARK: Initialization
    init() {
        self.textual = String()
        
        self.major = nil
        self.minor = nil
        self.daily = nil
    }
    
    init(string: String) {
        textual = string
        
        // parse build number according to this:
        // https://tidbits.com/2020/07/08/how-to-decode-apple-version-and-build-numbers/
        let scanner = Scanner(string: textual)
        scanner.caseSensitive = false
        
        self.major = scanner.scanInt()
        self.minor = scanner.scanCharacter()
        self.daily = scanner.string[scanner.currentIndex...].description
    }
}

// MARK: - Comparable implementation
extension AppleBuild: Comparable {
    public static func ==(lhs: AppleBuild, rhs: AppleBuild) -> Bool {
        if lhs.major == rhs.major {
            if lhs.minor == rhs.minor {
                let lhsDaily = lhs.daily ?? ""
                let rhsDaily = rhs.daily ?? ""
                
                if lhsDaily == rhsDaily {
                    return true
                }
            }
        }
        
        return false
    }
    
    public static func <(lhs: AppleBuild, rhs: AppleBuild) -> Bool {
        if lhs.major == rhs.major {
            if lhs.minor == rhs.minor {
                let lhsDaily = lhs.daily ?? ""
                let rhsDaily = rhs.daily ?? ""
                
                return lhsDaily.compare(rhsDaily) == .orderedAscending
            } else {
                let lhsMinor = lhs.minor ?? Character("")
                let rhsMinor = rhs.minor ?? Character("")
                
                return lhsMinor < rhsMinor
            }
        } else {
            let lhsMajor = lhs.major ?? 0
            let rhsMajor = rhs.major ?? 0
            
            return lhsMajor < rhsMajor
        }
    }
}

// MARK: - CustomStringConvertible conformance
extension AppleBuild: CustomStringConvertible {
    public var description: String {
        textual
    }
}
