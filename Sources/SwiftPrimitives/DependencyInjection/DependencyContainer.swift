/// A Simple Dependency Injection Container
public final class DependencyContainer: Sendable {
    
    /// Possible errors that can be encountered while resolving object.
    public enum ResolutionError: Error {
        /// Occurs when the requested type has not been registered and it cannot be automatically created
        case notFound

        /// Occurs when the factory method somehow returns an object that is not of the prescribed type
        case typeMismatch(expected: Any.Type, actual: Any.Type)
        
        /// Occurs when a class attempts to use a Resolver after it has expired
        case expired
    }
    
    private class SimpleResolver: Resolver {
        
        public let container: DependencyContainer
        private let factories: [ObjectIdentifier: (Resolver) throws -> Any]
        public private(set) var isExpired: Bool = false
        
        init(container: DependencyContainer, factories: [ObjectIdentifier: (Resolver) throws -> Any]) {
            self.container = container
            self.factories = factories
        }
        
        public func resolve<T>() throws -> T {
            guard !isExpired else {
                throw ResolutionError.expired
            }
            
            let id = ObjectIdentifier(T.self)
            if let factory = factories[id] {
                let untyped = try factory(self)
                guard let result = untyped as? T else {
                    throw ResolutionError.typeMismatch(expected: T.self, actual: type(of: untyped))
                }
                return result
            }
            
            if let autoresolvable = T.self as? Autoresolvable.Type {
                let instance = try autoresolvable.init(resolver: self)
                return instance as! T
            }
            
            if let defaultInit = T.self as? DefaultInitializable.Type {
                let instance = defaultInit.init()
                return instance as! T
            }
            
            throw ResolutionError.notFound
        }
        
        public func expire() {
            isExpired = true
        }
    }
    
    /// The intended way to construct a DependencyContainer.
    public struct Builder {
        private var factories: [ObjectIdentifier: (Resolver) throws -> Any] = [:]

        public init() { }
        
        /// Registers a closure to be invoked to create objects when the provided type is resolved.
        /// A new object is generated for each request.
        public func register<T>(as type: T.Type = T.self, factory: @escaping (Resolver) throws -> T) -> Self {
            var result = self
            let id = ObjectIdentifier(type)
            result.factories[id] = factory
            
            return result
        }
        
        /// Registers an object to be used when an object attempts to resolve the provided type.
        public func register<T>(as type: T.Type = T.self, singleton: T) -> Self {
            return register(as: type) { _ in singleton }
        }
        
        /// Registers a closure to create a singleton when it is first requested. Once created, that
        /// same object will be returned from all subsequent requests.
        public func registerLazySingleton<T>(as type: T.Type = T.self, factory: @escaping (Resolver) throws -> T) -> Self {
            var instance: T? = nil
            return register(as: type) { resolver in
                if let instance = instance {
                    return instance
                }
                instance = try factory(resolver)
                return instance!
            }
        }
        
        /// Called to generate the DependencyContainer when registrations are completed.
        public func build() -> DependencyContainer {
            DependencyContainer(factories: factories)
        }

    }
    
    private let factories: Synchronized<[ObjectIdentifier: (Resolver) throws -> Any]>
    
    private init(factories: [ObjectIdentifier: (Resolver) throws -> Any]) {
        // Since our closures for lazy methods aren't sendable and concurrent reentry safe,
        // we disable concurrent reads.
        self.factories = Synchronized(factories, allowConcurrentReads: false)
        
    }
        
    public func register<T>(as type: T.Type = T.self, factory: @escaping (Resolver) throws -> T) {

        let id = ObjectIdentifier(type)
        factories[id] = factory
    }
    
    public func register<T>(as type: T.Type = T.self, constructor: @escaping () -> T) {
        register(as: type) { _ in constructor() }
    }
    
    public func register<T>(as type: T.Type = T.self, singleton: T) {
        register(as: type) { _ in singleton }
    }
    
    public func registerLazySingleton<T>(as type: T.Type = T.self, factory: @escaping (Resolver) throws -> T) async {
        
        var instance: T? = nil
        register(as: type) { resolver in
            if let instance = instance {
                return instance
            }
            instance = try resolver.resolve()
            return instance!
        }
    }
    
    public func construct<T>(_ body: (Resolver) throws -> T) rethrows -> T {
        return try factories.using { factoriesUnwrapped in
            let resolver = SimpleResolver(container: self, factories: factoriesUnwrapped)
            let result = try body(resolver)
            resolver.expire()
            return result
        }
    }
    
    @preconcurrency
    public func constructAsync<T>(_ body: @Sendable @escaping (Resolver) throws -> T) async throws -> sending T {
        return try await factories.usingAsync { factoriesUnwrapped in
            let resolver = SimpleResolver(container: self, factories: factoriesUnwrapped)
            let result = try body(resolver)
            resolver.expire()
            return result
        }
    }
    
    public func resolve<T>() throws -> T {
        return try factories.using { factoriesUnwrapped in
            let resolver = SimpleResolver(container: self, factories: factoriesUnwrapped)
            let result: T = try resolver.resolve()
            resolver.expire()
            return result
        }
    }

    public func resolveAsync<T: Sendable>() async throws -> T {
        return try await factories.usingAsync { factoriesUnwrapped in
            let resolver = SimpleResolver(container: self, factories: factoriesUnwrapped)
            let result: T = try resolver.resolve()
            resolver.expire()
            return result
        }
    }

}
