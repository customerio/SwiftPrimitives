import Dispatch
import Foundation

/// A wrapper for primitive types to make them thread safe and able to conform to `Sendable`.
public final class Synchronized<T>: @unchecked Sendable {
    private let lock = NSRecursiveLock()
    private var _wrappedValue: T
    public var wrappedValue: T {
        get {
            lock.withLock {
                _wrappedValue
            }
        }
        set {
            lock.withLock {
                _wrappedValue = newValue
            }
        }
    }

    public init(_ initial: T) {
        self._wrappedValue = initial
    }

    /// Modify the wrapped value in a thread-safe manor.
    /// - Parameters:
    /// - body: The critical section of code that may modify the wrapped value.
    /// - Returns: The value returned from the inner function.
    public func mutating<Result>(_ body: (inout T) throws -> Result) rethrows -> Result {
        try lock.withLock {
            try body(&_wrappedValue)
        }
    }

    /// Modify the wrapped value in a thread-safe manor without blocking the current thread but
    /// asynchronously waiting for it to finish. The body will be executed atomically before the call returns.
    public func mutatingAsync<Result>(
        _ body: @Sendable (inout T) throws -> sending Result
    ) async throws -> Result {
        try await withoutActuallyEscaping(body) { escapingBody in
            try await withUnsafeThrowingContinuation { continuation in
                Task.detached {
                    let result = Swift.Result {
                        try self.lock.withLock {
                            try escapingBody(&self._wrappedValue)
                        }
                    }
                    continuation.resume(with: result)
                }
            }
        }
    }

    /// Modify the wrapped value in a thread-safe manor without blocking the current thread but
    /// asynchronously waiting for it to finish. The body will be executed atomically before the call returns.
    public func mutatingAsync<Result>(
        _ body: @Sendable (inout T) -> sending Result
    ) async -> sending Result {
        await withoutActuallyEscaping(body) { escapingBody in
            await withUnsafeContinuation { continuation in
                Task.detached {
                    let result = self.lock.withLock {
                        escapingBody(&self._wrappedValue)
                    }
                    continuation.resume(returning: result)
                }
            }
        }
    }

    /// Access the wrapped value in a thread-safe manor.
    /// - Parameters:
    ///  - body: The code to access the wrapped value. The return value is passed through and returned to the caller, leaving the original value unchanged.
    public func using<Result>(_ body: (T) throws -> Result) rethrows -> Result {
        try lock.withLock {
            try body(_wrappedValue)
        }
    }

    /// Access the wrapped value in a thread-safe manor without blocking the current thread but
    /// asynchronously waiting for it to finish. The body will be executed atomically before the call returns.
    public func usingAsync<Result>(
        _ body: @Sendable (T) throws -> sending Result
    ) async throws -> sending Result {
        try await withoutActuallyEscaping(body) { escapingBody in
            try await withUnsafeThrowingContinuation { continuation in
                Task.detached {
                    let result = Swift.Result {
                        try self.lock.withLock {
                            try escapingBody(self._wrappedValue)
                        }
                    }
                    continuation.resume(with: result)
                }
            }
        }
    }

    /// Modify the wrapped value in a thread-safe manor without blocking the current thread but
    /// asynchronously waiting for it to finish. The body will be executed atomically before the call returns.
    public func usingAsync<Result>(
        _ body: @Sendable (T) -> sending Result
    ) async -> sending Result {
        await withoutActuallyEscaping(body) { escapingBody in
            await withUnsafeContinuation { continuation in
                Task.detached {
                    let result = self.lock.withLock {
                        escapingBody(self._wrappedValue)
                    }
                    continuation.resume(returning: result)
                }
            }
        }
    }
}

extension Synchronized where T == Bool {
    public func toggle() {
        mutating { value in
            value.toggle()
        }
    }
}

extension Synchronized: Equatable where T: Equatable {
    public static func == (lhs: Synchronized<T>, rhs: Synchronized<T>) -> Bool {
        guard lhs !== rhs else { return true }

        return lhs.using { lhsValue in
            rhs.using { rhsValue in
                lhsValue == rhsValue
            }
        }
    }

    public static func == (lhs: Synchronized<T>, rhs: T) -> Bool {
        lhs.using { lhsValue in
            lhsValue == rhs
        }
    }

    public static func != (lhs: Synchronized<T>, rhs: T) -> Bool {
        lhs.using { lhsValue in
            lhsValue != rhs
        }
    }
}

extension Synchronized: Comparable where T: Comparable {
    public static func < (lhs: Synchronized<T>, rhs: Synchronized<T>) -> Bool {
        guard lhs !== rhs else { return false }

        return lhs.using { lhsValue in
            rhs.using { rhsValue in
                lhsValue < rhsValue
            }
        }
    }

    public static func <= (lhs: Synchronized<T>, rhs: Synchronized<T>) -> Bool {
        guard lhs !== rhs else { return true }

        return lhs.using { lhsValue in
            rhs.using { rhsValue in
                lhsValue <= rhsValue
            }
        }
    }

    public static func > (lhs: Synchronized<T>, rhs: Synchronized<T>) -> Bool {
        guard lhs !== rhs else { return false }

        return lhs.using { lhsValue in
            rhs.using { rhsValue in
                lhsValue > rhsValue
            }
        }
    }

    public static func >= (lhs: Synchronized<T>, rhs: Synchronized<T>) -> Bool {
        guard lhs !== rhs else { return true }

        return lhs.using { lhsValue in
            rhs.using { rhsValue in
                lhsValue >= rhsValue
            }
        }
    }
}

extension Synchronized where T: Comparable {
    public static func < (lhs: Synchronized<T>, rhs: T) -> Bool {
        lhs.using { lhsValue in
            lhsValue < rhs
        }
    }

    public static func <= (lhs: Synchronized<T>, rhs: T) -> Bool {
        lhs.using { lhsValue in
            lhsValue <= rhs
        }
    }

    public static func > (lhs: Synchronized<T>, rhs: T) -> Bool {
        lhs.using { lhsValue in
            lhsValue > rhs
        }
    }

    public static func >= (lhs: Synchronized<T>, rhs: T) -> Bool {
        lhs.using { lhsValue in
            lhsValue >= rhs
        }
    }
}

extension Synchronized: Hashable where T: Hashable {
    public func hash(into hasher: inout Hasher) {
        using { value in
            value.hash(into: &hasher)
        }
    }
}

extension Synchronized where T: AdditiveArithmetic {
    public static func + (lhs: Synchronized<T>, rhs: Synchronized<T>) -> T {
        guard lhs !== rhs else {
            return lhs.using { value in
                value + value
            }
        }

        return lhs.using { lhsValue in
            rhs.using { rhsValue in
                lhsValue + rhsValue
            }
        }
    }

    public static func + (lhs: Synchronized<T>, rhs: T) -> T {
        lhs.using { lhsValue in
            lhsValue + rhs
        }
    }

    public static func - (lhs: Synchronized<T>, rhs: Synchronized<T>) -> T {
        guard lhs !== rhs else { return .zero }

        return lhs.using { lhsValue in
            rhs.using { rhsValue in
                lhsValue - rhsValue
            }
        }
    }

    public static func - (lhs: Synchronized<T>, rhs: T) -> T {
        lhs.using { lhsValue in
            lhsValue - rhs
        }
    }

    public static func += (lhs: Synchronized<T>, rhs: Synchronized<T>) {
        guard lhs !== rhs else {
            lhs.mutating { value in
                value += value
            }
            return
        }
        lhs.mutating { lhsValue in
            rhs.using { rhsValue in
                lhsValue += rhsValue
            }
        }
    }

    public static func += (lhs: Synchronized<T>, rhs: T) {
        lhs.mutating { lhsValue in
            lhsValue += rhs
        }
    }

    public static func -= (lhs: Synchronized<T>, rhs: Synchronized<T>) {
        guard lhs !== rhs else {
            lhs.wrappedValue = .zero
            return
        }

        lhs.mutating { lhsValue in
            rhs.using { rhsValue in
                lhsValue -= rhsValue
            }
        }
    }

    public static func -= (lhs: Synchronized<T>, rhs: T) {
        lhs.mutating { lhsValue in
            lhsValue -= rhs
        }
    }
}

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

extension Synchronized where T: Collection {
    public var count: Int {
        using { value in value.count }
    }

    public var isEmpty: Bool {
        using { value in value.isEmpty }
    }
}

extension Synchronized where T: MutableCollection {
    public subscript(position: T.Index) -> T.Element {
        get {
            using { value in
                value[position]
            }
        }
        set {
            mutating { value in
                value[position] = newValue
            }
        }
    }
}

extension Synchronized where T: RangeReplaceableCollection {
    public static func += <S>(lhs: Synchronized<T>, rhs: S)
    where S: Sequence, T.Element == S.Element {
        lhs.append(contentsOf: rhs)
    }

    public static func += (lhs: Synchronized<T>, rhs: T.Element) {
        lhs.append(rhs)
    }

    public func append(_ newElement: T.Element) {
        mutating { value in
            value.append(newElement)
        }
    }

    public func append<S>(contentsOf newElements: S) where S: Sequence, T.Element == S.Element {
        mutating { value in
            value.append(contentsOf: newElements)
        }
    }

    public func insert(_ newElement: T.Element, at i: T.Index) {
        mutating { value in
            value.insert(newElement, at: i)
        }
    }

    public func insert<S>(contentsOf newElements: S, at i: T.Index)
    where S: Collection, T.Element == S.Element {
        mutating { value in
            value.insert(contentsOf: newElements, at: i)
        }
    }

    public func removeAll(keepingCapacity keepCapacity: Bool = false) {
        mutating { value in
            value.removeAll(keepingCapacity: keepCapacity)
        }
    }
}
