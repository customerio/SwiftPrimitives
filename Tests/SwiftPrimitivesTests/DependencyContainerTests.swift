import SwiftPrimitives
import Testing

struct DependencyContainerTests {

    @Test
    func testSimpleBuilder() async throws {

        let container: DependencyContainer = DependencyContainer.Builder()
            .register(singleton: "TestString")
            .register { _ in 42 }
            .build()

        let string: String = try await container.resolve()
        #expect(string == "TestString")

        let int: Int = try await container.resolve()
        #expect(int == 42)
    }

    @Test
    func testLazyConstruction() async throws {

        let constructorRun: Synchronized<Bool> = .init(false)

        let container: DependencyContainer = DependencyContainer.Builder()
            .registerLazySingleton { _ in
                constructorRun.wrappedValue = true
                return "LazyString"
            }
            .build()
        #expect(!constructorRun.wrappedValue)
        let string: String = try await container.resolve()
        #expect(string == "LazyString")
        #expect(constructorRun.wrappedValue)
    }

    @Test
    func testPostBuildRegistrationChange() async throws {

        let container: DependencyContainer = DependencyContainer.Builder()
            .register(singleton: "TestString")
            .register { _ in 42 }
            .build()

        await container.register(singleton: "UpdatedString")

        let string: String = try await container.resolve()
        #expect(string == "UpdatedString")

        let int: Int = try await container.resolve()
        #expect(int == 42)
    }

    @Test
    func testAutoAndDefaultConstructors() async throws {

        struct MyDefaultInitializable: DefaultInitializable {}
        struct MyAutoResolvable: Autoresolvable {
            init(resolver: borrowing any Resolver) throws {}
        }

        let container: DependencyContainer = DependencyContainer.Builder().build()

        let _: MyDefaultInitializable = try await container.resolve()
        let _: MyAutoResolvable = try await container.resolve()
    }

    @Test
    func testChainedResolutions() async throws {

        struct MyDefaultInitializable: DefaultInitializable {}
        struct MyAutoResolvable: Autoresolvable {
            var myString: String
            init(resolver: any Resolver) throws {
                myString = try resolver.resolve()
                let _: MyDefaultInitializable = try resolver.resolve()

            }
        }

        let container: DependencyContainer = DependencyContainer.Builder()
            .register(singleton: "TestString")
            .build()

        let _: MyAutoResolvable = try await container.resolve()
    }

    @Test
    func testResolvingThrowsIfCannotBeResolved() async throws {

        struct NonExistant {}

        let container: DependencyContainer = DependencyContainer.Builder().build()

        do {
            let _: NonExistant = try await container.resolve()
            Issue.record("Expected an error to be thrown")
        } catch {}
    }

    @Test
    func testSingletonResolution() async throws {

        struct InitCounter: DefaultInitializable {
            static let initCount: Synchronized<Int> = .init(0)
            init() {
                Self.initCount += 1
            }
        }

        let container: DependencyContainer = DependencyContainer.Builder().build()

        #expect(InitCounter.initCount == 0)
        let instance1: InitCounter = try await container.resolve()
        #expect(InitCounter.initCount == 1)
        let _: InitCounter = try await container.resolve()
        #expect(InitCounter.initCount == 2)

        await container.register(singleton: instance1)

        let _: InitCounter = try await container.resolve()
        #expect(InitCounter.initCount == 2)
        let _: InitCounter = try await container.resolve()
        #expect(InitCounter.initCount == 2)
    }
}
