/// A tokent that maintains a registration by its retention. When this token is deallocated,
/// the registration that generated it will be removed.

public class RegistrationToken<Identifier: Hashable & Sendable>: @unchecked Sendable {
    public let identifier: Identifier
    
    public init(identifier: Identifier) {
        self.identifier = identifier
    }
}

public final class BlockRegistrationToken<Identifier: Hashable & Sendable>: RegistrationToken<Identifier>, @unchecked Sendable {
    private let action: @Sendable () -> Void
    
    public init(identifier: Identifier, action: @Sendable @escaping () -> Void) {
        self.action = action
        super.init(identifier: identifier)
    }
    
    deinit {
        action()
    }
}
