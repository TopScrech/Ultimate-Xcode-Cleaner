import Foundation

extension FileManager {
    /// This method calculates the accumulated size of a directory on the volume in bytes.
    ///
    /// As there's no simple way to get this information from the file system it has to crawl the entire hierarchy,
    /// accumulating the overall sum on the way. The resulting value is roughly equivalent with the amount of bytes
    /// that would become available on the volume if the directory would be deleted.
    ///
    /// - note: There are a couple of oddities that are not taken into account (like symbolic links, meta data of
    /// directories, hard links, ...).
    public func allocatedSizeOfDirectory(atUrl url: URL) throws -> Int64 {
        // We'll sum up content size here:
        var accumulatedSize: Int64 = 0
        
        // prefetching some properties during traversal will speed up things a bit.
        let prefetchedProperties: [URLResourceKey] = [
            .isRegularFileKey,
            .fileAllocatedSizeKey,
            .totalFileAllocatedSizeKey
        ]
        
        // The error handler simply signals errors to outside code.
        var errorDidOccur: Error?
        let errorHandler: (URL, Error) -> Bool = { _, error in
            errorDidOccur = error
            return false
        }
        
        
        // We have to enumerate all directory contents, including subdirectories.
        let enumerator = self.enumerator(at: url,
                                         includingPropertiesForKeys: prefetchedProperties,
                                         options: FileManager.DirectoryEnumerationOptions.init(rawValue: 0),
                                         errorHandler: errorHandler)
        
        // Start the traversal:
        while let contentURL = (enumerator?.nextObject() as? URL)  {
            // Bail out on errors from the errorHandler.
            if let error = errorDidOccur { throw error }
            
            // Get the type of this item, making sure we only sum up sizes of regular files.
            let isRegularFileResourceValues = try contentURL.resourceValues(forKeys: [.isRegularFileKey])
            
            guard isRegularFileResourceValues.isRegularFile ?? false else {
                continue
            }
            
            // Get size values only if we're sure we calculating file size
            let resourceValues = try contentURL.resourceValues(forKeys: [.fileAllocatedSizeKey, .totalFileAllocatedSizeKey])
            
            // To get the file's size we first try the most comprehensive value in terms of what the file may use on disk.
            // This includes metadata, compression (on file system level) and block size.
            var fileSize = resourceValues.totalFileAllocatedSize
            
            // In case the value is unavailable we use the fallback value (excluding meta data and compression)
            // This value should always be available.
            fileSize = fileSize ?? resourceValues.fileAllocatedSize
            
            // We're good, add up the value.
            accumulatedSize += Int64(fileSize ?? 0)
        }
        
        // Bail out on errors from the errorHandler.
        if let error = errorDidOccur { throw error }
        
        // We finally got it.
        return accumulatedSize
    }
    
    public func allocatedSizeOfFile(at url: URL) throws -> Int64 {
        // Get the type of this item, making sure we only sum up sizes of regular files.
        let resourceValues = try url.resourceValues(forKeys: [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey])
        
        guard resourceValues.isRegularFile ?? false else {
            return 0
        }
        
        // To get the file's size we first try the most comprehensive value in terms of what the file may use on disk.
        // This includes metadata, compression (on file system level) and block size.
        var fileSize = resourceValues.totalFileAllocatedSize
        
        // In case the value is unavailable we use the fallback value (excluding meta data and compression)
        // This value should always be available.
        fileSize = fileSize ?? resourceValues.fileAllocatedSize
        
        return Int64(fileSize ?? 0)
    }
    
    public func volumeFreeDiskSpace(at url: URL) throws -> Int64 {
        do {
            let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            if let capacity = values.volumeAvailableCapacityForImportantUsage {
                return capacity
            }
        } catch let error {
            log.warning("FileManager+DirectorySize: Problem while requesting volume capacity: \(error)")
        }
        
        return 0
    }
}
