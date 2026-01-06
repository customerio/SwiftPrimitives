
extension Float: Commutable {
    public func commute() -> Commuted {
        Float64(self).commute()
    }
}

extension Float64: Commutable {
    public func commute() -> Commuted {
        if isInfinite || isNaN {
            return .null
        }
        return .float(self)
    }
}
