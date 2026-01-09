import Testing

import SwiftPrimitives

struct DependencyContainerTests {

    @Test
    func testSimpleBuilder() throws {

        let container: DependencyContainer = DependencyContainer.Builder()
            .register(singleton: "TestString")
            .register { _ in 42 }
            .build()

        let string: String = try container.resolve()
        #expect(string == "TestString")

        let int: Int = try container.resolve()
        #expect(int == 42)
    }

    @Test
    func testLazyConstruction() throws {

        var constructorRun: Bool = false

        let container: DependencyContainer = DependencyContainer.Builder()
            .registerLazySingleton { _ in
                constructorRun = true
                return "LazyString"
            }
            .build()
        #expect(!constructorRun)
        let string: String = try container.resolve()
        #expect(string == "LazyString")
        #expect(constructorRun)
    }

    @Test
    func testPostBuildRegistrationChange() throws {

        let container: DependencyContainer = DependencyContainer.Builder()
            .register(singleton: "TestString")
            .register { _ in 42 }
            .build()

        container.register(singleton: "UpdatedString")

        let string: String = try container.resolve()
        #expect(string == "UpdatedString")

        let int: Int = try container.resolve()
        #expect(int == 42)
    }

    @Test
    func testAutoAndDefaultConstructors() throws {

        struct MyDefaultInitializable: DefaultInitializable { }
        struct MyAutoResolvable: Autoresolvable {
            init(resolver: any Resolver) throws { }
        }

        let container: DependencyContainer = DependencyContainer.Builder().build()

        let _: MyDefaultInitializable = try container.resolve()
        let _: MyAutoResolvable = try container.resolve()
    }

    @Test
    func testChainedResolutions() throws {

        struct MyDefaultInitializable: DefaultInitializable { }
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

        let _: MyAutoResolvable = try container.resolve()
    }

    @Test
    func testResolvingThrowsIfCannotBeResolved() async throws {

        struct NonExistant { }

        let container: DependencyContainer = DependencyContainer.Builder().build()

        do {
            let _: NonExistant = try container.resolve()
            Issue.record("Expected an error to be thrown")
        } catch { }
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
        let instance1: InitCounter = try container.resolve()
        #expect(InitCounter.initCount == 1)
        let _: InitCounter = try container.resolve()
        #expect(InitCounter.initCount == 2)

        container.register(singleton: instance1)

        let _: InitCounter = try container.resolve()
        #expect(InitCounter.initCount == 2)
        let _: InitCounter = try container.resolve()
        #expect(InitCounter.initCount == 2)
    }

    @Test
    func testFailsAfterExpiration() async throws {

        struct MyAutoResolvable: Autoresolvable {
            static let savedResolver: Synchronized<Resolver?> = .init(nil)
            var myString: String
            init(resolver: any Resolver) throws {
                Self.savedResolver.wrappedValue = resolver
                myString = try resolver.resolve()
            }
        }

        let container: DependencyContainer = DependencyContainer.Builder()
            .register(singleton: "TestString")
            .register { _ in 42 }
            .build()

        #expect(MyAutoResolvable.savedResolver.wrappedValue == nil)
        let _: MyAutoResolvable = try container.resolve()
        #expect(MyAutoResolvable.savedResolver.wrappedValue != nil)

        do {

            let _: String = try MyAutoResolvable.savedResolver.wrappedValue!.resolve()

            Issue.record("Expected an error to be thrown")
        } catch let error as DependencyContainer.ResolutionError {
            if case DependencyContainer.ResolutionError.expired = error {
                // Expected error
            } else {
                Issue.record("Wrong error type thrown")
            }
        }
    }

}
