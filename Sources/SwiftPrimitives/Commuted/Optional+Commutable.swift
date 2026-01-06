
extension Optional: Commutable where Wrapped: Commutable {
    public func commute() -> Commuted {
        return self?.commute() ?? .null
    }
}
