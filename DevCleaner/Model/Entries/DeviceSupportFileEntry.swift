import Foundation

public final class DeviceSupportFileEntry: XcodeFileEntry {
    // MARK: Types
    public enum OSType {
        case iOS, watchOS, tvOS, macOS, visionOS, other
        
        public init(label: String) {
            switch label {
            case "iOS":
                self = .iOS
                
            case "watchOS":
                self = .watchOS
                
            case "tvOS":
                self = .tvOS
                
            case "macOS":
                self = .macOS
                
            case "visionOS":
                self = .visionOS
                
            default:
                self = .other
            }
        }
        
        public var description: String {
            switch self {
            case .iOS:      "iOS"
            case .watchOS:  "watchOS"
            case .tvOS:     "tvOS"
            case .macOS:    "macOS"
            case .visionOS: "visionOS"
            case .other:    ""
            }
        }
    }
    
    // MARK: Properties
    public let device: String?
    public let osType: OSType
    public let version: Version
    public let build: AppleBuild?
    public let date: Date
    public let architecture: String?
    
    // MARK: Initialization
    public init(device: String?, osType: OSType, version: Version, build: AppleBuild?, date: Date, arch: String?, selected: Bool) {
        self.device = device
        self.osType = osType
        self.version = version
        self.build = build
        self.date = date
        self.architecture = arch
        
        let label = Self.label(for: osType, device: device, version: version, build: build)
        let icon = Self.icon(for: osType, version: version)
        let tooltip = label + " " + DateFormatter.localizedString(from: self.date, dateStyle: .medium, timeStyle: .none)
        
        super.init(label: label, tooltipText: tooltip, icon: icon, tooltip: true, selected: selected)
    }
    
    // MARK: Helpers
    private static func label(for os: OSType, device: String?, version: Version, build: AppleBuild?) -> String {
        let appleBuild = build ?? .empty
        
        var result = "\(os.description) \(version) \(appleBuild)"
        
        if let device {
            result = result + " (\(Self.modelName(from: device)))"
        }
        
        return result
    }
    
    private static func icon(for os: OSType, version: Version) -> Icon {
        var result: Icon
        
        switch os {
        case .iOS:
            if version.major >= 2 && version.major <= 17 {
                result = .image(name: "OS/iOS/\(version.major)")
            } else {
                result = .image(name: "OS/iOS/Generic")
            }
            
        case .watchOS:
            if version.major >= 2 && version.major <= 10 {
                result = .image(name: "OS/watchOS/\(version.major)")
            } else {
                result = .image(name: "OS/watchOS/Generic")
            }
            
        case .tvOS:
            if version.major >= 9 && version.major <= 17 {
                result = .image(name: "OS/tvOS/\(version.major)")
            } else {
                result = .image(name: "OS/tvOS/Generic")
            }
            
        case .macOS:
            if version.major >= 12 && version.major <= 14 {
                result = .image(name: "OS/macOS/\(version.major)")
            } else {
                result = .image(name: "OS/macOS/Generic")
            }
            
        case .visionOS:
            // there's just one visionOS version so no logo was actually presented
            result = .image(name: "OS/visionOS/Generic")
            
        default:
            result = .image(name: "OS/iOS/Generic")
        }
        
        return result
    }
    
    // MARK: Map device model to device name
    private static func modelName(from deviceId: String) -> String {
        switch deviceId {
            // iPod touch
        case "iPod1,1":
            "iPod touch"
            
        case "iPod2,1":
            "iPod touch (2nd generation)"
            
        case "iPod3,1":
            "iPod touch (3rd generation)"
            
        case "iPod4,1":
            "iPod touch (4th generation)"
            
        case "iPod5,1":
            "iPod touch (5th generation)"
            
        case "iPod7,1":
            "iPod touch (6th generation)"
            
        case "iPod9,1":
            "iPod touch (7th generation)"
            
            // iPhone
        case "iPhone1,1":
            "iPhone"
            
        case "iPhone1,2":
            "iPhone 3G"
            
        case "iPhone2,1":
            "iPhone 3GS"
            
        case "iPhone3,1", "iPhone3,2", "iPhone3,3":
            "iPhone 4"
            
        case "iPhone4,1":
            "iPhone 4s"
            
        case "iPhone5,1", "iPhone5,2":
            "iPhone 5"
            
        case "iPhone5,3", "iPhone5,4":
            "iPhone 5c"
            
        case "iPhone6,1", "iPhone6,2":
            "iPhone 5s"
            
        case "iPhone7,2":
            "iPhone 6"
            
        case "iPhone7,1":
            "iPhone 6 Plus"
            
        case "iPhone8,1":
            "iPhone 6s"
            
        case "iPhone8,2":
            "iPhone 6s Plus"
            
        case "iPhone9,1", "iPhone9,3":
            "iPhone 7"
            
        case "iPhone9,2", "iPhone9,4":
            "iPhone 7 Plus"
            
        case "iPhone10,1", "iPhone10,4":
            "iPhone 8"
            
        case "iPhone10,2", "iPhone10,5":
            "iPhone 8 Plus"
            
        case "iPhone10,3", "iPhone10,6":
            "iPhone X"
            
        case "iPhone11,2":
            "iPhone XS"
            
        case "iPhone11,4", "iPhone11,6":
            "iPhone XS Max"
            
        case "iPhone11,8":
            "iPhone XR"
            
        case "iPhone12,1":
            "iPhone 11"
            
        case "iPhone12,3":
            "iPhone 11 Pro"
            
        case "iPhone12,5":
            "iPhone 11 Pro Max"
            
        case "iPhone13,1":
            "iPhone 12 mini"
            
        case "iPhone13,2":
            "iPhone 12"
            
        case "iPhone13,3":
            "iPhone 12 Pro"
            
        case "iPhone13,4":
            "iPhone 12 Pro Max"
            
        case "iPhone14,4":
            "iPhone 13 mini"
            
        case "iPhone14,5":
            "iPhone 13"
            
        case "iPhone14,2":
            "iPhone 13 Pro"
            
        case "iPhone14,3":
            "iPhone 13 Pro Max"
            
        case "iPhone14,7":
            "iPhone 14"
            
        case "iPhone14,8":
            "iPhone 14 Plus"
            
        case "iPhone15,2":
            "iPhone 14 Pro"
            
        case "iPhone15,3":
            "iPhone 14 Pro Max"
            
        case "iPhone15,4":
            "iPhone 15"
            
        case "iPhone15,5":
            "iPhone 15 Plus"
            
        case "iPhone16,1":
            "iPhone 15 Pro"
            
        case "iPhone16,2":
            "iPhone 15 Pro Max"
            
        case "iPhone8,4":
            "iPhone SE"
            
        case "iPhone12,8":
            "iPhone SE (2nd generation)"
            
        case "iPhone14,6":
            "iPhone SE (3rd generation)"
            
            // iPad
        case "iPad1,1":
            "iPad"
            
        case "iPad2,1", "iPad2,2", "iPad2,3", "iPad2,4":
            "iPad 2"
            
        case "iPad3,1", "iPad3,2", "iPad3,3":
            "iPad (3rd generation)"
            
        case "iPad3,4", "iPad3,5", "iPad3,6":
            "iPad (4th generation)"
            
        case "iPad6,11", "iPad6,12":
            "iPad (5th generation)"
            
        case "iPad7,5", "iPad7,6":
            "iPad (6th generation)"
            
        case "iPad7,11", "iPad7,12":
            "iPad (7th generation)"
            
        case "iPad11,6", "iPad11,7":
            "iPad (8th generation)"
            
        case "iPad12,1", "iPad12,2":
            "iPad (9th generation)"
            
        case "iPad13,18", "iPad13,19":
            "iPad (10th generation)"
            
        case "iPad4,1", "iPad4,2", "iPad4,3":
            "iPad Air"
            
        case "iPad5,3", "iPad5,4":
            "iPad Air 2"
            
        case "iPad11,3", "iPad11,4":
            "iPad Air (3rd generation)"
            
        case "iPad13,1", "iPad13,2":
            "iPad Air (4th generation)"
            
        case "iPad13,16", "iPad13,17":
            "iPad Air (5th generation)"
            
        case "iPad2,5", "iPad2,6", "iPad2,7":
            "iPad mini"
            
        case "iPad4,4", "iPad4,5", "iPad4,6":
            "iPad mini 2"
            
        case "iPad4,7", "iPad4,8", "iPad4,9":
            "iPad mini 3"
            
        case "iPad5,1", "iPad5,2":
            "iPad mini 4"
            
        case "iPad11,1", "iPad11,2":
            "iPad mini (5th generation)"
            
        case "iPad14,1", "iPad14,2":
            "iPad mini (6th generation)"
            
        case "iPad6,3", "iPad6,4":
            "iPad Pro (9.7-inch)"
            
        case "iPad7,3", "iPad7,4":
            "iPad Pro (10.5-inch)"
            
        case "iPad8,1", "iPad8,2", "iPad8,3", "iPad8,4":
            "iPad Pro (11-inch) (1st generation)"
            
        case "iPad8,9", "iPad8,10":
            "iPad Pro (11-inch) (2nd generation)"
            
        case "iPad13,4", "iPad13,5", "iPad13,6", "iPad13,7":
            "iPad Pro (11-inch) (3rd generation)"
            
        case "iPad14,3", "iPad14,4":
            "iPad Pro (11-inch) (4th generation)"
            
        case "iPad6,7", "iPad6,8":
            "iPad Pro (12.9-inch) (1st generation)"
            
        case "iPad7,1", "iPad7,2":
            "iPad Pro (12.9-inch) (2nd generation)"
            
        case "iPad8,5", "iPad8,6", "iPad8,7", "iPad8,8":
            "iPad Pro (12.9-inch) (3rd generation)"
            
        case "iPad8,11", "iPad8,12":
            "iPad Pro (12.9-inch) (4th generation)"
            
        case "iPad13,8", "iPad13,9", "iPad13,10", "iPad13,11":
            "iPad Pro (12.9-inch) (5th generation)"
            
        case "iPad14,5", "iPad14,6":
            "iPad Pro (12.9-inch) (6th generation)"
            
            // Apple Watch
        case "Watch1,1", "Watch1,2":
            "Apple Watch (1st generation)"
            
        case "Watch2,6", "Watch2,7":
            "Apple Watch Series 1"
            
        case "Watch2,3", "Watch2,4":
            "Apple Watch Series 2"
            
        case "Watch3,1", "Watch3,2", "Watch3,3", "Watch3,4":
            "Apple Watch Series 3"
            
        case "Watch4,1", "Watch4,2", "Watch4,3", "Watch4,4":
            "Apple Watch Series 4"
            
        case "Watch5,1", "Watch5,2", "Watch5,3", "Watch5,4":
            "Apple Watch Series 5"
            
        case "Watch5,9", "Watch5,10", "Watch5,11", "Watch5,12":
            "Apple Watch SE"
            
        case "Watch6,1", "Watch6,2", "Watch6,3", "Watch6,4":
            "Apple Watch Series 6"
            
        case "Watch6,6", "Watch6,7", "Watch6,8", "Watch6,9":
            "Apple Watch Series 7"
            
        case "Watch6,10", "Watch6,11", "Watch6,12", "Watch6,13":
            "Apple Watch SE (2nd generation)"
            
        case "Watch6,14", "Watch6,15", "Watch6,16", "Watch6,17":
            "Apple Watch Series 8"
            
        case "Watch6,18":
            "Apple Watch Ultra"
            
            // Apple TV
        case "AppleTV5,3":
            "Apple TV"
            
        case "AppleTV6,2":
            "Apple TV 4K"
            
        case "AppleTV11,1":
            "Apple TV 4K (2nd generation)"
            
            // HomePod
        case "AudioAccessory1,1":
            "HomePod"
            
        case "AudioAccessory5,1":
            "HomePod mini"
            
            // Vision Pro
        case "RealityDevice14,1":
            "Apple Vision Pro"
            
        default:
            deviceId
        }
    }
}
