import Foundation

public final class ArchiveFileEntry: XcodeFileEntry {
    // MARK: Types
    public enum SubmissionStatus {
        case success, 
             failure,
             undefined
        
        fileprivate var glyph: String {
            switch self {
            case .success: "✅"
            case .failure: "❌"
            case .undefined: String()
            }
        }
    }
    
    // MARK: Properties
    public let projectName: String
    public let bundleName: String
    public let versionString: String
    public let version: Version?
    public let build: String
    public let date: Date
    public let submissionStatus: SubmissionStatus
    
    public override var fullDescription: String {
        "\(projectName) \(versionString) (\(build)) (\(extraInfo))"
    }
    
    // MARK: Initialization
    public init(projectName: String, bundleName: String, version: String, build: String, date: Date, submissionStatus: SubmissionStatus, location: URL, selected: Bool) {
        self.projectName = projectName
        self.bundleName = bundleName
        self.versionString = version
        self.version = Version(describing: versionString)
        self.build = build
        self.date = date
        self.submissionStatus = submissionStatus
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        
        let dateString = dateFormatter.string(from: date)
        
        super.init(label: "\(versionString) (\(build)) \(submissionStatus.glyph)", extraInfo: dateString, icon: nil, tooltip: true, selected: selected)
        
        self.addPath(path: location)
    }
}
