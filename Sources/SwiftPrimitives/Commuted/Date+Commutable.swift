import Foundation

extension Date: Commutable {
    public func commute() -> Commuted {
        return .date(self)
    }
}
