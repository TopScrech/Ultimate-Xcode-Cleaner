import Cocoa

open class XcodeFileEntry: NSObject {
    // MARK: Types
    public enum Size: Comparable {
        case unknown, value(Int64)
        
        public var numberOfBytes: Int64? {
            switch self {
            case .value(let bytes):
                bytes
                
            default:
                nil
            }
        }
    }
    
    public enum Selection {
        case on, off, mixed
    }
    
    public enum Icon {
        case path(url: URL)
        case image(name: String)
        case system(name: NSImage.Name)
    }
    
    // MARK: Properties
    public let icon: Icon?
    public let label: String
    public let extraInfo: String
    public let tooltipText: String
    public let tooltip: Bool
    
    public var fullDescription: String {
        "\(label) \(extraInfo)"
    }
    
    public private(set) var selection: Selection
    public private(set) var size: Size
    public var selectedSize: Int64 {
        var result: Int64 = 0
        
        // sizes of children
        for item in items {
            result += item.selectedSize
        }
        
        // own size (only if selected and we have paths)
        if selection == .on && paths.count > 0 {
            result += size.numberOfBytes ?? 0
        }
        
        return result
    }
    
    public private(set) var paths: [URL]
    
    public private(set) weak var parent: XcodeFileEntry?
    public private(set) var items: [XcodeFileEntry]
    
    public var numberOfNonEmptyItems: Int {
        items.filter { !$0.isEmpty }.count
    }
    
    public var isEmpty: Bool {
        items.count == 0 && paths.count == 0
    }
    
    public var isSelected: Bool {
        selection != .off
    }
    
    // MARK: Initialization
    public init(label: String, extraInfo: String = String(), tooltipText: String? = nil, icon: Icon? = nil, tooltip: Bool = false, selected: Bool) {
        self.icon = icon
        self.label = label
        self.extraInfo = extraInfo
        self.tooltipText = (tooltipText ?? "\(label) \(extraInfo)").trimmingCharacters(in: .whitespacesAndNewlines)
        self.tooltip = tooltip
        
        self.selection = selected ? .on : .off
        self.size = .unknown
        
        self.paths = []
        self.items = []
        
        super.init()
    }
    
    // MARK: Manage children
    public func addChild(item: XcodeFileEntry) {
        // you can add path only if we have no children
        guard paths.count == 0 else {
            assertionFailure("❌ Cannot add child item to XcodeFileEntry if we already have paths!")
            return
        }
        
        item.parent = self
        items.append(item)
    }
    
    public func addChildren(items: [XcodeFileEntry]) {
        // you can add path only if we have no children
        guard paths.count == 0 else {
            assertionFailure("❌ Cannot add children items to XcodeFileEntry if we already have paths!")
            return
        }
        
        for item in items {
            item.parent = self
        }
        
        self.items.append(contentsOf: items)
    }
    
    public func removeAllChildren() {
        items.removeAll()
    }
    
    // MARK: Manage paths
    public func addPath(path: URL) {
        // you can add path only if we have no children
        guard items.count == 0 else {
            assertionFailure("❌ Cannot add paths to XcodeFileEntry if we already have children!")
            return
        }
        
        paths.append(path)
    }
    
    public func addPaths(paths: [URL]) {
        for path in paths {
            addPath(path: path)
        }
    }
    
    // MARK: Selection
    public func selectWithChildItems() {
        selection = .on
        
        for item in items {
            item.selectWithChildItems()
        }
    }
    
    public func deselectWithChildItems() {
        selection = .off
        
        for item in items {
            item.deselectWithChildItems()
        }
    }
    
    // MARK: Operations
    @discardableResult
    public func recalculateSize() -> Size? {
        var result: Int64 = 0
        
        // calculate sizes of children
        for item in items {
            if let size = item.recalculateSize(), let sizeInBytes = size.numberOfBytes {
                result += sizeInBytes
            }
        }
        
        // calculate own size
        let fileManager = FileManager.default
        
        for pathUrl in paths {
            if let dirSize = try? fileManager.allocatedSizeOfDirectory(atUrl: pathUrl) {
                result += dirSize
            } else if let fileSize = try? fileManager.allocatedSizeOfFile(at: pathUrl) {
                result += fileSize
            }
        }
        
        size = .value(result)
        
        return size
    }
    
    @discardableResult
    public func recalculateSizeIfNeeded() -> Size? {
        guard case .value(let size) = size else {
            return recalculateSize()
        }
        
        return .value(size)
    }
    
    @discardableResult
    public func recalculateSelection() -> Selection {
        var result: Selection
        
        // calculate selection for child items
        for item in items {
            item.recalculateSelection()
        }
        
        // calculate own selection
        if numberOfNonEmptyItems > 0 {
            let selectedItems = items.reduce(0) { (result, item) -> Int in
                return result + (item.isSelected ? 1 : 0)
            }
            
            if selectedItems == numberOfNonEmptyItems {
                if items.filter({ $0.selection == .mixed }).count > 0 {
                    result = .mixed
                } else {
                    result = .on
                }
            } else if selectedItems == 0 {
                result = .off
            } else {
                result = .mixed
            }
        } else {
            // with no items use current selection or deselect if its empty
            if isEmpty {
                result = .off
            } else {
                result = selection
            }
        }
        
        selection = result
        return result
    }
    
    public func clear() {
        removeAllChildren()
        paths.removeAll()
        size = .unknown
    }
    
    public func debugRepresentation(level: Int = 1) -> String {
        var result = String()
        
        // print own
        result += String(repeating: "\t", count: level)
        result += " \(label)"
        
        if let sizeInBytes = size.numberOfBytes {
            result += ": \(ByteCountFormatter.string(fromByteCount: sizeInBytes, countStyle: .file))"
        }
        
        result += "\n"
        
        // print children
        for item in items {
            result += item.debugRepresentation(level: level + 1)
        }
        
        return result
    }
}
