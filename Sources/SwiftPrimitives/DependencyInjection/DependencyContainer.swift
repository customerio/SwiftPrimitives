/// A Simple Dependency Injection Container
public actor DependencyContainer {

    private static func makeSingletonFactory<T: Sendable>(
        as type: T.Type = T.self,
        factory: @Sendable @escaping (borrowing any Resolver) throws -> T
    ) -> @Sendable (borrowing any Resolver) throws -> sending T {
        let instance: Synchronized<T?> = Synchronized(nil)
        return { resolver in
            try instance.mutating { value in
                if let existing = value {
                    return existing
                }
                let newInstance = try factory(resolver)
                value = newInstance
                return newInstance
            }
        }
    }

    /// Possible errors that can be encountered while resolving object.
    public enum ResolutionError: Error {
        /// Occurs when the requested type has not been registered and it cannot be automatically created
        case notFound

        /// Occurs when the factory method somehow returns an object that is not of the prescribed type
        case typeMismatch(expected: Any.Type, actual: Any.Type)

        /// Occurs when a class attempts to use a Resolver after it has expired
        case expired
    }

    private struct SimpleResolver: Resolver {

        public let container: DependencyContainer
        private let factories:
            [ObjectIdentifier: @Sendable (borrowing any Resolver) throws -> sending Any]

        init(
            container: DependencyContainer,
            factories: [ObjectIdentifier: @Sendable (borrowing any Resolver) throws -> sending Any]
        ) {
            self.container = container
            self.factories = factories
        }

        public func resolve<T>() throws -> sending T {
            let id = ObjectIdentifier(T.self)

            if let factory: (any Resolver) throws -> sending Any = factories[id] {
                let untyped = try factory(self)
                guard let result = untyped as? T else {
                    throw ResolutionError.typeMismatch(expected: T.self, actual: type(of: untyped))
                }
                return result
            }

            if let autoresolvable = T.self as? Autoresolvable.Type {
                let instance = try autoresolvable.init(resolver: self)
                guard let result = instance as? T else {
                    throw ResolutionError.typeMismatch(expected: T.self, actual: type(of: instance))
                }
                return result
            }

            if let defaultInit = T.self as? DefaultInitializable.Type {
                let instance = defaultInit.init()
                guard let result = instance as? T else {
                    throw ResolutionError.typeMismatch(expected: T.self, actual: type(of: instance))
                }
                return result
            }

            throw ResolutionError.notFound
        }
    }

    /// The intended way to construct a DependencyContainer.
    public struct Builder {
        private let factories:
            [ObjectIdentifier: @Sendable (borrowing any Resolver) throws -> sending Any]

        public init() {
            self.factories = [:]
        }

        private init(
            factories: [ObjectIdentifier: @Sendable (borrowing any Resolver) throws -> sending Any]
        ) {
            self.factories = factories
        }

        /// Registers a closure to be invoked to create objects when the provided type is resolved.
        /// A new object is generated for each request.
        public func register<T>(
            as type: T.Type = T.self,
            factory: @Sendable @escaping (borrowing any Resolver) throws -> sending T
        ) -> Self {
            var factories = self.factories
            let id = ObjectIdentifier(type)
            factories[id] = factory
            return Builder(factories: factories)
        }

        /// Registers an object to be used when an object attempts to resolve the provided type.
        public func register<T: Sendable>(as type: T.Type = T.self, singleton: T) -> Self {
            return register(as: type) { _ in singleton }
        }

        /// Registers a closure to create a singleton when it is first requested. Once created, that
        /// same object will be returned from all subsequent requests.
        public func registerLazySingleton<T: Sendable>(
            as type: T.Type = T.self,
            factory: @Sendable @escaping (borrowing any Resolver) throws -> T
        ) -> Self {
            return register(
                as: type,
                factory: DependencyContainer.makeSingletonFactory(as: type, factory: factory)
            )
        }

        /// Called to generate the DependencyContainer when registrations are completed.
        public func build() -> DependencyContainer {
            let copy = self.factories
            return DependencyContainer(factories: copy)
        }
    }

    private var factories:
        [ObjectIdentifier: @Sendable (borrowing any Resolver) throws -> sending Any]

    private init(
        factories: [ObjectIdentifier: @Sendable (borrowing any Resolver) throws -> sending Any]
    ) {
        self.factories = factories
    }

    /// Registers a closure to be invoked to create objects when the provided type is resolved.
    /// A new object is generated for each request.
    public func register<T>(
        as type: T.Type = T.self,
        factory: @Sendable @escaping (borrowing any Resolver) throws -> sending T
    ) {
        let id = ObjectIdentifier(type)
        factories[id] = factory
    }
    /// Registers an object to be used when an object attempts to resolve the provided type.
    public func register<T: Sendable>(as type: T.Type = T.self, singleton: T) {
        return register(as: type) { _ in singleton }
    }

    /// Registers a closure to create a singleton when it is first requested. Once created, that
    /// same object will be returned from all subsequent requests.
    public func registerLazySingleton<T: Sendable>(
        as type: T.Type = T.self,
        factory: @Sendable @escaping (borrowing any Resolver) throws -> T
    ) {
        register(
            as: type,
            factory: Self.makeSingletonFactory(as: type, factory: factory)
        )
    }
    /// Construct an object using the dependency container to resolve dependencies within the provided closure.
    public func construct<T>(_ body: (borrowing any Resolver) throws -> sending T) rethrows
        -> sending T
    {
        let resolver = SimpleResolver(container: self, factories: factories)
        let result = try body(resolver)
        return result
    }

    /// Resolves an object of the specified type from the container.
    public func resolve<T>() throws -> sending T {
        let resolver = SimpleResolver(container: self, factories: factories)
        let result: T = try resolver.resolve()
        return result
    }
}
