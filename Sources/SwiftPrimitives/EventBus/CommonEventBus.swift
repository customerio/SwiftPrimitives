import Foundation
import Logging

public protocol EventBus {
    func registerObserver<EventType: Sendable>(listener: @Sendable @escaping (EventType) -> Void)
        -> RegistrationToken<UUID>
    func post(_ event: any Sendable)
}

public final class CommonEventBus: Sendable, EventBus {

    private final class NotifyOperation: Operation, @unchecked Sendable {
        let wasHandled: Synchronized<Bool?> = .init(nil)

        let event: any Sendable
        let listener: @Sendable (any Sendable) -> Bool
        init(event: any Sendable, listener: @Sendable @escaping (any Sendable) -> Bool) {
            self.event = event
            self.listener = listener
        }
        override func main() {
            wasHandled.wrappedValue = listener(event)
        }
    }

    /// Protocol to classify system messages.
    public protocol SystemMessage: Sendable {}

    /// A summary of the delivery statistics for an event submitted to the event queue.
    public struct DeliverySummary: Sendable, SystemMessage {
        public var sourceEvent: any Sendable
        public var registeredObservers: Int
        public var handlingObservers: Int
        public var arrivalTime: Date
        public var completionTime: Date
    }

    /// A system message dispatched on the EventBus when a new observer registers
    public struct ObserverAddedMessage: Sendable, SystemMessage {
        public var handledType: Any.Type
        public var listener: @Sendable (Any) -> Bool
    }

    private let notifiyQueue = OperationQueue()

    private let observers: Synchronized<[UUID: @Sendable (Any) -> Bool]> = Synchronized([:])

    private let logger: Logger

    public init(logger: Logger) {
        self.logger = logger
    }

    public init(resolver: Resolver) throws {
        logger = try resolver.resolve()
    }

    public func registerObserver<EventType: Sendable>(
        listener: @Sendable @escaping (EventType) -> Void
    ) -> RegistrationToken<UUID> {
        let identifier = UUID()
        let token = RegistrationToken(identifier: identifier) { [weak self] in
            guard let self else { return }
            removeRegistration(for: identifier)
        }
        let wrappedListener: @Sendable (Any) -> Bool = { untypedEvent in
            guard let event = untypedEvent as? EventType else {
                return false
            }
            listener(event)
            return true
        }
        observers[token.identifier] = wrappedListener
        logger.debug(
            "Registration complete for events of type \(String(describing: EventType.self)) and assigned identifier \(token.identifier.uuidString)."
        )

        post(
            ObserverAddedMessage(
                handledType: EventType.self,
                listener: wrappedListener
            ))
        return token
    }

    private func removeRegistration(for identifier: UUID) {
        observers.removeValue(forKey: identifier)
        logger.debug("Registration removed for identifier \(identifier).")
    }

    public func post(_ event: any Sendable) {
        let eventTypeName = String(describing: type(of: event))
        let arrivalTime = Date()

        logger.debug("Beginning post for event of type \(eventTypeName)")
        // Fetch the observers synchronously now in case they change before enqueuing the callbacks
        let snapshot = observers.wrappedValue.values
        guard !snapshot.isEmpty else {
            logger.debug("No observers are registered for any events, so aborting delivery.")
            return

        }
        // Notifications delivery queuing happens in the background
        DispatchQueue.global().async {
            let ops = snapshot.map { NotifyOperation(event: event, listener: $0) }

            // Don't post delivery summaries for SystemMessages to avoid recursion
            if !(event is SystemMessage) {
                let sendSummaryOperation = BlockOperation { [weak self] in
                    guard let self else { return }
                    self.logger.debug(
                        "Preparing delivery summary for delivery of event of type \(eventTypeName)")
                    let completionTime = Date()
                    let handledCount = ops.count { op in
                        op.wasHandled.wrappedValue ?? false
                    }
                    let summary = DeliverySummary(
                        sourceEvent: event,
                        registeredObservers: ops.count,
                        handlingObservers: handledCount,
                        arrivalTime: arrivalTime,
                        completionTime: completionTime
                    )
                    self.post(summary)
                    self.logger.debug(
                        "Submitted delivery summary for delivery of event of type \(eventTypeName)")
                }
                ops.forEach {
                    sendSummaryOperation.addDependency($0)
                }
                self.notifiyQueue.addOperation(sendSummaryOperation)
            }
            self.notifiyQueue.addOperations(ops, waitUntilFinished: false)
            self.logger.debug(
                "Completed queuing post for event of type \(eventTypeName) to \(snapshot.count) potential listeners."
            )
        }
    }

    public func postAndWait(_ event: any Sendable) async -> DeliverySummary {
        let arrivalTime = Date()
        let eventTypeName = String(describing: type(of: event))
        logger.debug("Beginning postAndWait for event of type \(eventTypeName)")

        // Fetch the observers synchronously now in case they change before enqueuing the callbacks
        let snapshot = observers.wrappedValue.values

        return await withCheckedContinuation { continuation in

            DispatchQueue.global().async {
                let ops = snapshot.map { NotifyOperation(event: event, listener: $0) }
                self.logger.debug(
                    "Beginning blocking queuing of event of type \(eventTypeName) to \(snapshot.count) potential listeners."
                )
                self.notifiyQueue.addOperations(ops, waitUntilFinished: true)
                let completionTime = Date()
                let handledCount = ops.count { op in
                    op.wasHandled.wrappedValue ?? false
                }
                let summary = DeliverySummary(
                    sourceEvent: event,
                    registeredObservers: ops.count,
                    handlingObservers: handledCount,
                    arrivalTime: arrivalTime,
                    completionTime: completionTime
                )
                self.logger.debug(
                    "Completing postAndWait for event of type \(eventTypeName) with \(handledCount) handled events."
                )
                continuation.resume(returning: summary)
            }
        }
    }
}
