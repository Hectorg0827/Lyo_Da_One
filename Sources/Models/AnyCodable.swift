import Foundation

// MARK: - Helper for dynamic JSON values
public struct AnyCodable: Codable {
    public let value: Any

    public init<T>(_ value: T?) {
        self.value = value ?? ()
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            value = ()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "AnyCodable value cannot be decoded"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case is Void:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            let codableArray = array.map(AnyCodable.init)
            try container.encode(codableArray)
        case let dict as [String: Any]:
            let codableDict = dict.mapValues(AnyCodable.init)
            try container.encode(codableDict)
        default:
            let context = EncodingError.Context(
                codingPath: container.codingPath,
                debugDescription: "AnyCodable value cannot be encoded"
            )
            throw EncodingError.invalidValue(value, context)
        }
    }
    public func decode<T: Decodable>(_ type: T.Type) throws -> T {
        let data: Data
        let sanitized = AnyCodable.sanitizeForJSON(value)
        if JSONSerialization.isValidJSONObject(sanitized) {
            data = try JSONSerialization.data(withJSONObject: sanitized, options: [])
        } else if let encodable = value as? Encodable {
            data = try JSONEncoder().encode(AnyEncodableWrapper(encodable))
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: [],
                    debugDescription: "AnyCodable value of type \(Swift.type(of: value)) cannot be serialized to JSON"
                )
            )
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - JSON Sanitization

    /// Recursively sanitizes a value produced by AnyCodable for use with JSONSerialization.
    /// Swift Void `()` (decoded from JSON null) is replaced with NSNull because Void is
    /// not a valid ObjC-bridgeable type and causes JSONSerialization.data(withJSONObject:) to throw.
    /// Keys whose values are Void are dropped (JSON omit-null semantics), which is correct
    /// for Swift's `decodeIfPresent` / optional properties.
    public static func sanitizeForJSON(_ val: Any) -> Any {
        switch val {
        case is Void:
            // JSON null → drop (callers omit key entirely rather than emitting NSNull)
            return NSNull()
        case let arr as [Any]:
            return arr.compactMap { item -> Any? in
                let s = sanitizeForJSON(item)
                return (s is NSNull) ? nil : s
            }
        case let dict as [String: Any]:
            var out: [String: Any] = [:]
            for (k, v) in dict {
                let s = sanitizeForJSON(v)
                if !(s is NSNull) { out[k] = s }
            }
            return out
        default:
            return val
        }
    }
}

// MARK: - Helper to erase Encodable for re-serialization
private struct AnyEncodableWrapper: Encodable {
    private let _encode: (Encoder) throws -> Void
    init(_ wrapped: Encodable) {
        _encode = { encoder in try wrapped.encode(to: encoder) }
    }
    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}

// MARK: - Typed JSON value enum

enum AnyCodableValue: Codable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([AnyCodableValue])
    case dictionary([String: AnyCodableValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([AnyCodableValue].self) {
            self = .array(array)
        } else if let dict = try? container.decode([String: AnyCodableValue].self) {
            self = .dictionary(dict)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .dictionary(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    var intValue: Int? {
        if case .int(let i) = self { return i }
        return nil
    }

    var doubleValue: Double? {
        if case .double(let d) = self { return d }
        if case .int(let i) = self { return Double(i) }
        return nil
    }

    var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }

    var value: Any {
        switch self {
        case .string(let s): return s
        case .int(let i): return i
        case .double(let d): return d
        case .bool(let b): return b
        case .array(let arr): return arr.map { $0.value }
        case .dictionary(let dict): return dict.mapValues { $0.value }
        case .null: return NSNull()
        }
    }
}
