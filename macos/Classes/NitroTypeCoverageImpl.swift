import Foundation
import Combine

/// Complete echo implementation of HybridNitroTypeCoverageProtocol.
/// Every method returns exactly what it receives.
/// Used to verify the Nitro bridge correctly serialises/deserialises every type.
public class NitroTypeCoverageImpl: NSObject, HybridNitroTypeCoverageProtocol {

    // ── Streams ───────────────────────────────────────────────────────────────
    private let _intStreamSubject = PassthroughSubject<Int64, Never>()
    private let _pointStreamSubject = PassthroughSubject<TcPoint, Never>()
    private let _boolStreamSubject = PassthroughSubject<Bool, Never>()
    private let _doubleStreamSubject = PassthroughSubject<Double, Never>()
    private let _statusStreamSubject = PassthroughSubject<TcStatus, Never>()

    public var intStream: AnyPublisher<Int64, Never> { _intStreamSubject.eraseToAnyPublisher() }
    public var pointStream: AnyPublisher<TcPoint, Never> { _pointStreamSubject.eraseToAnyPublisher() }
    public var boolStream: AnyPublisher<Bool, Never> { _boolStreamSubject.eraseToAnyPublisher() }
    public var doubleStream: AnyPublisher<Double, Never> { _doubleStreamSubject.eraseToAnyPublisher() }
    public var statusStream: AnyPublisher<TcStatus, Never> { _statusStreamSubject.eraseToAnyPublisher() }

    // ── Properties ────────────────────────────────────────────────────────────
    public var precision: Int64 = 0
    public var tag: String = ""
    public var nullableRate: Double? = nil
    public var enabled: Bool = false
    public var currentStatus: TcStatus = .ok
    public var nullableCounter: Int64? = nil
    public var optionalFlag: Bool? = nil

    // ── Primitives ────────────────────────────────────────────────────────────
    public func echoInt(value: Int64) -> Int64 { value }
    public func echoDouble(value: Double) -> Double { value }
    public func echoBool(value: Bool) -> Bool { value }
    public func echoString(value: String) -> String { value }

    // ── Multi-param ───────────────────────────────────────────────────────────
    public func addInts(a: Int64, b: Int64, c: Int64) -> Int64 { a &+ b &+ c }
    public func mulDoubles(a: Double, b: Double) -> Double { a * b }
    public func joinStrings(a: String, b: String, separator: String) -> String { a + separator + b }

    // ── Nullable primitives ───────────────────────────────────────────────────
    public func echoNullableInt(value: Int64?) -> Int64? { value }
    public func echoNullableDouble(value: Double?) -> Double? { value }
    public func echoNullableBool(value: Bool?) -> Bool? { value }
    public func echoNullableString(value: String?) -> String? { value }

    // ── Enum ──────────────────────────────────────────────────────────────────
    public func echoStatus(value: TcStatus) -> TcStatus { value }
    public func echoNullableStatus(value: TcStatus?) -> TcStatus? { value }

    // ── Struct ────────────────────────────────────────────────────────────────
    public func echoPoint(value: TcPoint) -> TcPoint { value }

    // ── @HybridRecord ─────────────────────────────────────────────────────────
    public func echoConfig(value: TcConfig) -> TcConfig { value }
    public func echoMeta(value: TcMeta) -> TcMeta { value }

    // ── TypedData (zero-copy) ─────────────────────────────────────────────────
    public func echoBytes(value: Data) -> Data { value }
    public func echoFloats(value: [Float]) -> [Float] { value }
    public func echoFloat64s(value: [Double]) -> [Double] { value }
    public func echoInt32s(value: [Int32]) -> [Int32] { value }
    public func echoInt8s(value: Data) -> Data { value }
    public func echoInt16s(value: [Int16]) -> [Int16] { value }
    public func echoInt64s(value: [Int64]) -> [Int64] { value }

    // ── Lists (async) ─────────────────────────────────────────────────────────
    public func echoIntList(value: [Int64]) async throws -> [Int64] { value }
    public func echoDoubleList(value: [Double]) async throws -> [Double] { value }
    public func echoStringList(value: [String]) async throws -> [String] { value }
    public func echoConfigList(values: [TcConfig]) async throws -> [TcConfig] { values }

    // ── Async ─────────────────────────────────────────────────────────────────
    public func asyncInt(value: Int64) async throws -> Int64 { value }
    public func asyncDouble(value: Double) async throws -> Double { value }
    public func asyncBool(value: Bool) async throws -> Bool { value }
    public func asyncString(value: String) async throws -> String { value }
    public func asyncConfig(value: TcConfig) async throws -> TcConfig { value }
    public func asyncPoint(value: TcPoint) async throws -> TcPoint { value }
    public func asyncNullableStatus(value: TcStatus?) async throws -> TcStatus? { value }
    public func asyncMeta(value: TcMeta) async throws -> TcMeta { value }
    public func echoNullableIntSafe(value: NitroNullableInt) -> NitroNullableInt { value }
    public func echoNullableDoubleSafe(value: NitroNullableDouble) -> NitroNullableDouble { value }
    public func echoNullableBoolSafe(value: NitroNullableBool) -> NitroNullableBool { value }
    public func echoIntMap(value: Any) -> Any { value }
    public func echoStringMap(value: Any) -> Any { value }
    public func echoDoubleMap(value: Any) -> Any { value }
    public func echoBoolMap(value: Any) -> Any { value }
    public func echoDataRecord(value: TcDataRecord) -> TcDataRecord { value }
    public func echoPacket(value: TcPacket) -> TcPacket { value }
    public func echoNullablePoint(value: TcPoint?) -> TcPoint? { value }
    public func onPointEvent(pointCb: @escaping (TcPoint) -> Void) { pointCb(TcPoint(x: 1.0, y: 2.0, z: 3.0)) }
    public func onDetailEvent(detailCb: @escaping (Int64, Double) -> Void) { detailCb(42, 9.81) }

    // ── §30: 6 new type coverage features ────────────────────────────────────
    private let _configStreamSubject = PassthroughSubject<TcConfig, Never>()
    public var configStream: AnyPublisher<TcConfig, Never> { _configStreamSubject.eraseToAnyPublisher() }
    public func configureConfigStream(seed: TcConfig, count: Int64) {
        Task {
            for i in 0..<count {
                _configStreamSubject.send(TcConfig(
                    name: "\(seed.name)-\(i)", count: seed.count + i,
                    enabled: seed.enabled, threshold: seed.threshold + Double(i) * 0.1))
            }
        }
    }
    public func echoNullableConfig(value: TcConfig?) -> TcConfig? { value }
    public func echoNested(value: TcNested) -> TcNested { value }
    public func echoConfigListSync(values: [TcConfig]) async throws -> [TcConfig] { values }
    public func echoNullableWrapper(value: TcNullableWrapper) -> TcNullableWrapper { value }
    public func onTransformEvent(transformCb: @escaping (Int64) -> Int64) { let _ = transformCb(42) }

    // ── Async nullable ────────────────────────────────────────────────────────
    public func asyncNullableInt(value: Int64?) async throws -> Int64? { value }
    public func asyncNullableDouble(value: Double?) async throws -> Double? { value }
    public func asyncNullableBool(value: Bool?) async throws -> Bool? { value }
    public func asyncNullableString(value: String?) async throws -> String? { value }

    // ── Callbacks ─────────────────────────────────────────────────────────────
    public func onIntEvent(callback: @escaping (Int64) -> Void) { callback(42) }
    public func onBoolEvent(boolCb: @escaping (Bool) -> Void) { boolCb(true) }
    public func onDoubleEvent(doubleCb: @escaping (Double) -> Void) { doubleCb(2.71828) }

    // ── Stream control ────────────────────────────────────────────────────────
    public func configureStream(from: Int64, count: Int64) {
        Task {
            for i in 0..<count {
                let v = from + i
                _intStreamSubject.send(v)
                _pointStreamSubject.send(TcPoint(x: Double(v), y: Double(v) * 0.5, z: 0.0))
                _boolStreamSubject.send(v % 2 == 0)
            }
        }
    }
    public func configureDoubleStream(start: Double, count: Int64) {
        Task {
            for i in 0..<count { _doubleStreamSubject.send(start + Double(i)) }
        }
    }
    public func configureStatusStream(count: Int64) {
        let statuses: [TcStatus] = [.ok, .error, .pending]
        Task {
            for i in 0..<count { _statusStreamSubject.send(statuses[Int(i) % statuses.count]) }
        }
    }

    // ── Error handling ────────────────────────────────────────────────────────
    public func throwNative(message: String) {
        NSException(name: NSExceptionName("NativeTestError"), reason: message, userInfo: nil).raise()
    }
    public func throwNativeAsync(message: String) async throws {
        throw NSError(domain: "NativeTestError", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
