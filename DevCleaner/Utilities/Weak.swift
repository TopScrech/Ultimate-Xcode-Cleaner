public class Weak<T: AnyObject>: Equatable {
    public private(set) weak var value: T?
    
    init(value: T?) {
        self.value = value
    }
    
    public static func == (lhs: Weak<T>, rhs: Weak<T>) -> Bool {
        lhs.value === rhs.value
    }
}
