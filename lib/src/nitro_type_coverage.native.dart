
import 'package:nitro/nitro.dart';

part 'nitro_type_coverage.g.dart';

// ── L13: uint64 scalar type ────────────────────────────────────────────────────
// Dart alias so `uint64` is valid syntax in method signatures below.
// ignore: camel_case_types
typedef uint64 = int;

// ── N1: Narrow scalar typedefs (RN Nitro parity) ─────────────────────────────
// These map to narrower C/JVM types on the native side:
//   int8 → Int8/Byte, int16 → Int16/Short, int32 → Int32/Int
//   uint8 → UInt8/Byte, uint16 → UInt16/Short, uint32 → UInt32/Int
//   float → Float/Float (32-bit)
// ignore: camel_case_types
typedef int8 = int;
// ignore: camel_case_types
typedef int16 = int;
// ignore: camel_case_types
typedef int32 = int;
// ignore: camel_case_types
typedef uint8 = int;
// ignore: camel_case_types
typedef uint16 = int;
// ignore: camel_case_types
typedef uint32 = int;
// ignore: camel_case_types
typedef float = double;

@NitroModule(
  ios: NativeImpl.swift,
  android: NativeImpl.kotlin,
  macos: NativeImpl.swift,
  windows: NativeImpl.cpp,
  linux: NativeImpl.cpp,
)
abstract class NitroTypeCoverage extends HybridObject {
  // Default singleton — same as getInstance('default').
  static NitroTypeCoverage get instance => getInstance();

  // Returns the cached instance for [key], creating one on first access.
  // Each unique key maps to a dedicated native impl (string-keyed registry,
  // int64 instanceId used internally for zero-overhead C bridge calls).
  static NitroTypeCoverage getInstance([String key = 'default']) =>
      _NitroTypeCoverageImpl(key);

  // ── Primitives (sync) ──────────────────────────────────────────────────────
  int echoInt(int value);
  double echoDouble(double value);
  bool echoBool(bool value);
  String echoString(String value);

  // ── Multi-param (sync) ────────────────────────────────────────────────────
  int addInts(int a, int b, int c);
  double mulDoubles(double a, double b);
  String joinStrings(String a, String b, String separator);

  // ── DateTime (sync) ───────────────────────────────────────────────────────
  DateTime echoDateTime(DateTime value);
  DateTime? echoNullableDateTime(DateTime? value);

  // ── Nullable primitives (sync) ────────────────────────────────────────────
  int? echoNullableInt(int? value);
  double? echoNullableDouble(double? value);
  bool? echoNullableBool(bool? value);
  String? echoNullableString(String? value);

  // ── Enum ──────────────────────────────────────────────────────────────────
  TcStatus echoStatus(TcStatus value);
  TcStatus? echoNullableStatus(TcStatus? value);

  // ── Struct ────────────────────────────────────────────────────────────────
  TcPoint echoPoint(TcPoint value);

  // ── @HybridRecord ─────────────────────────────────────────────────────────
  TcConfig echoConfig(TcConfig value);

  // ── TypedData (zero-copy) — multiple element types ─────────────────────────
  @zeroCopy
  Uint8List echoBytes(Uint8List value);

  @zeroCopy
  Float32List echoFloats(Float32List value);

  @zeroCopy
  Float64List echoFloat64s(Float64List value);

  @zeroCopy
  Int32List echoInt32s(Int32List value);

  // Additional TypedData types (§17 coverage)
  @zeroCopy
  Int8List echoInt8s(Int8List value);

  @zeroCopy
  Int16List echoInt16s(Int16List value);

  @zeroCopy
  Int64List echoInt64s(Int64List value);

  // ── Lists (async — @HybridRecord JSON encoding) ───────────────────────────
  @nitroAsync
  Future<List<int>> echoIntList(List<int> value);

  @nitroAsync
  Future<List<double>> echoDoubleList(List<double> value);

  @nitroAsync
  Future<List<String>> echoStringList(List<String> value);

  @nitroAsync
  Future<List<TcConfig>> echoConfigList(List<TcConfig> values);

  // ── Async (@nitroAsync) ───────────────────────────────────────────────────
  @nitroAsync
  Future<int> asyncInt(int value);

  @nitroAsync
  Future<double> asyncDouble(double value);

  @nitroAsync
  Future<bool> asyncBool(bool value);

  @nitroAsync
  Future<String> asyncString(String value);

  @nitroAsync
  Future<TcConfig> asyncConfig(TcConfig value);

  // ── Async nullable variants ───────────────────────────────────────────────
  @nitroAsync
  Future<int?> asyncNullableInt(int? value);

  @nitroAsync
  Future<double?> asyncNullableDouble(double? value);

  @nitroAsync
  Future<bool?> asyncNullableBool(bool? value);

  @nitroAsync
  Future<String?> asyncNullableString(String? value);

  // Additional async types (§21 coverage)
  @nitroAsync
  Future<TcPoint> asyncPoint(TcPoint value);

  @nitroAsync
  Future<TcStatus?> asyncNullableStatus(TcStatus? value);

  @nitroAsync
  Future<TcMeta> asyncMeta(TcMeta value);

  // ── @HybridRecord with more field types (§22 coverage) ───────────────────
  TcMeta echoMeta(TcMeta value);

  // ── Nitro nullable types — collision-free via binary flag (§23 coverage) ──
  NitroNullableInt echoNullableIntSafe(NitroNullableInt value);
  NitroNullableDouble echoNullableDoubleSafe(NitroNullableDouble value);
  NitroNullableBool echoNullableBoolSafe(NitroNullableBool value);

  // ── @HybridRecord with TypedData fields (§29 coverage) ───────────────────
  // Tests binary codec with Uint8List, Int32List, Float64List inside a record.
  TcDataRecord echoDataRecord(TcDataRecord value);

  // ── Map types — JSON-encoded bridge (§24 coverage) ───────────────────────
  // Maps are encoded as JSON strings over the C bridge (not binary).
  // Only Map<String, T> is supported; non-String keys are a known limitation.
  // Primitive value maps — type-safe, cast via .cast<String, T>()
  Map<String, int> echoIntMap(Map<String, int> value);
  Map<String, String> echoStringMap(Map<String, String> value);
  Map<String, double> echoDoubleMap(Map<String, double> value);
  Map<String, bool> echoBoolMap(Map<String, bool> value);
  // L4: Map<String, @HybridRecord> and Map<String, @NitroVariant> — binary tag-5 encoding.
  Map<String, TcConfig> echoConfigMap(Map<String, TcConfig> value);
  Map<String, TcEvent> echoEventMap(Map<String, TcEvent> value);

  // ── @HybridRecord with enum field (§25 coverage) ─────────────────────────
  // Tests binary codec with mixed primitive + enum field ordering.
  TcPacket echoPacket(TcPacket value);

  // ── Nullable struct (§26 coverage) ───────────────────────────────────────
  // TcPoint? — null represented as a null pointer (not a sentinel value).
  TcPoint? echoNullablePoint(TcPoint? value);

  // ── #1 Stream<@HybridRecord> (§30 coverage) ──────────────────────────────
  // Tests binary codec round-trip through a stream (not just method returns).
  @NitroStream(backpressure: Backpressure.dropLatest)
  Stream<TcConfig> configStream();
  void configureConfigStream(TcConfig seed, int count);

  // ── #2 Nullable @HybridRecord param/return (§30 coverage) ───────────────
  // TcConfig? — null represented via binary null-tag (1B flag + payload).
  TcConfig? echoNullableConfig(TcConfig? value);

  // ── #3 Nested @HybridRecord — record field inside a record (§30 coverage) ─
  TcNested echoNested(TcNested value);

  // ── #4 List<@HybridRecord> as sync param (§30 coverage) ──────────────────
  // Sync (non-async) method accepting List<@HybridRecord> as parameter.
  @nitroAsync
  Future<List<TcConfig>> echoConfigListSync(List<TcConfig> values);

  // ── #5 NitroNullable inside @HybridRecord field (§30 coverage) ───────────
  TcNullableWrapper echoNullableWrapper(TcNullableWrapper value);

  // ── #6 Bidirectional callback — callback that returns a value (§30 coverage)
  // The native side calls Dart with an int and receives an int back.
  void onTransformEvent(int Function(int value) transformCb);

  // ── #5: @HybridStruct embedded in @HybridRecord (§32 coverage) ──────────
  TcStructHolder echoStructHolder(TcStructHolder value);

  // ── #4: Bidirectional callbacks with non-int return types (§32 coverage) ─
  void onStringTransform(String Function(int value) stringCb);
  void onDoubleTransform(double Function(int value) doubleCb);

  // ── #9: Batch stream (§32 coverage) ──────────────────────────────────────
  @NitroStream(backpressure: Backpressure.batch, batchMaxSize: 16)
  Stream<int> batchIntStream();
  void configureBatchStream(int from, int count);

  @NitroStream(backpressure: Backpressure.batch, batchMaxSize: 16)
  Stream<double> batchDoubleStream();
  void configureBatchDoubleStream(List<double> values);

  @NitroStream(backpressure: Backpressure.batch, batchMaxSize: 16)
  Stream<bool> batchBoolStream();
  void configureBatchBoolStream(List<bool> values);

  // ── #4: Bidirectional callbacks with bool and enum returns (§35 coverage) ─
  void onBoolTransform(bool Function(int value) boolCb);
  void onStatusTransform(TcStatus Function(int value) statusCb);

  // ── §35: List<bool> and List<@HybridStruct> param/return ─────────────────
  @nitroAsync
  Future<List<bool>> echoListBool(List<bool> value);

  @nitroAsync
  Future<List<TcPoint>> echoPointList(List<TcPoint> values);

  // ── §35: @NitroNativeAsync with typed returns ─────────────────────────────
  @nitroNativeAsync
  Future<int> nativeAsyncInt(int value);

  @nitroNativeAsync
  Future<double> nativeAsyncDouble(double value);

  @nitroNativeAsync
  Future<bool> nativeAsyncBool(bool value);

  @nitroNativeAsync
  Future<String> nativeAsyncString(String value);

  // ── N3: @NitroNativeAsync with nullable returns ────────────────────────────
  @nitroNativeAsync
  Future<int?> nativeAsyncNullableInt(int? value);

  @nitroNativeAsync
  Future<double?> nativeAsyncNullableDouble(double? value);

  @nitroNativeAsync
  Future<bool?> nativeAsyncNullableBool(bool? value);

  // ── §67: @NitroNativeAsync param-decoding + return-dispatch coverage ─────
  // Regression coverage for the nitro_generator fix where @NitroNativeAsync's
  // trampoline only decoded nullable-primitive params/returns and forwarded
  // every other category (enum, record, variant, list-of-those, callback) as
  // a raw undecoded bridge value — a Kotlin/Swift compile failure. Plus a
  // handful of previously-broken return categories (bare variant, Map, and a
  // fresh List<@HybridEnum>/List<@NitroVariant> return regression that same
  // record-return fix introduced).
  @nitroNativeAsync
  Future<TcStatus> nativeAsyncStatus(TcStatus value);

  @nitroNativeAsync
  Future<TcStatus?> nativeAsyncNullableStatus(TcStatus? value);

  @nitroNativeAsync
  Future<TcConfig> nativeAsyncConfig(TcConfig value);

  @nitroNativeAsync
  Future<TcConfig?> nativeAsyncNullableConfig(TcConfig? value);

  @nitroNativeAsync
  Future<TcEvent> nativeAsyncEvent(TcEvent value);

  @nitroNativeAsync
  Future<List<TcConfig>> nativeAsyncConfigList(List<TcConfig> values);

  @nitroNativeAsync
  Future<List<TcStatus>> nativeAsyncStatusList(List<TcStatus> values);

  @nitroNativeAsync
  Future<List<TcEvent>> nativeAsyncEventList(List<TcEvent> values);

  @nitroNativeAsync
  Future<List<int>> nativeAsyncIntList(List<int> values);

  @nitroNativeAsync
  Future<int> nativeAsyncWithCallback(int value, void Function(int) callback);

  @nitroNativeAsync
  Future<Map<String, int>> nativeAsyncCounts(int seed);

  @nitroNativeAsync
  Future<uint64?> nativeAsyncNullableUint64(uint64? value);

  // ── §68: @NitroNativeAsync — Map/AnyMap params, struct returns, AnyMap ───
  // Follow-up coverage for the gaps closed after §67: Map<String,V> and
  // NitroAnyMap native-async params (previously deferred), bare
  // @HybridStruct native-async returns on Kotlin (previously no wire format
  // existed at all), and NitroAnyMap as a whole on Swift (previously
  // unimplemented on every dispatch path, not just native-async).
  @nitroNativeAsync
  Future<Map<String, int>> nativeAsyncEchoIntMap(Map<String, int> value);

  @nitroNativeAsync
  Future<TcPoint> nativeAsyncEchoPoint(TcPoint value);

  @nitroNativeAsync
  Future<NitroAnyMap> nativeAsyncEchoAnyMap(NitroAnyMap value);

  // ── §35: Stream<String> — validates the kString emit path ────────────────
  @NitroStream(backpressure: Backpressure.dropLatest)
  Stream<String> stringStream();
  void configureStringStream(List<String> values);

  // ── §42: Secondary String stream — validates multiple concurrent String streams ──
  @NitroStream(backpressure: Backpressure.dropLatest)
  Stream<String> batchStringStream();
  void configureBatchStringStream(List<String> values);

  // ── §35: Backpressure.block stream ────────────────────────────────────────
  @NitroStream(backpressure: Backpressure.block)
  Stream<int> blockIntStream();
  void configureBlockIntStream(int from, int count);

  // ── Callbacks with struct and multi-params (§27 coverage) ────────────────
  void onPointEvent(void Function(TcPoint point) pointCb);
  void onDetailEvent(void Function(int id, double score) detailCb);

  // ── Callback parameter ────────────────────────────────────────────────────
  void onIntEvent(void Function(int value) callback);

  // Additional callback types (§19 coverage).
  // Use param name 'boolCb'/'doubleCb' (not 'callback') so the Kotlin generator
  // creates a unique _invoke_boolCb / _invoke_doubleCb with Long-encoded values
  // that reuses the same synchronous path as _invoke_callback.
  void onBoolEvent(void Function(bool value) boolCb);
  void onDoubleEvent(void Function(double value) doubleCb);

  // ── Properties ────────────────────────────────────────────────────────────
  int get precision;
  set precision(int value);

  String get tag;
  set tag(String value);

  double? get nullableRate;
  set nullableRate(double? value);

  bool get enabled;
  set enabled(bool value);

  TcStatus get currentStatus;
  set currentStatus(TcStatus value);

  // Additional nullable primitive properties (§18 coverage)
  int? get nullableCounter;
  set nullableCounter(int? value);

  bool? get optionalFlag;
  set optionalFlag(bool? value);

  // ── Streams ───────────────────────────────────────────────────────────────
  @NitroStream(backpressure: Backpressure.dropLatest)
  Stream<int> intStream();

  @NitroStream(backpressure: Backpressure.dropLatest)
  Stream<TcPoint> pointStream();

  @NitroStream(backpressure: Backpressure.dropLatest)
  Stream<bool> boolStream();

  // Additional stream types (§20 coverage)
  @NitroStream(backpressure: Backpressure.dropLatest)
  Stream<double> doubleStream();

  @NitroStream(backpressure: Backpressure.dropLatest)
  Stream<TcStatus> statusStream();

  void configureStream(int from, int count);
  void configureDoubleStream(double start, int count);
  void configureStatusStream(int count);

  // ── Error handling ────────────────────────────────────────────────────────
  void throwNative(String message);

  @nitroAsync
  Future<void> throwNativeAsync(String message);

  // ── §36: @NitroOwned — returns an opaque handle ──────────────────────────
  // acquireBuffer returns an opaque native handle via @NitroOwned.
  @NitroOwned()
  NativeHandle<Void> acquireBuffer(int size);

  // ── §36: @NitroVariant — sealed class round-trip ─────────────────────────
  // echoEvent echoes a TcEvent variant through the C bridge.
  TcEvent echoEvent(TcEvent event);

  // ── §36: @NitroResult — safe division with error result ──────────────────
  // safeDiv returns NitroResultValue<double>: NitroOk(a/b) or NitroErr("division by zero").
  @NitroResult()
  NitroResultValue<double> safeDiv(double a, double b);

  // ── §36: @NitroResult<String> — label validation ─────────────────────────
  // validateLabel returns NitroResultValue<String>: NitroOk(trimmed) or NitroErr("empty label").
  @NitroResult()
  NitroResultValue<String> validateLabel(String label);

  // ── §47: Slow async — deliberate delay for timeout testing ───────────────
  // Returns delayMs after sleeping that many milliseconds.
  // @NitroAsync(timeout: 800) enforces an 800 ms deadline on all platforms.
  @NitroAsync(timeout: 800)
  Future<int> slowAsync(int delayMs);

  // ── §52: Deeply nested @HybridRecord — 3-level nesting ───────────────────
  // TcDeepRecord → TcNested → TcConfig (3 levels of nested record codec).
  TcDeepRecord echoDeepRecord(TcDeepRecord value);

  @nitroAsync
  Future<TcDeepRecord> asyncDeepRecord(TcDeepRecord value);

  // ── §37: @nitroAsync + @NitroOwned/@NitroVariant/@NitroResult combos ─────
  // asyncAcquireBuffer: same allocation as acquireBuffer but dispatched async.
  @nitroAsync
  @NitroOwned()
  Future<NativeHandle<Void>> asyncAcquireBuffer(int size);

  // asyncEchoEvent: variant round-trip on a background thread.
  @nitroAsync
  Future<TcEvent> asyncEchoEvent(TcEvent event);

  // asyncSafeDiv: division with error result, dispatched async.
  @nitroAsync
  @NitroResult()
  Future<NitroResultValue<double>> asyncSafeDiv(double a, double b);

  // asyncValidateLabel: label validation with error result, dispatched async.
  @nitroAsync
  @NitroResult()
  Future<NitroResultValue<String>> asyncValidateLabel(String label);

  // ── §59: Gap 9 — non-contiguous enum round-trip ──────────────────────────
  TcPriority echoPriority(TcPriority value);

  // ── §60: Gap 10 — Backpressure.bufferDrop stream ─────────────────────────
  @NitroStream(backpressure: Backpressure.bufferDrop)
  Stream<int> bufferDropIntStream();
  void configureBufferDropIntStream(int from, int count);

  // ── §61: Gap 13 — @NitroVariant as callback parameter ────────────────────
  void onEventCallback(void Function(TcEvent event) handler);

  // ── §62: Gap 17 — @NitroVariant as Stream item ───────────────────────────
  @NitroStream(backpressure: Backpressure.dropLatest)
  Stream<TcEvent> eventStream();
  void configureEventStream(int count);

  // ── §63: List<@HybridEnum> — encode/decode enum list via record codec ─────
  List<TcStatus> getStatusList();
  List<TcStatus> echoStatusList(List<TcStatus> values);

  // ── §64: List<@NitroVariant> — encode/decode variant list via record codec ─
  List<TcEvent> getEventList();
  List<TcEvent> echoEventList(List<TcEvent> values);

  // ── §65: @NitroVariant as property type ──────────────────────────────────
  TcEvent get currentEvent;
  set currentEvent(TcEvent value);

  // ── §66: Nullable enum/String stream items ────────────────────────────────
  @NitroStream(backpressure: Backpressure.dropLatest)
  Stream<TcStatus?> nullableStatusStream();
  void configureNullableStatusStream(int count);

  @NitroStream(backpressure: Backpressure.dropLatest)
  Stream<String?> nullableStringStream();
  void configureNullableStringStream(int count);


  // ── L12: @NitroTuple — positional record round-trip ──────────────────────
  // Wire: uint8_t* / ByteArray — same binary codec as @HybridRecord.
  // Dart: (int, String) positional record; fields via $1, $2.
  TcPair echoPair(TcPair value);
  TcPair? echoNullablePair(TcPair? value);

  // ── L13: uint64 scalar round-trip ─────────────────────────────────────────
  // Wire: uint64_t (non-null) / NitroOptInt64* (nullable, 9-byte packed).
  // Dart: int; Kotlin: Long; Swift: UInt64.
  uint64 echoUint64(uint64 value);
  uint64? echoNullableUint64(uint64? value);

  // ── L13: uint64 stream items ──────────────────────────────────────────────
  @NitroStream(backpressure: Backpressure.dropLatest)
  Stream<uint64> uint64Stream();
  void configureUint64Stream(int from, int count);

  @NitroStream(backpressure: Backpressure.dropLatest)
  Stream<uint64?> nullableUint64Stream();
  void configureNullableUint64Stream(int count);

  // ── N1: Narrow scalar types (RN Nitro parity — HybridXxxSpec narrow int/float) ───
  int8 echoInt8(int8 value);
  int16 echoInt16(int16 value);
  int32 echoInt32(int32 value);
  uint8 echoUint8(uint8 value);
  uint16 echoUint16(uint16 value);
  uint32 echoUint32(uint32 value);
  float echoFloat(float value);
  int32? echoNullableInt32(int32? value);
  float? echoNullableFloat(float? value);

  // ── N2: Nullable primitive streams ──────────────────────────────────────────
  @NitroStream(backpressure: Backpressure.dropLatest)
  Stream<int?> nullableIntStream();
  void configureNullableIntStream(int count);

  @NitroStream(backpressure: Backpressure.dropLatest)
  Stream<double?> nullableDoubleStream();
  void configureNullableDoubleStream(int count);

  @NitroStream(backpressure: Backpressure.dropLatest)
  Stream<bool?> nullableBoolStream();
  void configureNullableBoolStream(int count);
}

// ── Types ─────────────────────────────────────────────────────────────────────

@HybridEnum(nativeValues: [0, 100, 200])
enum TcPriority { low, medium, high }

@HybridEnum()
enum TcStatus { ok, error, pending }

@HybridStruct()
class TcPoint {
  final double x;
  final double y;
  final double z;
  TcPoint({required this.x, required this.y, required this.z});
}

@HybridRecord()
class TcConfig {
  final String name;
  final int count;
  final bool enabled;
  final double threshold;
  TcConfig({
    required this.name,
    required this.count,
    required this.enabled,
    required this.threshold,
  });
}

/// A more complex @HybridRecord covering all 4 primitive types with different
/// field ordering — tests that the binary codec is position-stable.
@HybridRecord()
class TcMeta {
  final int version;
  final double weight;
  final bool active;
  final String label;
  TcMeta({
    required this.version,
    required this.weight,
    required this.active,
    required this.label,
  });
}

/// @HybridRecord with a @HybridEnum field — tests binary codec enum encoding.
/// Wire: [int32 name_len][name bytes][int64 sequence][int64 status_rawValue][uint8 valid]
@HybridRecord()
class TcPacket {
  final String name;
  final int sequence;
  final TcStatus status;
  final bool valid;
  TcPacket({
    required this.name,
    required this.sequence,
    required this.status,
    required this.valid,
  });
}

// NitroNullableInt, NitroNullableDouble, NitroNullableBool are part of
// package:nitro — no declaration needed here. Just use them directly.

/// #3: Nested @HybridRecord — a record whose field is another @HybridRecord.
/// Wire: label(string) → config(@HybridRecord inline) → version(int)
/// Tests RecordFieldKind.recordObject path in the binary codec.
@HybridRecord()
class TcNested {
  final String label;
  final TcConfig config; // RecordFieldKind.recordObject
  final int version;
  TcNested({required this.label, required this.config, required this.version});
}

/// #5: @HybridRecord whose fields are NitroNullable library types.
/// Tests RecordFieldKind.recordObject where the nested record is a
/// built-in library type (NitroNullableInt / NitroNullableDouble).
@HybridRecord()
class TcNullableWrapper {
  final NitroNullableInt count;
  final NitroNullableDouble rate;
  final String name;
  TcNullableWrapper({
    required this.count,
    required this.rate,
    required this.name,
  });
}

/// @HybridRecord with TypedData fields (§29 coverage).
/// Tests that binary codec correctly encodes Uint8List, Int32List, Float64List
/// as [4B element_count][element_bytes] inside a record.
@HybridRecord()
class TcDataRecord {
  final Uint8List bytes; // raw binary — [4B len][bytes]
  final Int32List values; // int32 array — [4B count][int32 * count]
  final Float64List scores; // float64 array — [4B count][f64 * count]
  final String label; // string field alongside TypedData
  TcDataRecord({
    required this.bytes,
    required this.values,
    required this.scores,
    required this.label,
  });
}

/// #5: @HybridStruct embedded as a field inside a @HybridRecord (§32 coverage).
/// TcPoint uses RecordFieldKind.struct — each field encoded inline as primitives.
/// Wire: label(string) → origin.x(f64) → origin.y(f64) → origin.z(f64) → radius(f64)
@HybridRecord()
class TcStructHolder {
  final String label;
  final TcPoint origin; // RecordFieldKind.struct — embedded inline
  final double radius;
  TcStructHolder({
    required this.label,
    required this.origin,
    required this.radius,
  });
}

/// §52: Deeply nested @HybridRecord — 3 levels of nesting.
/// Wire: label(string) → nested(TcNested inline) → depth(int64)
/// TcNested itself contains TcConfig, making this a 3-level record codec.
@HybridRecord()
class TcDeepRecord {
  final String label;
  final TcNested nested;
  final int depth;
  TcDeepRecord({required this.label, required this.nested, required this.depth});
}

/// §36: @NitroVariant sealed class — event cases.
/// Wire format: [4B len][1B tag][case fields].
/// Nullable case fields write a 1-byte presence flag before the field payload.
@NitroVariant()
sealed class TcEvent {
  const TcEvent();
}

class TcEventTap extends TcEvent {
  final int x;
  final int y;
  const TcEventTap({required this.x, required this.y});
}

class TcEventScroll extends TcEvent {
  final double delta;
  const TcEventScroll({required this.delta});
}

class TcEventResize extends TcEvent {
  final int width;
  final int height;
  const TcEventResize({required this.width, required this.height});
}

class TcEventNullable extends TcEvent {
  final int? count;
  final TcStatus? status;
  final TcConfig? config;
  final List<int>? samples;
  const TcEventNullable({
    required this.count,
    required this.status,
    required this.config,
    required this.samples,
  });
}

// ── L12: @NitroTuple — positional record typedef ──────────────────────────────
// Wire: same binary codec as @HybridRecord (uint8_t* / ByteArray blob).
// Dart positional record — fields accessed via $1 (int), $2 (String).
// Generator emits standalone _nitroDecode_TcPair / _nitroEncode_TcPair free
// functions (not extension methods, which cannot be added to typedefs).
@NitroTuple()
typedef TcPair = (int, String);
