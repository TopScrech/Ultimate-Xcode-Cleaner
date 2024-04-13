import Foundation

extension FileManager {
    public var realHomeDirectoryForCurrentUser: URL {
        let pw = getpwuid(getuid())!
        let home = pw.pointee.pw_dir!
        let homePath = FileManager.default.string(withFileSystemRepresentation: home, length: Int(strlen(home)))
        
        return URL(fileURLWithPath: homePath, isDirectory: true)
    }
}
