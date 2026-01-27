import Foundation
import Logging
import Testing

@testable import SwiftPrimitives

extension Array {
    /// Helper to append multiple elements and return the appended elements.
    static func += (lhs: inout [Element], rhs: Element) {
        lhs.append(rhs)
    }
}

@Suite("CommonEventBus Tests")
struct CommonEventBusTests {

    // MARK: - Test Events

    struct TestEvent: Sendable, Equatable {
        let message: String
        let value: Int
    }

    struct AnotherTestEvent: Sendable, Equatable {
        let data: String
    }

    struct NumericEvent: Sendable, Equatable {
        let number: Int
    }

    // MARK: - Helper Properties

    public static func createEventBus() -> CommonEventBus {
        var logger = Logger(label: "io.Customer.SwiftPrimitives.CommonEventBusTests.Helper")
        logger.logLevel = .debug
        return CommonEventBus(logger: logger)
    }

    // MARK: - Initialization

    init() {
    }

    // MARK: - Basic Registration and Posting Tests

    @Test("Register observer returns valid token")
    func registerObserverReturnsValidToken() {

        // Given
        let eventBus = CommonEventBusTests.createEventBus()
        let token = eventBus.registerObserver { (event: TestEvent) in
            _ = event
        }

        // Then
        #expect(token.identifier != UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
    }

    @Test("Single observer receives posted event")
    func singleObserverReceivesEvent() async throws {
        // Given
        let eventBus = CommonEventBusTests.createEventBus()
        let testEvent = TestEvent(message: "Hello", value: 42)
        let receivedEvent = Synchronized<TestEvent?>(nil)

        let token = eventBus.registerObserver { (event: TestEvent) in
            receivedEvent.wrappedValue = event
        }

        // When
        eventBus.post(testEvent)

        // Wait for event processing
        try await Task.sleep(for: .milliseconds(500))

        // Then
        #expect(receivedEvent.wrappedValue == testEvent)
        _ = token
    }

    @Test("Multiple observers all receive event")
    func multipleObserversReceiveEvent() async throws {
        // Given
        let eventBus = CommonEventBusTests.createEventBus()
        let testEvent = TestEvent(message: "Broadcast", value: 100)
        let receivedEvents = Synchronized<[TestEvent]>([])

        var tokens: [RegistrationToken<UUID>] = []

        tokens += eventBus.registerObserver { (event: TestEvent) in
            receivedEvents.append(event)
        }

        tokens += eventBus.registerObserver { (event: TestEvent) in
            receivedEvents.append(event)
        }

        tokens += eventBus.registerObserver { (event: TestEvent) in
            receivedEvents.append(event)
        }

        // When
        eventBus.post(testEvent)

        // Wait for event processing
        try await Task.sleep(for: .milliseconds(500))

        // Then
        let events = receivedEvents.wrappedValue
        #expect(events.count == 3)
        #expect(events.allSatisfy { $0 == testEvent })
        _ = tokens
    }

    @Test("Only matching observers receive specific event types")
    func eventTypeFiltering() async throws {
        // Given
        let eventBus = CommonEventBusTests.createEventBus()
        let testEvent = TestEvent(message: "Test", value: 1)
        let anotherEvent = AnotherTestEvent(data: "Another")

        let receivedTestEvent = Synchronized<TestEvent?>(nil)
        let receivedAnotherEvent = Synchronized<AnotherTestEvent?>(nil)

        let token1 = eventBus.registerObserver { (event: TestEvent) in
            receivedTestEvent.wrappedValue = event
        }

        let token2 = eventBus.registerObserver { (event: AnotherTestEvent) in
            receivedAnotherEvent.wrappedValue = event
        }

        // When
        eventBus.post(testEvent)
        eventBus.post(anotherEvent)

        // Wait for event processing
        try await Task.sleep(for: .milliseconds(500))

        // Then
        #expect(receivedTestEvent == testEvent)
        #expect(receivedAnotherEvent == anotherEvent)
        _ = (token1, token2)
    }

    // MARK: - Token Deallocation Tests

    @Test("Token deallocation removes observer")
    func tokenDeallocationRemovesObserver() async throws {
        // Given
        let eventBus = CommonEventBusTests.createEventBus()
        let testEvent1 = TestEvent(message: "First", value: 1)
        let testEvent2 = TestEvent(message: "Second", value: 2)
        let eventCount = Synchronized<Int>(0)

        var token: RegistrationToken<UUID>? = eventBus.registerObserver { (event: TestEvent) in
            eventCount += 1
        }

        // When - Post first event
        eventBus.post(testEvent1)
        try await Task.sleep(for: .milliseconds(500))

        #expect(eventCount == 1)

        // Deallocate token
        token = nil
        try await Task.sleep(for: .milliseconds(100))

        // Post second event
        eventBus.post(testEvent2)
        try await Task.sleep(for: .milliseconds(500))

        // Then
        #expect(eventCount == 1, "Should only receive the first event")
    }

    // MARK: - No Observers Tests

    @Test("Posting event with no observers does not error")
    func postEventWithNoObservers() async throws {
        // Given
        let eventBus = CommonEventBusTests.createEventBus()
        let testEvent = TestEvent(message: "No listeners", value: 0)

        // When/Then - Should not crash or throw
        eventBus.post(testEvent)

        // Wait a bit to ensure processing completes
        try await Task.sleep(for: .milliseconds(100))
    }

    // MARK: - Concurrent Operations Tests

    @Test("Concurrent registration registers all observers")
    func concurrentRegistration() async throws {
        // Given
        let eventBus = CommonEventBusTests.createEventBus()
        let numberOfObservers = 50
        let testEvent = TestEvent(message: "Concurrent", value: 999)
        let eventCounts = Synchronized<[Int]>(Array(repeating: 0, count: numberOfObservers))
        let tokens = Synchronized<[RegistrationToken<UUID>]>([])

        // When - Register observers concurrently
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<numberOfObservers {
                group.addTask {
                    let token = eventBus.registerObserver { (event: TestEvent) in
                        eventCounts.mutating { $0[i] += 1 }
                    }
                    tokens.append(token)
                }
            }
        }

        // Wait for all registrations to complete
        try await Task.sleep(for: .milliseconds(200))

        // Post event
        eventBus.post(testEvent)

        // Wait for all observers to receive event
        try await Task.sleep(for: .seconds(1))

        // Then
        let totalEvents = eventCounts.using { $0.reduce(0, +) }
        #expect(totalEvents == numberOfObservers, "All observers should receive the event")
        _ = tokens
    }

    @Test("Concurrent posting delivers all events")
    func concurrentPosting() async throws {
        // Given
        let eventBus = CommonEventBusTests.createEventBus()
        let numberOfEvents = 20
        let receivedEvents = Synchronized<[NumericEvent]>([])

        let token = eventBus.registerObserver { (event: NumericEvent) in
            receivedEvents.append(event)
        }

        // When - Post events concurrently
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<numberOfEvents {
                group.addTask {
                    eventBus.post(NumericEvent(number: i))
                }
            }
        }

        // Wait for all events to be processed
        try await Task.sleep(for: .seconds(1))

        // Then
        let events = receivedEvents.wrappedValue
        #expect(events.count == numberOfEvents, "All events should be received")

        // Verify all numbers are present
        let receivedNumbers = Set(events.map { $0.number })
        let expectedNumbers = Set(0..<numberOfEvents)
        #expect(receivedNumbers == expectedNumbers, "All event numbers should be present")
        _ = token
    }

    // MARK: - PostAndWait Tests

    @Test("PostAndWait returns delivery summary")
    func postAndWaitReturnsDeliverySummary() async throws {
        // Given
        let eventBus = CommonEventBusTests.createEventBus()
        let testEvent = TestEvent(message: "Wait test", value: 42)
        let receivedEvent = Synchronized<TestEvent?>(nil)

        let token = eventBus.registerObserver { (event: TestEvent) in
            receivedEvent.wrappedValue = event
        }

        // When
        let summary = await eventBus.postAndWait(testEvent)

        // Then
        #expect(summary.registeredObservers == 1)
        #expect(summary.handlingObservers == 1)
        #expect(receivedEvent == testEvent)
        #expect(summary.completionTime >= summary.arrivalTime)
        _ = token
    }

    @Test("PostAndWait with multiple observers shows correct counts")
    func postAndWaitMultipleObservers() async throws {
        // Given
        let eventBus = CommonEventBusTests.createEventBus()
        let testEvent = TestEvent(message: "Multiple", value: 100)

        let token1 = eventBus.registerObserver { (event: TestEvent) in
            // Observer 1
        }

        let token2 = eventBus.registerObserver { (event: TestEvent) in
            // Observer 2
        }

        let token3 = eventBus.registerObserver { (event: AnotherTestEvent) in
            // This should not handle TestEvent
        }

        // When
        let summary = await eventBus.postAndWait(testEvent)

        // Then
        #expect(summary.registeredObservers == 3, "Total registered observers")
        #expect(summary.handlingObservers == 2, "Only TestEvent observers handle it")
        _ = (token1, token2, token3)
    }

    @Test("PostAndWait with no observers shows zero counts")
    func postAndWaitNoObservers() async throws {
        // Given
        let eventBus = CommonEventBusTests.createEventBus()
        let testEvent = TestEvent(message: "No observers", value: 0)

        // When
        let summary = await eventBus.postAndWait(testEvent)

        // Then
        #expect(summary.registeredObservers == 0)
        #expect(summary.handlingObservers == 0)
    }

    // MARK: - System Message Tests

    @Test("ObserverAddedMessage is posted on registration")
    func observerAddedMessage() async throws {
        // Given
        let eventBus = CommonEventBusTests.createEventBus()
        let receivedMessage = Synchronized<CommonEventBus.ObserverAddedMessage?>(nil)

        let token1 = eventBus.registerObserver { (message: CommonEventBus.ObserverAddedMessage) in
            receivedMessage.wrappedValue = message
        }

        // When
        let token2 = eventBus.registerObserver { (event: TestEvent) in
            // New observer
        }

        // Wait for message processing
        try await Task.sleep(for: .milliseconds(500))

        // Then
        let message = receivedMessage.wrappedValue
        #expect(message != nil)
        #expect(message?.handledType == TestEvent.self)
        _ = (token1, token2)
    }

    @Test("DeliverySummary is posted after normal event")
    func deliverySummaryPosted() async throws {
        // Given
        let eventBus = CommonEventBusTests.createEventBus()
        let receivedSummary = Synchronized<CommonEventBus.DeliverySummary?>(nil)

        let token1 = eventBus.registerObserver { (summary: CommonEventBus.DeliverySummary) in
            receivedSummary.wrappedValue = summary
        }

        let token2 = eventBus.registerObserver { (event: TestEvent) in
            // Test event observer
        }

        let testEvent = TestEvent(message: "Summary test", value: 123)

        // When
        eventBus.post(testEvent)

        // Wait for summary processing
        try await Task.sleep(for: .milliseconds(500))

        // Then
        let summary = receivedSummary.wrappedValue
        #expect(summary != nil)
        #expect(summary?.handlingObservers == 1)
        _ = (token1, token2)
    }

    // MARK: - Edge Cases

    @Test("Multiple events in sequence are all delivered")
    func multipleEventsInSequence() async throws {
        // Given
        let eventBus = CommonEventBusTests.createEventBus()
        let receivedMessages = Synchronized<[String]>([])

        let token = eventBus.registerObserver { (event: TestEvent) in
            receivedMessages.append(event.message)
        }

        let events = [
            TestEvent(message: "First", value: 1),
            TestEvent(message: "Second", value: 2),
            TestEvent(message: "Third", value: 3),
        ]

        // When
        for event in events {
            eventBus.post(event)
        }

        // Wait for all events to be processed
        try await Task.sleep(for: .seconds(1))

        // Then
        let messages = receivedMessages.wrappedValue
        #expect(messages.count == 3)
        #expect(messages.contains("First"))
        #expect(messages.contains("Second"))
        #expect(messages.contains("Third"))
        _ = token
    }

    @Test("Observer only receives matching event type")
    func observerOnlyReceivesMatchingType() async throws {
        // Given
        let eventBus = CommonEventBusTests.createEventBus()
        let testEventCount = Synchronized<Int>(0)

        let token = eventBus.registerObserver { (event: TestEvent) in
            testEventCount += 1
        }

        // When - Post multiple event types
        eventBus.post(TestEvent(message: "First", value: 1))
        eventBus.post(AnotherTestEvent(data: "Should not be received"))
        eventBus.post(NumericEvent(number: 42))
        eventBus.post(TestEvent(message: "Second", value: 2))

        // Wait for processing
        try await Task.sleep(for: .milliseconds(500))

        // Then
        #expect(testEventCount == 2, "Should only receive TestEvent instances")
        _ = token
    }

    @Test("Large number of events are all processed")
    func largeNumberOfEvents() async throws {
        // Given
        let eventBus = CommonEventBusTests.createEventBus()
        let numberOfEvents = 100
        let receivedCount = Synchronized<Int>(0)

        let token = eventBus.registerObserver { (event: NumericEvent) in
            receivedCount += 1
        }

        // When
        for i in 0..<numberOfEvents {
            eventBus.post(NumericEvent(number: i))
        }

        // Wait for all events to be processed
        try await Task.sleep(for: .seconds(2))

        // Then
        #expect(receivedCount == numberOfEvents, "All events should be processed")
        _ = token
    }

    // MARK: - Memory Management Tests

    @Test("Multiple token deallocation removes all observers")
    func multipleTokenDeallocation() async throws {
        // Given
        let eventBus = CommonEventBusTests.createEventBus()
        var tokens: [RegistrationToken<UUID>?] = []
        let eventCount = Synchronized<Int>(0)

        for _ in 0..<5 {
            let token = eventBus.registerObserver { (event: TestEvent) in
                eventCount += 1
            }
            tokens.append(token)
        }

        // When - Post first event
        eventBus.post(TestEvent(message: "First", value: 1))
        try await Task.sleep(for: .milliseconds(500))

        #expect(eventCount == 5, "All observers should receive first event")

        // Deallocate all tokens
        tokens.removeAll()
        try await Task.sleep(for: .milliseconds(100))

        // Reset count
        eventCount.wrappedValue = 0

        // Post second event
        eventBus.post(TestEvent(message: "Second", value: 2))
        try await Task.sleep(for: .milliseconds(500))

        // Then
        #expect(eventCount == 0, "No observers should receive second event")
    }
}
