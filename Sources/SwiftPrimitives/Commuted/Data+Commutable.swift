import Foundation

extension Data: Commutable {
    public func commute() -> Commuted {
        return .data(self)
    }
}

