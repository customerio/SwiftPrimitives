
extension Array: Commutable where Element: Commutable  {
    public func commute() -> Commuted {
        let commuted: [Commuted] = map { $0.commute() }
        return .array(commuted)
    }
}

extension Array where Element == Commutable {
    public func commute() -> Commuted {
        let commuted: [Commuted] = map { $0.commute() }
        return .array(commuted)
    }
}
