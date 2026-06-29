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

    // ── DateTime ─────────────────────────────────────────────────────────────
    public func echoDateTime(value: Date) -> Date { value }
    public func echoNullableDateTime(value: Date?) -> Date? { value }

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

    // ── Async nullable ────────────────────────────────────────────────────────
    public func asyncNullableInt(value: Int64?) async throws -> Int64? { value }
    public func asyncNullableDouble(value: Double?) async throws -> Double? { value }
    public func asyncNullableBool(value: Bool?) async throws -> Bool? { value }
    public func asyncNullableString(value: String?) async throws -> String? { value }

    // ── @HybridRecord (TcMeta) ───────────────────────────────────────────────
    public func echoMeta(value: TcMeta) -> TcMeta { value }
    public func asyncMeta(value: TcMeta) async throws -> TcMeta { value }

    // ── NitroNullable built-in types (from package:nitro) ────────────────────
    // These types have no sentinel collision — all values including Int64.min,
    // NaN, and every bool state round-trip correctly on all platforms.
    public func echoNullableIntSafe(value: NitroNullableInt) -> NitroNullableInt { value }
    public func echoNullableDoubleSafe(value: NitroNullableDouble) -> NitroNullableDouble { value }
    public func echoNullableBoolSafe(value: NitroNullableBool) -> NitroNullableBool { value }

    // ── Maps (§24 + L4) ──────────────────────────────────────────────────────
    public func echoIntMap(value: Any) -> Any { value }
    public func echoStringMap(value: Any) -> Any { value }
    public func echoDoubleMap(value: Any) -> Any { value }
    public func echoBoolMap(value: Any) -> Any { value }
    public func echoConfigMap(value: Any) -> Any { value }
    public func echoEventMap(value: Any) -> Any { value }

    // ── @HybridRecord with TypedData fields (§29) ────────────────────────────
    public func echoDataRecord(value: TcDataRecord) -> TcDataRecord { value }

    // ── §30: 6 new type coverage features ────────────────────────────────────

    // #1 Stream<TcConfig>
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

    // #2 Nullable @HybridRecord
    public func echoNullableConfig(value: TcConfig?) -> TcConfig? { value }

    // #3 Nested @HybridRecord
    public func echoNested(value: TcNested) -> TcNested { value }

    // #4 List<TcConfig> sync param
    public func echoConfigListSync(values: [TcConfig]) async throws -> [TcConfig] { values }

    // #5 NitroNullable inside @HybridRecord
    public func echoNullableWrapper(value: TcNullableWrapper) -> TcNullableWrapper { value }

    // #6 Bidirectional callback — native calls Dart, receives a value back
    public func onTransformEvent(transformCb: @escaping (Int64) -> Int64) {
        // Call the Dart callback with 42 and verify we get a transformed value back
        let _ = transformCb(42)
    }

    // ── @HybridRecord with enum field (§25) ───────────────────────────────────
    public func echoPacket(value: TcPacket) -> TcPacket { value }

    // ── Nullable struct (§26) ─────────────────────────────────────────────────
    public func echoNullablePoint(value: TcPoint?) -> TcPoint? { value }

    // ── #5: @HybridStruct in @HybridRecord (§32) ──────────────────────────────
    public func echoStructHolder(value: TcStructHolder) -> TcStructHolder { value }

    // ── #4: Bidirectional callbacks with non-int returns (§32) ───────────────
    public func onStringTransform(stringCb: @escaping (Int64) -> String) {
        _ = stringCb(42)  // Native calls Dart with 42, gets back a String
    }
    public func onDoubleTransform(doubleCb: @escaping (Int64) -> Double) {
        _ = doubleCb(7)  // Native calls Dart with 7, gets back a Double
    }

    // ── #9: Batch stream (§32) ─────────────────────────────────────────────────
    private var _batchIntSubject = PassthroughSubject<Int64, Never>()
    public var batchIntStream: AnyPublisher<Int64, Never> {
        _batchIntSubject.eraseToAnyPublisher()
    }
    public func configureBatchStream(from: Int64, count: Int64) {
        DispatchQueue.global().async { [weak self] in
            for i in 0..<count { self?._batchIntSubject.send(from + i) }
        }
    }

    private var _batchDoubleSubject = PassthroughSubject<Double, Never>()
    public var batchDoubleStream: AnyPublisher<Double, Never> {
        _batchDoubleSubject.eraseToAnyPublisher()
    }
    public func configureBatchDoubleStream(values: [Double]) {
        DispatchQueue.global().async { [weak self] in
            for v in values { self?._batchDoubleSubject.send(v) }
        }
    }

    private var _batchBoolSubject = PassthroughSubject<Bool, Never>()
    public var batchBoolStream: AnyPublisher<Bool, Never> {
        _batchBoolSubject.eraseToAnyPublisher()
    }
    public func configureBatchBoolStream(values: [Bool]) {
        DispatchQueue.global().async { [weak self] in
            for v in values { self?._batchBoolSubject.send(v) }
        }
    }

    private var _batchStringSubject = PassthroughSubject<String, Never>()
    public var batchStringStream: AnyPublisher<String, Never> {
        _batchStringSubject.eraseToAnyPublisher()
    }
    public func configureBatchStringStream(values: [String]) {
        DispatchQueue.global().async { [weak self] in
            for v in values { self?._batchStringSubject.send(v) }
        }
    }

    // ── §35: Bool/enum bidirectional callbacks ────────────────────────────────
    public func onBoolTransform(boolCb: @escaping (Int64) -> Bool) {
        _ = boolCb(42)  // Dart returns true when value == 42
    }
    public func onStatusTransform(statusCb: @escaping (Int64) -> TcStatus) {
        _ = statusCb(42)  // Dart returns .ok for 42
    }

    // ── §35: List<bool> and List<TcPoint> ────────────────────────────────────
    public func echoListBool(value: [Bool]) async throws -> [Bool] { value }
    public func echoPointList(values: [TcPoint]) async throws -> [TcPoint] { values }

    // ── §35: @NitroNativeAsync with typed returns ──────────────────────────────
    public func nativeAsyncInt(value: Int64) async throws -> Int64 { value }
    public func nativeAsyncDouble(value: Double) async throws -> Double { value }
    public func nativeAsyncBool(value: Bool) async throws -> Bool { value }
    public func nativeAsyncString(value: String) async throws -> String { value }

    // ── §35: Stream<String> ───────────────────────────────────────────────────
    private let _stringStreamSubject = PassthroughSubject<String, Never>()
    public var stringStream: AnyPublisher<String, Never> { _stringStreamSubject.eraseToAnyPublisher() }
    public func configureStringStream(values: [String]) {
        DispatchQueue.global().async { [weak self] in
            for v in values { self?._stringStreamSubject.send(v) }
        }
    }

    // ── §35: Backpressure.block stream ────────────────────────────────────────
    private let _blockIntSubject = PassthroughSubject<Int64, Never>()
    public var blockIntStream: AnyPublisher<Int64, Never> { _blockIntSubject.eraseToAnyPublisher() }
    public func configureBlockIntStream(from: Int64, count: Int64) {
        DispatchQueue.global().async { [weak self] in
            for i in 0..<count { self?._blockIntSubject.send(from + i) }
        }
    }

    // ── Callbacks with struct and multi-params (§27) ──────────────────────────
    public func onPointEvent(pointCb: @escaping (TcPoint) -> Void) {
        pointCb(TcPoint(x: 1.0, y: 2.0, z: 3.0))
    }
    public func onDetailEvent(detailCb: @escaping (Int64, Double) -> Void) {
        detailCb(42, 9.81)
    }

    // ── Async additions ───────────────────────────────────────────────────────
    public func asyncPoint(value: TcPoint) async throws -> TcPoint { value }
    public func asyncNullableStatus(value: TcStatus?) async throws -> TcStatus? { value }

    // ── Callback ──────────────────────────────────────────────────────────────
    public func onIntEvent(callback: @escaping (Int64) -> Void) {
        // Fire immediately with a test value so Dart can verify the callback fires
        callback(42)
    }
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

    // ── §36: @NitroOwned ─────────────────────────────────────────────────────
    public func acquireBuffer(size: Int64) -> UnsafeMutableRawPointer? {
        // Allocate a raw buffer of `size` bytes; Dart side wraps it in NativeHandle + finalizer.
        return UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: 16)
    }

    // ── §36: @NitroVariant ────────────────────────────────────────────────────
    public func echoEvent(event: TcEvent) -> TcEvent { return event }

    // ── §36: @NitroResult ─────────────────────────────────────────────────────
    public func safeDiv(a: Double, b: Double) throws -> Double {
        if b == 0.0 { throw NSError(domain: "NitroTypeCoverage", code: 1, userInfo: [NSLocalizedDescriptionKey: "division by zero"]) }
        return a / b
    }

    public func validateLabel(label: String) throws -> String {
        let trimmed = label.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { throw NSError(domain: "NitroTypeCoverage", code: 2, userInfo: [NSLocalizedDescriptionKey: "empty label"]) }
        return trimmed
    }

    // ── §47: Slow async — deliberate delay for timeout testing ────────────────
    public func slowAsync(delayMs: Int64) async throws -> Int64 {
        try await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
        return delayMs
    }

    // ── §52: Deeply nested @HybridRecord ─────────────────────────────────────
    public func echoDeepRecord(value: TcDeepRecord) -> TcDeepRecord { value }
    public func asyncDeepRecord(value: TcDeepRecord) async throws -> TcDeepRecord { value }

    // ── §37: @nitroAsync + @NitroOwned/@NitroVariant/@NitroResult ────────────
    public func asyncAcquireBuffer(size: Int64) async throws -> UnsafeMutableRawPointer? {
        return UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: 16)
    }

    public func asyncEchoEvent(event: TcEvent) async throws -> TcEvent { return event }

    public func asyncSafeDiv(a: Double, b: Double) async throws -> Double {
        if b == 0.0 { throw NSError(domain: "NitroTypeCoverage", code: 1, userInfo: [NSLocalizedDescriptionKey: "division by zero"]) }
        return a / b
    }

    public func asyncValidateLabel(label: String) async throws -> String {
        let trimmed = label.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { throw NSError(domain: "NitroTypeCoverage", code: 2, userInfo: [NSLocalizedDescriptionKey: "empty label"]) }
        return trimmed
    }

    // ── §59: Gap 9 — non-contiguous enum round-trip ───────────────────────────
    public func echoPriority(value: TcPriority) -> TcPriority { value }

    // ── §60: Gap 10 — Backpressure.bufferDrop stream ─────────────────────────
    private let _bufferDropIntSubject = PassthroughSubject<Int64, Never>()
    public var bufferDropIntStream: AnyPublisher<Int64, Never> { _bufferDropIntSubject.eraseToAnyPublisher() }
    public func configureBufferDropIntStream(from: Int64, count: Int64) {
        DispatchQueue.global().async { [weak self] in
            for i in 0..<count { self?._bufferDropIntSubject.send(from + i) }
        }
    }

    // ── §61: Gap 13 — @NitroVariant as callback parameter ────────────────────
    public func onEventCallback(handler: @escaping (TcEvent) -> Void) {
        handler(.tap(x: 10, y: 20))
        handler(.scroll(delta: 1.5))
    }

    // ── §62: Gap 17 — @NitroVariant as Stream item ───────────────────────────
    private let _eventStreamSubject = PassthroughSubject<TcEvent, Never>()
    public var eventStream: AnyPublisher<TcEvent, Never> { _eventStreamSubject.eraseToAnyPublisher() }
    public func configureEventStream(count: Int64) {
        DispatchQueue.global().async { [weak self] in
            for i in 0..<count {
                if i % 2 == 0 {
                    self?._eventStreamSubject.send(.tap(x: i, y: i * 2))
                } else {
                    self?._eventStreamSubject.send(.scroll(delta: Double(i)))
                }
            }
        }
    }

    // ── §63: List<@HybridEnum> ────────────────────────────────────────────────
    public func getStatusList() -> [TcStatus] { [.ok, .error, .pending] }
    public func echoStatusList(values: [TcStatus]) -> [TcStatus] { values }

    // ── §64: List<@NitroVariant> ──────────────────────────────────────────────
    public func getEventList() -> [TcEvent] {
        [.tap(x: 1, y: 2), .scroll(delta: 3.5), .resize(width: 100, height: 200)]
    }
    public func echoEventList(values: [TcEvent]) -> [TcEvent] { values }

    // ── §65: @NitroVariant as property type ──────────────────────────────────
    public var currentEvent: TcEvent = .tap(x: 0, y: 0)

    // ── §66: Nullable enum/String stream items ────────────────────────────────
    private let _nullableStatusStreamSubject = PassthroughSubject<TcStatus?, Never>()
    public var nullableStatusStream: AnyPublisher<TcStatus?, Never> { _nullableStatusStreamSubject.eraseToAnyPublisher() }
    public func configureNullableStatusStream(count: Int64) {
        DispatchQueue.global().async { [weak self] in
            for i in 0..<count {
                if i % 3 == 0 { self?._nullableStatusStreamSubject.send(nil) }
                else if i % 3 == 1 { self?._nullableStatusStreamSubject.send(.ok) }
                else { self?._nullableStatusStreamSubject.send(.error) }
            }
        }
    }

    private let _nullableStringStreamSubject = PassthroughSubject<String?, Never>()
    public var nullableStringStream: AnyPublisher<String?, Never> { _nullableStringStreamSubject.eraseToAnyPublisher() }
    public func configureNullableStringStream(count: Int64) {
        DispatchQueue.global().async { [weak self] in
            for i in 0..<count {
                self?._nullableStringStreamSubject.send(i % 2 == 0 ? nil : "item\(i)")
            }
        }
    }

    // ── L12: @NitroTuple round-trip ───────────────────────────────────────────
    public func echoPair(value: TcPair) -> TcPair { value }
    public func echoNullablePair(value: TcPair?) -> TcPair? { value }

    // ── L13: uint64 round-trip ────────────────────────────────────────────────
    public func echoUint64(value: UInt64) -> UInt64 { value }
    public func echoNullableUint64(value: UInt64?) -> UInt64? { value }

    // ── L13: uint64 streams ───────────────────────────────────────────────────
    private let _uint64StreamSubject = PassthroughSubject<UInt64, Never>()
    public var uint64Stream: AnyPublisher<UInt64, Never> { _uint64StreamSubject.eraseToAnyPublisher() }
    public func configureUint64Stream(from: Int64, count: Int64) {
        DispatchQueue.global().async { [weak self] in
            for i in 0..<count { self?._uint64StreamSubject.send(UInt64(bitPattern: from + i)) }
        }
    }

    private let _nullableUint64StreamSubject = PassthroughSubject<UInt64?, Never>()
    public var nullableUint64Stream: AnyPublisher<UInt64?, Never> { _nullableUint64StreamSubject.eraseToAnyPublisher() }
    public func configureNullableUint64Stream(count: Int64) {
        DispatchQueue.global().async { [weak self] in
            for i in 0..<count {
                self?._nullableUint64StreamSubject.send(i % 2 == 0 ? nil : UInt64(i))
            }
        }
    }
}
