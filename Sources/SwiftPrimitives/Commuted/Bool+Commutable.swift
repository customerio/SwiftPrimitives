
extension Bool: Commutable {
    public func commute() -> Commuted {
        return .bool(self)
    }
}
