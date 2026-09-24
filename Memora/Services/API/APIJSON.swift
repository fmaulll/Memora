import Foundation

enum APIJSON {
    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = timestamp(string) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO8601 timestamp: \(string)")
        }
        return decoder
    }

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        // Stable output also helps persist and inspect immutable upload payloads.
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    static func timestamp(_ string: String, allowsNaiveUTC: Bool = false) -> Date? {
        let formatter = ISO8601DateFormatter()
        for options: ISO8601DateFormatter.Options in [
            [.withInternetDateTime, .withFractionalSeconds], [.withInternetDateTime]
        ] {
            formatter.formatOptions = options
            if let date = formatter.date(from: string) { return date }
            // Only legacy card/exam fields opt into the backend's naive UTC form.
            if allowsNaiveUTC, let date = formatter.date(from: string + "Z") { return date }
        }
        return nil
    }
}

extension KeyedDecodingContainer {
    func decodeLegacyUTCDate(forKey key: Key) throws -> Date {
        let string = try decode(String.self, forKey: key)
        guard let date = APIJSON.timestamp(string, allowsNaiveUTC: true) else {
            throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "Invalid legacy UTC timestamp: \(string)")
        }
        return date
    }

    func decodeLegacyUTCDateIfPresent(forKey key: Key) throws -> Date? {
        guard contains(key), try !decodeNil(forKey: key) else { return nil }
        return try decodeLegacyUTCDate(forKey: key)
    }
}
