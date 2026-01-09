import Foundation

extension String: Commutable {
    public func commute() -> Commuted {
        return .string(self)
    }
}
