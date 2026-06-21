import 'dart:typed_data';

import 'package:nitro/nitro.dart';

part 'nitro_type_coverage.g.dart';

@NitroModule(
  ios: NativeImpl.swift,
  android: NativeImpl.kotlin,
  macos: NativeImpl.swift,
)
// TypeCoverage — echo round-trips for every Nitro bridge type.
abstract class NitroTypeCoverage extends HybridObject {
  static final NitroTypeCoverage instance = _NitroTypeCoverageImpl();

  // ── Primitives
  int echoInt(int value);
  double echoDouble(double value);
  bool echoBool(bool value);
  String echoString(String value);

  // ── Nullable
  int? echoNullableInt(int? value);
  double? echoNullableDouble(double? value);
  bool? echoNullableBool(bool? value);
  String? echoNullableString(String? value);

  // ── Enum
  TcStatus echoStatus(TcStatus value);

  // ── Struct
  TcPoint echoPoint(TcPoint value);

  // ── @HybridRecord
  TcConfig echoConfig(TcConfig value);

  // ── TypedData (zero-copy)
  @zeroCopy
  Uint8List echoBytes(Uint8List value);

  @zeroCopy
  Float32List echoFloats(Float32List value);

  // ── Lists (async)
  @nitroAsync
  Future<List<int>> echoIntList(List<int> value);

  @nitroAsync
  Future<List<double>> echoDoubleList(List<double> value);

  @nitroAsync
  Future<List<String>> echoStringList(List<String> value);

  // ── Async
  @nitroAsync
  Future<double> asyncDouble(double value);

  @nitroAsync
  Future<String> asyncString(String value);

  @nitroAsync
  Future<int> asyncInt(int value);

  // ── Properties
  int get precision;
  set precision(int value);

  String get tag;
  set tag(String value);

  double? get nullableRate;
  set nullableRate(double? value);

  // ── Streams
  @NitroStream(backpressure: Backpressure.dropLatest)
  Stream<int> intStream();

  @NitroStream(backpressure: Backpressure.dropLatest)
  Stream<TcPoint> pointStream();

  void configureStream(int from, int count);
}

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
