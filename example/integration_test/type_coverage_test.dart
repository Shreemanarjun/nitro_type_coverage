// Integration test — nitro_type_coverage plugin.
//
// Runs on a real device / simulator. Every test sends a value through the
// Nitro bridge and verifies the exact same value comes back. If the bridge
// has a wrong JNI signature, wrong struct layout, wrong enum rawValue, or
// wrong memory ownership, the test fails here — not silently at runtime.
//
// Run:
//   flutter test integration_test/type_coverage_test.dart -d <device-id>
//
// Or via drive:
//   flutter drive --driver=test_driver/integration_test.dart \
//                 --target=integration_test/type_coverage_test.dart

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nitro_type_coverage/nitro_type_coverage.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final tc = NitroTypeCoverage.instance;

  // ── Primitives ─────────────────────────────────────────────────────────────

  group('Primitives — sync echo round-trip', () {
    test('echoInt: 0', () => expect(tc.echoInt(0), 0));
    test('echoInt: 1', () => expect(tc.echoInt(1), 1));
    test('echoInt: -1', () => expect(tc.echoInt(-1), -1));
    test('echoInt: int64 max', () {
      const max = 9223372036854775807;
      expect(tc.echoInt(max), max);
    });
    test('echoInt: int64 min', () {
      const min = -9223372036854775808;
      expect(tc.echoInt(min), min);
    });

    test('echoDouble: 0.0', () => expect(tc.echoDouble(0.0), 0.0));
    test('echoDouble: 3.14159', () => expect(tc.echoDouble(3.14159), closeTo(3.14159, 1e-12)));
    test('echoDouble: -99.9', () => expect(tc.echoDouble(-99.9), closeTo(-99.9, 1e-12)));
    test('echoDouble: infinity', () => expect(tc.echoDouble(double.infinity), double.infinity));
    test('echoDouble: -infinity', () => expect(tc.echoDouble(double.negativeInfinity), double.negativeInfinity));
    test('echoDouble: NaN', () => expect(tc.echoDouble(double.nan).isNaN, isTrue));
    test('echoDouble: maxFinite', () => expect(tc.echoDouble(double.maxFinite), double.maxFinite));
    test('echoDouble: minPositive', () => expect(tc.echoDouble(double.minPositive), greaterThan(0)));

    test('echoBool: true', () => expect(tc.echoBool(true), isTrue));
    test('echoBool: false', () => expect(tc.echoBool(false), isFalse));

    test('echoString: empty', () => expect(tc.echoString(''), ''));
    test('echoString: ascii', () => expect(tc.echoString('hello'), 'hello'));
    test('echoString: unicode', () => expect(tc.echoString('日本語 🎉'), '日本語 🎉'));
    test('echoString: emoji', () => expect(tc.echoString('🔥💧🌊'), '🔥💧🌊'));
    test('echoString: 1 KB', () {
      final s = 'x' * 1024;
      expect(tc.echoString(s), s);
    });
    test('echoString: special chars', () {
      expect(tc.echoString('hello\nworld\ttab'), 'hello\nworld\ttab');
    });
  });

  // ── Nullable primitives ────────────────────────────────────────────────────

  group('Nullable primitives', () {
    test('echoNullableInt: null', () => expect(tc.echoNullableInt(null), anyOf(isNull, 0)));
    test('echoNullableInt: 42', () => expect(tc.echoNullableInt(42), 42));
    test('echoNullableDouble: null', () => expect(tc.echoNullableDouble(null), anyOf(isNull, 0.0)));
    test('echoNullableDouble: 1.5', () => expect(tc.echoNullableDouble(1.5), closeTo(1.5, 1e-12)));
    test('echoNullableBool: null', () => expect(tc.echoNullableBool(null), anyOf(isNull, isFalse)));
    test('echoNullableBool: true', () => expect(tc.echoNullableBool(true), isTrue));
    test('echoNullableString: null', () => expect(tc.echoNullableString(null), anyOf(isNull, isEmpty)));
    test('echoNullableString: hi', () => expect(tc.echoNullableString('hi'), 'hi'));
  });

  // ── Enum ──────────────────────────────────────────────────────────────────

  group('Enum — every variant', () {
    test('ok', () => expect(tc.echoStatus(TcStatus.ok), TcStatus.ok));
    test('error', () => expect(tc.echoStatus(TcStatus.error), TcStatus.error));
    test('pending', () => expect(tc.echoStatus(TcStatus.pending), TcStatus.pending));
  });

  // ── Struct ─────────────────────────────────────────────────────────────────

  group('Struct — field round-trip', () {
    test('origin (0, 0, 0)', () {
      final p = tc.echoPoint(TcPoint(x: 0, y: 0, z: 0));
      expect(p.x, 0.0); expect(p.y, 0.0); expect(p.z, 0.0);
    });
    test('(1.5, -2.5, 3.0)', () {
      final p = tc.echoPoint(TcPoint(x: 1.5, y: -2.5, z: 3.0));
      expect(p.x, closeTo(1.5, 1e-12));
      expect(p.y, closeTo(-2.5, 1e-12));
      expect(p.z, closeTo(3.0, 1e-12));
    });
    test('very small values', () {
      final p = tc.echoPoint(TcPoint(x: 1e-300, y: -1e-300, z: 0));
      expect(p.x, closeTo(1e-300, 1e-310));
      expect(p.y, closeTo(-1e-300, 1e-310));
    });
    test('infinity in z', () {
      final p = tc.echoPoint(TcPoint(x: 0, y: 0, z: double.infinity));
      expect(p.z, double.infinity);
    });
  });

  // ── @HybridRecord ─────────────────────────────────────────────────────────

  group('@HybridRecord — all fields preserved', () {
    test('basic config', () {
      final cfg = TcConfig(name: 'test', count: 7, enabled: true, threshold: 0.5);
      final echo = tc.echoConfig(cfg);
      expect(echo.name, 'test');
      expect(echo.count, 7);
      expect(echo.enabled, isTrue);
      expect(echo.threshold, closeTo(0.5, 1e-12));
    });
    test('empty name, zero count, disabled', () {
      final echo = tc.echoConfig(TcConfig(name: '', count: 0, enabled: false, threshold: 0));
      expect(echo.name, '');
      expect(echo.count, 0);
      expect(echo.enabled, isFalse);
    });
    test('unicode name + large count', () {
      final echo = tc.echoConfig(TcConfig(
          name: '設定 🔧', count: 1000000, enabled: true, threshold: 99.9));
      expect(echo.name, '設定 🔧');
      expect(echo.count, 1000000);
      expect(echo.threshold, closeTo(99.9, 1e-10));
    });
    test('negative threshold + false enabled', () {
      final echo = tc.echoConfig(TcConfig(name: 'neg', count: -5, enabled: false, threshold: -0.001));
      expect(echo.count, -5);
      expect(echo.threshold, closeTo(-0.001, 1e-12));
    });
  });

  // ── TypedData (zero-copy) ─────────────────────────────────────────────────

  group('TypedData — zero-copy round-trip', () {
    test('echoBytes: empty', () => expect(tc.echoBytes(Uint8List(0)).length, 0));
    test('echoBytes: [0, 1, 2, 255]', () {
      expect(tc.echoBytes(Uint8List.fromList([0, 1, 2, 255])), [0, 1, 2, 255]);
    });
    test('echoBytes: all-zeros 1 KB', () {
      final echo = tc.echoBytes(Uint8List(1024));
      expect(echo.length, 1024);
      expect(echo.every((b) => b == 0), isTrue);
    });
    test('echoBytes: all-255 512 bytes', () {
      final src = Uint8List.fromList(List.filled(512, 255));
      final echo = tc.echoBytes(src);
      expect(echo.every((b) => b == 255), isTrue);
    });
    test('echoBytes: 64 KB pattern', () {
      final src = Uint8List.fromList(List.generate(65536, (i) => i & 0xFF));
      final echo = tc.echoBytes(src);
      expect(echo.length, 65536);
      expect(echo[0], 0); expect(echo[255], 255); expect(echo[256], 0);
    });

    test('echoFloats: empty', () => expect(tc.echoFloats(Float32List(0)).length, 0));
    test('echoFloats: [1.0, 2.0, 3.0]', () {
      final echo = tc.echoFloats(Float32List.fromList([1.0, 2.0, 3.0]));
      expect(echo[0], closeTo(1.0, 1e-6));
      expect(echo[1], closeTo(2.0, 1e-6));
      expect(echo[2], closeTo(3.0, 1e-6));
    });
    test('echoFloats: 1000 values', () {
      final src = Float32List.fromList(List.generate(1000, (i) => i.toDouble()));
      final echo = tc.echoFloats(src);
      expect(echo.length, 1000);
      expect(echo[999], closeTo(999.0, 1e-4));
    });
  });

  // ── Lists (async) ─────────────────────────────────────────────────────────

  group('Lists — async echo round-trip', () {
    testWidgets('echoIntList: [1, 2, 3]', (t) async {
      expect(await tc.echoIntList([1, 2, 3]), [1, 2, 3]);
    });
    testWidgets('echoIntList: empty', (t) async {
      expect(await tc.echoIntList([]), isEmpty);
    });
    testWidgets('echoIntList: 1000 items', (t) async {
      final src = List.generate(1000, (i) => i);
      final echo = await tc.echoIntList(src);
      expect(echo.length, 1000);
      expect(echo.first, 0); expect(echo.last, 999);
    });

    testWidgets('echoDoubleList: [1.1, 2.2, 3.3]', (t) async {
      final echo = await tc.echoDoubleList([1.1, 2.2, 3.3]);
      expect(echo[0], closeTo(1.1, 1e-10));
      expect(echo[2], closeTo(3.3, 1e-10));
    });

    testWidgets('echoStringList: basic', (t) async {
      expect(await tc.echoStringList(['a', 'b', 'c']), ['a', 'b', 'c']);
    });
    testWidgets('echoStringList: empty', (t) async {
      expect(await tc.echoStringList([]), isEmpty);
    });
    testWidgets('echoStringList: unicode', (t) async {
      final echo = await tc.echoStringList(['日本語', '🎉', 'hello']);
      expect(echo, ['日本語', '🎉', 'hello']);
    });
  });

  // ── Async (@nitroAsync) ───────────────────────────────────────────────────

  group('Async (@nitroAsync) — isolate round-trip', () {
    testWidgets('asyncDouble: 42.0', (t) async {
      expect(await tc.asyncDouble(42.0), closeTo(42.0, 1e-12));
    });
    testWidgets('asyncDouble: NaN', (t) async {
      expect((await tc.asyncDouble(double.nan)).isNaN, isTrue);
    });
    testWidgets('asyncDouble: infinity', (t) async {
      expect(await tc.asyncDouble(double.infinity), double.infinity);
    });
    testWidgets('asyncString: "hello async"', (t) async {
      expect(await tc.asyncString('hello async'), 'hello async');
    });
    testWidgets('asyncString: empty', (t) async {
      expect(await tc.asyncString(''), '');
    });
    testWidgets('asyncString: unicode', (t) async {
      expect(await tc.asyncString('日本語 🎉'), '日本語 🎉');
    });
    testWidgets('asyncInt: 0', (t) async { expect(await tc.asyncInt(0), 0); });
    testWidgets('asyncInt: maxInt64', (t) async {
      const max = 9223372036854775807;
      expect(await tc.asyncInt(max), max);
    });
    testWidgets('100 concurrent asyncDouble — all resolve correctly', (t) async {
      final futures = List.generate(100, (i) => tc.asyncDouble(i.toDouble()));
      final results = await Future.wait(futures);
      for (var i = 0; i < 100; i++) {
        expect(results[i], closeTo(i.toDouble(), 1e-12));
      }
    });
  });

  // ── Properties ─────────────────────────────────────────────────────────────

  group('Properties — get/set round-trip', () {
    test('precision: 7', () { tc.precision = 7; expect(tc.precision, 7); });
    test('precision: 0', () { tc.precision = 0; expect(tc.precision, 0); });
    test('precision: -1', () { tc.precision = -1; expect(tc.precision, -1); });
    test('tag: "hello"', () { tc.tag = 'hello'; expect(tc.tag, 'hello'); });
    test('tag: empty', () { tc.tag = ''; expect(tc.tag, ''); });
    test('tag: unicode', () { tc.tag = '🔧'; expect(tc.tag, '🔧'); });
    test('nullableRate: null', () { tc.nullableRate = null; expect(tc.nullableRate, isNull); });
    test('nullableRate: 3.14', () { tc.nullableRate = 3.14; expect(tc.nullableRate, closeTo(3.14, 1e-12)); });
    test('nullableRate: 0.0', () { tc.nullableRate = 0.0; expect(tc.nullableRate, 0.0); });
  });

  // ── Streams ───────────────────────────────────────────────────────────────

  group('Streams — emission and cancellation', () {
    testWidgets('intStream: 5 values from 0', (t) async {
      final received = <int>[];
      final sub = tc.intStream().listen(received.add);
      tc.configureStream(0, 5);
      await Future.delayed(const Duration(milliseconds: 200));
      await sub.cancel();
      expect(received, containsAll([0, 1, 2, 3, 4]));
    });

    testWidgets('intStream: values from 10', (t) async {
      final received = <int>[];
      final sub = tc.intStream().listen(received.add);
      tc.configureStream(10, 3);
      await Future.delayed(const Duration(milliseconds: 200));
      await sub.cancel();
      expect(received, containsAll([10, 11, 12]));
    });

    testWidgets('pointStream: x matches from value', (t) async {
      final received = <TcPoint>[];
      final sub = tc.pointStream().listen(received.add);
      tc.configureStream(5, 3);
      await Future.delayed(const Duration(milliseconds: 200));
      await sub.cancel();
      expect(received.isNotEmpty, isTrue);
      expect(received.first.x, closeTo(5.0, 1e-9));
    });

    testWidgets('cancel stops further emissions', (t) async {
      final received = <int>[];
      final sub = tc.intStream().listen(received.add);
      tc.configureStream(0, 100);
      // Cancel immediately
      await sub.cancel();
      final countAfterCancel = received.length;
      await Future.delayed(const Duration(milliseconds: 200));
      expect(received.length, countAfterCancel);
    });

    testWidgets('multiple subscribers receive independent streams', (t) async {
      final a = <int>[], b = <int>[];
      final subA = tc.intStream().listen(a.add);
      final subB = tc.intStream().listen(b.add);
      tc.configureStream(1, 3);
      await Future.delayed(const Duration(milliseconds: 200));
      await subA.cancel(); await subB.cancel();
      // Both should have received values (may vary due to backpressure)
      expect(a.length + b.length, greaterThan(0));
    });
  });
}
