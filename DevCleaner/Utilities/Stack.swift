public struct Stack<T> {
    // MARK: Properties
    private var array = [T]()
    
    public var top: T? {
        array.last
    }
    
    public var count: Int {
        array.count
    }
    
    public var isEmpty: Bool {
        count == 0
    }
    
    // MARK: Manipulate stack
    public mutating func push(_ e: T) {
        self.array.append(e)
    }
    
    @discardableResult
    public mutating func pop() -> T? {
        array.popLast()
    }
}

extension Stack: CustomStringConvertible {
    public var description: String {
        let contents = array.map {
            "\($0)"
        }.reversed().joined(separator: ", ")
        
        return "[" + contents + "]"
    }
}
