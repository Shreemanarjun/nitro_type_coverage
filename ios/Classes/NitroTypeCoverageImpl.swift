import Foundation
import Combine

/// Echo implementation of HybridNitroTypeCoverageProtocol.
/// Every method returns exactly what it receives.
/// Streams emit a configurable sequence of values.
public class NitroTypeCoverageImpl: NSObject, HybridNitroTypeCoverageProtocol {

    // ── Stream subjects ───────────────────────────────────────────────────────
    private let _intStream = PassthroughSubject<Int64, Never>()
    private let _pointStream = PassthroughSubject<TcPoint, Never>()

    public var intStream: AnyPublisher<Int64, Never> { _intStream.eraseToAnyPublisher() }
    public var pointStream: AnyPublisher<TcPoint, Never> { _pointStream.eraseToAnyPublisher() }

    // ── Properties ────────────────────────────────────────────────────────────
    public var precision: Int64 = 0
    public var tag: String = ""
    public var nullableRate: Double? = nil

    // ── Primitives ────────────────────────────────────────────────────────────
    public func echoInt(value: Int64) -> Int64 { value }
    public func echoDouble(value: Double) -> Double { value }
    public func echoBool(value: Bool) -> Bool { value }
    public func echoString(value: String) -> String { value }

    // ── Nullable primitives ───────────────────────────────────────────────────
    public func echoNullableInt(value: Int64?) -> Int64? { value }
    public func echoNullableDouble(value: Double?) -> Double? { value }
    public func echoNullableBool(value: Bool?) -> Bool? { value }
    public func echoNullableString(value: String?) -> String? { value }

    // ── Enum ──────────────────────────────────────────────────────────────────
    public func echoStatus(value: TcStatus) -> TcStatus { value }

    // ── Struct ────────────────────────────────────────────────────────────────
    public func echoPoint(value: TcPoint) -> TcPoint { value }

    // ── @HybridRecord ─────────────────────────────────────────────────────────
    public func echoConfig(value: TcConfig) -> TcConfig { value }

    // ── TypedData (zero-copy) ─────────────────────────────────────────────────
    public func echoBytes(value: Data) -> Data { value }
    public func echoFloats(value: [Float]) -> [Float] { value }

    // ── Lists (async) ─────────────────────────────────────────────────────────
    public func echoIntList(value: [Int64]) async throws -> [Int64] { value }
    public func echoDoubleList(value: [Double]) async throws -> [Double] { value }
    public func echoStringList(value: [String]) async throws -> [String] { value }

    // ── Async ─────────────────────────────────────────────────────────────────
    public func asyncDouble(value: Double) async throws -> Double { value }
    public func asyncString(value: String) async throws -> String { value }
    public func asyncInt(value: Int64) async throws -> Int64 { value }

    // ── Stream control ────────────────────────────────────────────────────────
    public func configureStream(from: Int64, count: Int64) {
        Task {
            for i in 0..<count {
                _intStream.send(from + i)
                _pointStream.send(TcPoint(x: Double(from + i), y: Double(from + i) * 0.5, z: 0.0))
            }
        }
    }
}
