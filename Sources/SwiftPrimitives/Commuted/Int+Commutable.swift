extension Int: Commutable {
    public func commute() -> Commuted {
        return .int(Int64(self))
    }
}

extension UInt: Commutable {
    public func commute() -> Commuted {
        return .int(Int64(self))
    }
}

extension Int64: Commutable {
    public func commute() -> Commuted {
        return .int(self)
    }
}

extension UInt64: Commutable {
    public func commute() -> Commuted {
        return .int(Int64(self))
    }
}
