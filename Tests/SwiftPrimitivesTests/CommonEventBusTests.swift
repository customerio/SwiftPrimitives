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

    let eventBus: CommonEventBus
    let logger: Logger

    // MARK: - Initialization

    init() {
        var logger = Logger(label: "com.test.CommonEventBusTests")
        logger.logLevel = .debug
        self.logger = logger
        self.eventBus = CommonEventBus(logger: logger)
    }

    // MARK: - Basic Registration and Posting Tests

    @Test("Register observer returns valid token")
    func registerObserverReturnsValidToken() {

        // Given
        let token = eventBus.registerObserver { (event: TestEvent) in
            _ = event
        }

        // Then
        #expect(token.identifier != UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
    }

    @Test("Single observer receives posted event")
    func singleObserverReceivesEvent() async throws {
        // Given
        let testEvent = TestEvent(message: "Hello", value: 42)
        let receivedEvent = Locked<TestEvent?>(nil)

        let token = eventBus.registerObserver { (event: TestEvent) in
            receivedEvent.withLock { $0 = event }
        }

        // When
        eventBus.post(testEvent)

        // Wait for event processing
        try await Task.sleep(for: .milliseconds(500))

        // Then
        #expect(receivedEvent.withLock { $0 } == testEvent)
        _ = token
    }

    @Test("Multiple observers all receive event")
    func multipleObserversReceiveEvent() async throws {
        // Given
        let testEvent = TestEvent(message: "Broadcast", value: 100)
        let receivedEvents = Locked<[TestEvent]>([])

        var tokens: [RegistrationToken<UUID>] = []

        tokens += eventBus.registerObserver { (event: TestEvent) in
            receivedEvents.withLock { $0.append(event) }
        }

        tokens += eventBus.registerObserver { (event: TestEvent) in
            receivedEvents.withLock { $0.append(event) }
        }

        tokens += eventBus.registerObserver { (event: TestEvent) in
            receivedEvents.withLock { $0.append(event) }
        }

        // When
        eventBus.post(testEvent)

        // Wait for event processing
        try await Task.sleep(for: .milliseconds(500))

        // Then
        let events = receivedEvents.withLock { $0 }
        #expect(events.count == 3)
        #expect(events.allSatisfy { $0 == testEvent })
        _ = tokens
    }

    @Test("Only matching observers receive specific event types")
    func eventTypeFiltering() async throws {
        // Given
        let testEvent = TestEvent(message: "Test", value: 1)
        let anotherEvent = AnotherTestEvent(data: "Another")

        let receivedTestEvent = Locked<TestEvent?>(nil)
        let receivedAnotherEvent = Locked<AnotherTestEvent?>(nil)

        let token1 = eventBus.registerObserver { (event: TestEvent) in
            receivedTestEvent.withLock { $0 = event }
        }

        let token2 = eventBus.registerObserver { (event: AnotherTestEvent) in
            receivedAnotherEvent.withLock { $0 = event }
        }

        // When
        eventBus.post(testEvent)
        eventBus.post(anotherEvent)

        // Wait for event processing
        try await Task.sleep(for: .milliseconds(500))

        // Then
        #expect(receivedTestEvent.withLock { $0 } == testEvent)
        #expect(receivedAnotherEvent.withLock { $0 } == anotherEvent)
        _ = (token1, token2)
    }

    // MARK: - Token Deallocation Tests

    @Test("Token deallocation removes observer")
    func tokenDeallocationRemovesObserver() async throws {
        // Given
        let testEvent1 = TestEvent(message: "First", value: 1)
        let testEvent2 = TestEvent(message: "Second", value: 2)
        let eventCount = Locked<Int>(0)

        var token: RegistrationToken<UUID>? = eventBus.registerObserver { (event: TestEvent) in
            eventCount.withLock { $0 += 1 }
        }

        // When - Post first event
        eventBus.post(testEvent1)
        try await Task.sleep(for: .milliseconds(500))

        #expect(eventCount.withLock { $0 } == 1)

        // Deallocate token
        token = nil
        try await Task.sleep(for: .milliseconds(100))

        // Post second event
        eventBus.post(testEvent2)
        try await Task.sleep(for: .milliseconds(500))

        // Then
        #expect(eventCount.withLock { $0 } == 1, "Should only receive the first event")
    }

    // MARK: - No Observers Tests

    @Test("Posting event with no observers does not error")
    func postEventWithNoObservers() async throws {
        // Given
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
        let numberOfObservers = 50
        let testEvent = TestEvent(message: "Concurrent", value: 999)
        let eventCounts = Locked<[Int]>(Array(repeating: 0, count: numberOfObservers))
        let tokens = Locked<[RegistrationToken<UUID>]>([])

        // When - Register observers concurrently
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<numberOfObservers {
                group.addTask {
                    let token = self.eventBus.registerObserver { (event: TestEvent) in
                        eventCounts.withLock { $0[i] += 1 }
                    }
                    tokens.withLock { $0.append(token) }
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
        let totalEvents = eventCounts.withLock { $0.reduce(0, +) }
        #expect(totalEvents == numberOfObservers, "All observers should receive the event")
        _ = tokens
    }

    @Test("Concurrent posting delivers all events")
    func concurrentPosting() async throws {
        // Given
        let numberOfEvents = 20
        let receivedEvents = Locked<[NumericEvent]>([])

        let token = eventBus.registerObserver { (event: NumericEvent) in
            receivedEvents.withLock { $0.append(event) }
        }

        // When - Post events concurrently
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<numberOfEvents {
                group.addTask {
                    self.eventBus.post(NumericEvent(number: i))
                }
            }
        }

        // Wait for all events to be processed
        try await Task.sleep(for: .seconds(1))

        // Then
        let events = receivedEvents.withLock { $0 }
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
        let testEvent = TestEvent(message: "Wait test", value: 42)
        let receivedEvent = Locked<TestEvent?>(nil)

        let token = eventBus.registerObserver { (event: TestEvent) in
            receivedEvent.withLock { $0 = event }
        }

        // When
        let summary = await eventBus.postAndWait(testEvent)

        // Then
        #expect(summary.registeredObservers == 1)
        #expect(summary.handlingObservers == 1)
        #expect(receivedEvent.withLock { $0 } == testEvent)
        #expect(summary.completionTime >= summary.arrivalTime)
        _ = token
    }

    @Test("PostAndWait with multiple observers shows correct counts")
    func postAndWaitMultipleObservers() async throws {
        // Given
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
        let receivedMessage = Locked<CommonEventBus.ObserverAddedMessage?>(nil)

        let token1 = eventBus.registerObserver { (message: CommonEventBus.ObserverAddedMessage) in
            receivedMessage.withLock { $0 = message }
        }

        // When
        let token2 = eventBus.registerObserver { (event: TestEvent) in
            // New observer
        }

        // Wait for message processing
        try await Task.sleep(for: .milliseconds(500))

        // Then
        let message = receivedMessage.withLock { $0 }
        #expect(message != nil)
        #expect(message?.handledType == TestEvent.self)
        _ = (token1, token2)
    }

    @Test("DeliverySummary is posted after normal event")
    func deliverySummaryPosted() async throws {
        // Given
        let receivedSummary = Locked<CommonEventBus.DeliverySummary?>(nil)

        let token1 = eventBus.registerObserver { (summary: CommonEventBus.DeliverySummary) in
            receivedSummary.withLock { $0 = summary }
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
        let summary = receivedSummary.withLock { $0 }
        #expect(summary != nil)
        #expect(summary?.handlingObservers == 1)
        _ = (token1, token2)
    }

    // MARK: - Edge Cases

    @Test("Multiple events in sequence are all delivered")
    func multipleEventsInSequence() async throws {
        // Given
        let receivedMessages = Locked<[String]>([])

        let token = eventBus.registerObserver { (event: TestEvent) in
            receivedMessages.withLock { $0.append(event.message) }
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
        let messages = receivedMessages.withLock { $0 }
        #expect(messages.count == 3)
        #expect(messages.contains("First"))
        #expect(messages.contains("Second"))
        #expect(messages.contains("Third"))
        _ = token
    }

    @Test("Observer only receives matching event type")
    func observerOnlyReceivesMatchingType() async throws {
        // Given
        let testEventCount = Locked<Int>(0)

        let token = eventBus.registerObserver { (event: TestEvent) in
            testEventCount.withLock { $0 += 1 }
        }

        // When - Post multiple event types
        eventBus.post(TestEvent(message: "First", value: 1))
        eventBus.post(AnotherTestEvent(data: "Should not be received"))
        eventBus.post(NumericEvent(number: 42))
        eventBus.post(TestEvent(message: "Second", value: 2))

        // Wait for processing
        try await Task.sleep(for: .milliseconds(500))

        // Then
        #expect(testEventCount.withLock { $0 } == 2, "Should only receive TestEvent instances")
        _ = token
    }

    @Test("Large number of events are all processed")
    func largeNumberOfEvents() async throws {
        // Given
        let numberOfEvents = 100
        let receivedCount = Locked<Int>(0)

        let token = eventBus.registerObserver { (event: NumericEvent) in
            receivedCount.withLock { $0 += 1 }
        }

        // When
        for i in 0..<numberOfEvents {
            eventBus.post(NumericEvent(number: i))
        }

        // Wait for all events to be processed
        try await Task.sleep(for: .seconds(2))

        // Then
        #expect(receivedCount.withLock { $0 } == numberOfEvents, "All events should be processed")
        _ = token
    }

    // MARK: - Memory Management Tests

    @Test("Multiple token deallocation removes all observers")
    func multipleTokenDeallocation() async throws {
        // Given
        var tokens: [RegistrationToken<UUID>?] = []
        let eventCount = Locked<Int>(0)

        for _ in 0..<5 {
            let token = eventBus.registerObserver { (event: TestEvent) in
                eventCount.withLock { $0 += 1 }
            }
            tokens.append(token)
        }

        // When - Post first event
        eventBus.post(TestEvent(message: "First", value: 1))
        try await Task.sleep(for: .milliseconds(500))

        #expect(eventCount.withLock { $0 } == 5, "All observers should receive first event")

        // Deallocate all tokens
        tokens.removeAll()
        try await Task.sleep(for: .milliseconds(100))

        // Reset count
        eventCount.withLock { $0 = 0 }

        // Post second event
        eventBus.post(TestEvent(message: "Second", value: 2))
        try await Task.sleep(for: .milliseconds(500))

        // Then
        #expect(eventCount.withLock { $0 } == 0, "No observers should receive second event")
    }
}

// MARK: - Helper Type for Thread-Safe Access

final class Locked<Value>: @unchecked Sendable {
    private var value: Value
    private let lock = NSLock()

    init(_ value: Value) {
        self.value = value
    }

    func withLock<Result>(_ body: (inout Value) -> Result) -> Result {
        lock.lock()
        defer { lock.unlock() }
        return body(&value)
    }
}
