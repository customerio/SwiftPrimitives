public protocol Commutable: Sendable {
    func commute() -> Commuted
}
