extension Dictionary: Commutable where Key == String, Value: Commutable {
    public func commute() -> Commuted {
        let commuted: [String: Commuted] = mapValues { $0.commute()}
        return .object(commuted)
    }
}

extension Dictionary where Key == String, Value == Commutable {
    public func commute() -> Commuted {
        let commuted: [String: Commuted] = mapValues { $0.commute()}
        return .object(commuted)
    }
}
