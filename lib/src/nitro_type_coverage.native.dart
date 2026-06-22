import 'dart:typed_data';

import 'package:nitro/nitro.dart';

part 'nitro_type_coverage.g.dart';

@NitroModule(
  ios: NativeImpl.swift,
  android: NativeImpl.kotlin,
  macos: NativeImpl.swift,
)
abstract class NitroTypeCoverage extends HybridObject {
  static final NitroTypeCoverage instance = _NitroTypeCoverageImpl();

  // ── Primitives (sync) ──────────────────────────────────────────────────────
  int echoInt(int value);
  double echoDouble(double value);
  bool echoBool(bool value);
  String echoString(String value);

  // ── Multi-param (sync) ────────────────────────────────────────────────────
  int addInts(int a, int b, int c);
  double mulDoubles(double a, double b);
  String joinStrings(String a, String b, String separator);

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
}

// ── Types ─────────────────────────────────────────────────────────────────────

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
  TcConfig({required this.name, required this.count, required this.enabled, required this.threshold});
}

/// A more complex @HybridRecord covering all 4 primitive types with different
/// field ordering — tests that the binary codec is position-stable.
@HybridRecord()
class TcMeta {
  final int version;
  final double weight;
  final bool active;
  final String label;
  TcMeta({required this.version, required this.weight, required this.active, required this.label});
}
