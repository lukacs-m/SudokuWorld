import Domain
import Foundation

/// JSON codecs for the payload blobs. Failures surface as `DomainError` so
/// SwiftData/Codable details never cross the boundary.
enum PersistenceMappers {
    static func encode(_ value: some Encodable) throws -> Data {
        do {
            return try JSONEncoder().encode(value)
        } catch {
            throw DomainError.persistence
        }
    }

    static func decode<Value: Decodable>(_ type: Value.Type, from data: Data) throws -> Value {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw DomainError.persistence
        }
    }
}
