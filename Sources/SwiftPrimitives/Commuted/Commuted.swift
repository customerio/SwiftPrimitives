import Foundation

public enum Commuted: Sendable {
    case null
    case bool(Bool)
    case int(Int64)
    case float(Float64)
    case date(Date)
    case string(String)
    case data(Data)
    indirect case array([Commuted])
    indirect case object([String: Commuted])
}

extension Commuted: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .float(let value):
            try container.encode(value)
        case .date(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .data(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            // Null must be decoded first because it is often encoded in other types
            self = .null
        } else if let value = try? container.decode(Date.self) {
            // Date must be before String, Int, and Float
            self = .date(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Int64.self) {
            // Int must be before Float
            self = .int(value)
        } else if let value = try? container.decode(Float64.self) {
            self = .float(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode([Commuted].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: Commuted].self) {
            self = .object(value)
        } else if let value = try? container.decode(Data.self) {
            // In JSON Encoding, data is encoded as Base64 Strings.
            // That precludes this from ever being posible with JSON,
            // but other encoding strategies support it, so it's here as
            // an option.
            self = .data(value)
        } else {
            let description = "No valid Commuted-supported value was found"
            let context = DecodingError.Context(
                codingPath: container.codingPath, debugDescription: description)
            throw DecodingError.valueNotFound(Commuted.self, context)
        }

    }
}

extension Commuted: Equatable {
    public static func == (lhs: Commuted, rhs: Commuted) -> Bool {
        switch (lhs, rhs) {
        case (.null, .null):
            return true
        case (.bool(let l), .bool(let r)):
            return l == r
        case (.int(let l), .int(let r)):
            return l == r
        case (.float(let l), .float(let r)):
            return l == r
        case (.float(let l), .int(let r)):
            return l == Float64(r)
        case (.int(let l), .float(let r)):
            return Float64(l) == r
        case (.date(let l), .date(let r)):
            return l == r
        case (.string(let l), .string(let r)):
            return l == r
        case (.data(let l), .data(let r)):
            return l == r
        case (.array(let l), .array(let r)):
            return l == r
        case (.object(let l), .object(let r)):
            return l == r
        default:
            return false
        }
    }

    public static func == (lhs: Commuted, rhs: Commutable) -> Bool {
        return lhs == rhs.commute()
    }

    public static func != (lhs: Commuted, rhs: Commutable) -> Bool {
        return lhs != rhs.commute()
    }
}
