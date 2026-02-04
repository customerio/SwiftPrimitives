public protocol DictionaryProtocol {
    associatedtype Key: Hashable
    associatedtype Value

    subscript(key: Key) -> Value? { get set }
    mutating func removeValue(forKey key: Key) -> Value?
}

extension Dictionary: DictionaryProtocol {}

extension Synchronized: DictionaryProtocol where T: DictionaryProtocol {
    public typealias Key = T.Key
    public typealias Value = T.Value

    public subscript(key: Key) -> Value? {
        get {
            using { value in
                value[key]
            }
        }
        set {
            mutating { value in
                value[key] = newValue
            }
        }
    }

    @discardableResult
    public func removeValue(forKey key: Key) -> Value? {
        var result: Value?
        mutating { value in
            result = value.removeValue(forKey: key)
        }
        return result
    }
}
