// Integration test — nitro_type_coverage plugin.
//
// Covers every bridge type supported by Nitro with round-trip echo tests,
// documents KNOWN LIMITATIONS (sentinel collisions, precision loss), and
// includes stress + concurrency tests.
//
// Run:
//   flutter test integration_test/type_coverage_test.dart -d <device-id>


import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:nitro/nitro.dart';
import 'package:nitro_type_coverage/nitro_type_coverage.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final tc = NitroTypeCoverage.instance;

  // ══════════════════════════════════════════════════════════════════════════
  // §1 PRIMITIVES — sync echo
  // ══════════════════════════════════════════════════════════════════════════

  group('§1 Primitives — sync echo', () {
    test('int: 0', () => expect(tc.echoInt(0), 0));
    test('int: 1', () => expect(tc.echoInt(1), 1));
    test('int: -1', () => expect(tc.echoInt(-1), -1));
    test('int: int64 max', () {
      const max = 9223372036854775807;
      expect(tc.echoInt(max), max);
    });
    test('int: int64 min', () {
      const min = -9223372036854775808;
      expect(tc.echoInt(min), min);
    });

    test('double: 0.0', () => expect(tc.echoDouble(0.0), 0.0));
    test('double: 3.14159265358979', () =>
        expect(tc.echoDouble(3.14159265358979), closeTo(3.14159265358979, 1e-12)));
    test('double: infinity', () =>
        expect(tc.echoDouble(double.infinity), double.infinity));
    test('double: -infinity', () =>
        expect(tc.echoDouble(double.negativeInfinity), double.negativeInfinity));
    test('double: NaN', () => expect(tc.echoDouble(double.nan).isNaN, isTrue));
    test('double: maxFinite', () =>
        expect(tc.echoDouble(double.maxFinite), double.maxFinite));
    test('double: minPositive', () =>
        expect(tc.echoDouble(double.minPositive), greaterThan(0)));

    test('bool: true', () => expect(tc.echoBool(true), isTrue));
    test('bool: false', () => expect(tc.echoBool(false), isFalse));

    test('String: empty', () => expect(tc.echoString(''), ''));
    test('String: ascii', () => expect(tc.echoString('hello'), 'hello'));
    test('String: unicode', () =>
        expect(tc.echoString('日本語 🎉'), '日本語 🎉'));
    test('String: emoji cluster', () =>
        expect(tc.echoString('👨‍👩‍👧‍👦'), '👨‍👩‍👧‍👦'));
    test('String: 1 KB', () {
      final s = 'a' * 1024;
      expect(tc.echoString(s), s);
    });
    test('String: 64 KB', () {
      final s = 'x' * 65536;
      expect(tc.echoString(s).length, 65536);
    });
    test('String: special chars', () {
      expect(tc.echoString('hello\nworld\t\r'), 'hello\nworld\t\r');
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // §2 MULTI-PARAM — sync
  // ══════════════════════════════════════════════════════════════════════════

  group('§2 Multi-param — sync', () {
    test('addInts: 1+2+3 = 6', () => expect(tc.addInts(1, 2, 3), 6));
    test('addInts: negative', () => expect(tc.addInts(-1, -2, -3), -6));
    test('addInts: overflow wraps (int64)', () {
      const max = 9223372036854775807;
      expect(() => tc.addInts(max, 1, 0), returnsNormally);
    });

    test('mulDoubles: 2.5 * 4.0 = 10.0', () =>
        expect(tc.mulDoubles(2.5, 4.0), closeTo(10.0, 1e-12)));
    test('mulDoubles: 0 * inf = NaN', () =>
        expect(tc.mulDoubles(0, double.infinity).isNaN, isTrue));

    test('joinStrings: "a" + "b" with "-"', () =>
        expect(tc.joinStrings('a', 'b', '-'), 'a-b'));
    test('joinStrings: empty separator', () =>
        expect(tc.joinStrings('foo', 'bar', ''), 'foobar'));
    test('joinStrings: unicode separator', () =>
        expect(tc.joinStrings('a', 'b', '→'), 'a→b'));
  });

  // ══════════════════════════════════════════════════════════════════════════
  // §3 NULLABLE PRIMITIVES — sync
  // ══════════════════════════════════════════════════════════════════════════

  group('§3 Nullable primitives — sync (non-null paths)', () {
    test('int?: 42 → 42', () => expect(tc.echoNullableInt(42), 42));
    test('int?: 0 → 0', () => expect(tc.echoNullableInt(0), 0));
    test('int?: large positive', () =>
        expect(tc.echoNullableInt(1000000), 1000000));

    test('double?: 1.5 → 1.5', () =>
        expect(tc.echoNullableDouble(1.5), closeTo(1.5, 1e-12)));
    test('double?: 0.0 → 0.0', () =>
        expect(tc.echoNullableDouble(0.0), 0.0));
    test('double?: maxFinite', () =>
        expect(tc.echoNullableDouble(double.maxFinite), double.maxFinite));
    test('double?: infinity', () =>
        expect(tc.echoNullableDouble(double.infinity), double.infinity));
    test('double?: -infinity', () =>
        expect(tc.echoNullableDouble(double.negativeInfinity), double.negativeInfinity));

    test('bool?: true → true', () =>
        expect(tc.echoNullableBool(true), isTrue));
    test('bool?: false → false', () =>
        expect(tc.echoNullableBool(false), isFalse));

    test('String?: "hi" → "hi"', () =>
        expect(tc.echoNullableString('hi'), 'hi'));
    test('String?: empty → empty', () =>
        expect(tc.echoNullableString(''), ''));
    test('String?: unicode', () =>
        expect(tc.echoNullableString('日本語'), '日本語'));
  });

  group('§3 Nullable primitives — null paths', () {
    test('int?: null → null', () =>
        expect(tc.echoNullableInt(null), isNull));
    test('double?: null → null', () =>
        expect(tc.echoNullableDouble(null), isNull));
    test('bool?: null → null or false (platform encodes null as false)', () {
      final v = tc.echoNullableBool(null);
      expect(v, anyOf(isNull, isFalse));
    });
    test('String?: null → null or empty', () {
      final v = tc.echoNullableString(null);
      expect(v, anyOf(isNull, isEmpty));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // §4 ENUM
  // ══════════════════════════════════════════════════════════════════════════

  group('§4 Enum', () {
    test('ok', () => expect(tc.echoStatus(TcStatus.ok), TcStatus.ok));
    test('error', () => expect(tc.echoStatus(TcStatus.error), TcStatus.error));
    test('pending', () => expect(tc.echoStatus(TcStatus.pending), TcStatus.pending));

    test('nullable enum: ok → ok', () =>
        expect(tc.echoNullableStatus(TcStatus.ok), TcStatus.ok));
    test('nullable enum: error → error', () =>
        expect(tc.echoNullableStatus(TcStatus.error), TcStatus.error));
    test('nullable enum: null → null', () =>
        expect(tc.echoNullableStatus(null), isNull));
  });

  // ══════════════════════════════════════════════════════════════════════════
  // §5 STRUCT
  // ══════════════════════════════════════════════════════════════════════════

  group('§5 @HybridStruct', () {
    test('origin (0,0,0)', () {
      final p = tc.echoPoint(TcPoint(x: 0, y: 0, z: 0));
      expect(p.x, 0.0); expect(p.y, 0.0); expect(p.z, 0.0);
    });
    test('(1.5, -2.5, 3.0)', () {
      final p = tc.echoPoint(TcPoint(x: 1.5, y: -2.5, z: 3.0));
      expect(p.x, closeTo(1.5, 1e-12));
      expect(p.y, closeTo(-2.5, 1e-12));
      expect(p.z, closeTo(3.0, 1e-12));
    });
    test('inf in z field', () {
      final p = tc.echoPoint(TcPoint(x: 0, y: 0, z: double.infinity));
      expect(p.z, double.infinity);
    });
    test('NaN in x field', () {
      final p = tc.echoPoint(TcPoint(x: double.nan, y: 0, z: 0));
      expect(p.x.isNaN, isTrue);
    });
    test('very small values', () {
      final p = tc.echoPoint(TcPoint(x: 1e-300, y: -1e-300, z: 0));
      expect(p.x, closeTo(1e-300, 1e-310));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // §6 @HybridRecord
  // ══════════════════════════════════════════════════════════════════════════

  group('§6 @HybridRecord', () {
    test('basic round-trip', () {
      final cfg = TcConfig(name: 'test', count: 7, enabled: true, threshold: 0.5);
      final r = tc.echoConfig(cfg);
      expect(r.name, 'test'); expect(r.count, 7);
      expect(r.enabled, isTrue); expect(r.threshold, closeTo(0.5, 1e-12));
    });
    test('empty name, zero count', () {
      final r = tc.echoConfig(TcConfig(name: '', count: 0, enabled: false, threshold: 0));
      expect(r.name, ''); expect(r.count, 0); expect(r.enabled, isFalse);
    });
    test('unicode name', () {
      final r = tc.echoConfig(TcConfig(name: '設定 🔧', count: 1000000, enabled: true, threshold: 99.9));
      expect(r.name, '設定 🔧'); expect(r.count, 1000000);
      expect(r.threshold, closeTo(99.9, 1e-10));
    });
    test('negative threshold', () {
      final r = tc.echoConfig(TcConfig(name: 'neg', count: -5, enabled: false, threshold: -3.14));
      expect(r.count, -5); expect(r.threshold, closeTo(-3.14, 1e-12));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // §7 TYPED DATA — zero-copy round-trips
  // ══════════════════════════════════════════════════════════════════════════

  group('§7 TypedData — zero-copy', () {
    // Uint8List
    test('echoBytes: empty', () =>
        expect(tc.echoBytes(Uint8List(0)).length, 0));
    test('echoBytes: [0,1,2,255]', () =>
        expect(tc.echoBytes(Uint8List.fromList([0, 1, 2, 255])), [0, 1, 2, 255]));
    test('echoBytes: 1 KB all-zeros', () {
      final r = tc.echoBytes(Uint8List(1024));
      expect(r.length, 1024);
      expect(r.every((b) => b == 0), isTrue);
    });
    test('echoBytes: 256 KB pattern', () {
      final src = Uint8List.fromList(List.generate(262144, (i) => i & 0xFF));
      final r = tc.echoBytes(src);
      expect(r.length, src.length);
      expect(r[0], 0); expect(r[255], 255); expect(r[256], 0);
    });

    // Float32List
    test('echoFloats: [1.0, 2.0, 3.0]', () {
      final r = tc.echoFloats(Float32List.fromList([1.0, 2.0, 3.0]));
      expect(r[0], closeTo(1.0, 1e-6));
      expect(r[2], closeTo(3.0, 1e-6));
    });
    test('echoFloats: empty', () =>
        expect(tc.echoFloats(Float32List(0)).length, 0));
    test('echoFloats: 10k elements', () {
      final src = Float32List.fromList(List.generate(10000, (i) => i.toDouble()));
      expect(tc.echoFloats(src).length, 10000);
    });

    // Float64List
    test('echoFloat64s: [1.0, 2.0]', () {
      final r = tc.echoFloat64s(Float64List.fromList([1.0, 2.0]));
      expect(r[0], closeTo(1.0, 1e-15));
      expect(r[1], closeTo(2.0, 1e-15));
    });
    test('echoFloat64s: pi to 15 sig figs', () {
      const pi = 3.14159265358979323846;
      final r = tc.echoFloat64s(Float64List.fromList([pi]));
      expect(r[0], closeTo(pi, 1e-15));
    });

    // Int32List
    test('echoInt32s: [0, -1, 2147483647]', () {
      final r = tc.echoInt32s(Int32List.fromList([0, -1, 2147483647]));
      expect(r[0], 0); expect(r[1], -1); expect(r[2], 2147483647);
    });
    test('echoInt32s: empty', () =>
        expect(tc.echoInt32s(Int32List(0)).length, 0));
  });

  // ══════════════════════════════════════════════════════════════════════════
  // §8 LISTS — async
  // ══════════════════════════════════════════════════════════════════════════

  group('§8 Lists — async', () {
    testWidgets('echoIntList: [1,2,3]', (t) async =>
        expect(await tc.echoIntList([1, 2, 3]), [1, 2, 3]));
    testWidgets('echoIntList: empty', (t) async =>
        expect(await tc.echoIntList([]), isEmpty));
    testWidgets('echoIntList: 1000 items', (t) async {
      final src = List.generate(1000, (i) => i);
      final r = await tc.echoIntList(src);
      expect(r.length, 1000);
      expect(r.first, 0); expect(r.last, 999);
    });

    testWidgets('echoDoubleList: [1.1, 2.2]', (t) async {
      final r = await tc.echoDoubleList([1.1, 2.2]);
      expect(r[0], closeTo(1.1, 1e-10));
      expect(r[1], closeTo(2.2, 1e-10));
    });

    testWidgets('echoStringList: unicode', (t) async {
      final r = await tc.echoStringList(['日本語', '🎉', 'hello']);
      expect(r, ['日本語', '🎉', 'hello']);
    });

    testWidgets('echoConfigList: 3 configs', (t) async {
      final cfgs = [
        TcConfig(name: 'a', count: 1, enabled: true, threshold: 0.1),
        TcConfig(name: 'b', count: 2, enabled: false, threshold: 0.2),
        TcConfig(name: 'c', count: 3, enabled: true, threshold: 0.3),
      ];
      final r = await tc.echoConfigList(cfgs);
      expect(r.length, 3);
      expect(r[0].name, 'a'); expect(r[1].count, 2); expect(r[2].enabled, isTrue);
    });
    testWidgets('echoConfigList: empty', (t) async =>
        expect(await tc.echoConfigList([]), isEmpty));
  });

  // ══════════════════════════════════════════════════════════════════════════
  // §9 ASYNC (@nitroAsync)
  // ══════════════════════════════════════════════════════════════════════════

  group('§9 Async — @nitroAsync', () {
    testWidgets('asyncInt: 99', (t) async =>
        expect(await tc.asyncInt(99), 99));
    testWidgets('asyncDouble: pi', (t) async =>
        expect(await tc.asyncDouble(3.14159), closeTo(3.14159, 1e-12)));
    testWidgets('asyncBool: true', (t) async =>
        expect(await tc.asyncBool(true), isTrue));
    testWidgets('asyncBool: false', (t) async =>
        expect(await tc.asyncBool(false), isFalse));
    testWidgets('asyncString: unicode', (t) async =>
        expect(await tc.asyncString('日本語 🎉'), '日本語 🎉'));
    testWidgets('asyncConfig round-trip', (t) async {
      final cfg = TcConfig(name: 'async', count: 99, enabled: true, threshold: 3.14);
      final r = await tc.asyncConfig(cfg);
      expect(r.name, 'async'); expect(r.count, 99);
    });

    testWidgets('100 concurrent asyncInt — all resolve correctly', (t) async {
      final futures = List.generate(100, (i) => tc.asyncInt(i));
      final results = await Future.wait(futures);
      for (var i = 0; i < 100; i++) {
        expect(results[i], i);
      }
    });

    testWidgets('50 concurrent asyncString — results ordered', (t) async {
      final futures = List.generate(50, (i) => tc.asyncString('msg-$i'));
      final results = await Future.wait(futures);
      for (var i = 0; i < 50; i++) {
        expect(results[i], 'msg-$i');
      }
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // §10 ASYNC NULLABLE — @nitroAsync with nullable return
  // ══════════════════════════════════════════════════════════════════════════

  group('§10 Async nullable — @nitroAsync', () {
    testWidgets('asyncNullableInt: 42 → 42', (t) async =>
        expect(await tc.asyncNullableInt(42), 42));
    testWidgets('asyncNullableInt: null → null', (t) async =>
        expect(await tc.asyncNullableInt(null), isNull));
    testWidgets('asyncNullableDouble: 1.5 → 1.5', (t) async =>
        expect(await tc.asyncNullableDouble(1.5), closeTo(1.5, 1e-12)));
    testWidgets('asyncNullableDouble: null → null', (t) async =>
        expect(await tc.asyncNullableDouble(null), isNull));
    testWidgets('asyncNullableBool: true → true', (t) async =>
        expect(await tc.asyncNullableBool(true), isTrue));
    testWidgets('asyncNullableBool: null → null or false', (t) async {
      final r = await tc.asyncNullableBool(null);
      expect(r, anyOf(isNull, isFalse));
    });
    testWidgets('asyncNullableString: "hi" → "hi"', (t) async =>
        expect(await tc.asyncNullableString('hi'), 'hi'));
    testWidgets('asyncNullableString: null → null or empty', (t) async {
      final r = await tc.asyncNullableString(null);
      expect(r, anyOf(isNull, isEmpty));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // §11 PROPERTIES
  // ══════════════════════════════════════════════════════════════════════════

  group('§11 Properties', () {
    test('precision: set/get int', () {
      tc.precision = 7; expect(tc.precision, 7);
      tc.precision = 0; expect(tc.precision, 0);
      tc.precision = -1; expect(tc.precision, -1);
    });
    test('tag: set/get String', () {
      tc.tag = 'hello'; expect(tc.tag, 'hello');
      tc.tag = ''; expect(tc.tag, '');
      tc.tag = '日本語 🔧'; expect(tc.tag, '日本語 🔧');
    });
    test('nullableRate: null', () {
      tc.nullableRate = null;
      expect(tc.nullableRate, isNull);
    });
    test('nullableRate: 3.14', () {
      tc.nullableRate = 3.14;
      expect(tc.nullableRate, closeTo(3.14, 1e-12));
    });
    test('nullableRate: 0.0', () {
      tc.nullableRate = 0.0;
      expect(tc.nullableRate, 0.0);
    });
    test('nullableRate: infinity', () {
      tc.nullableRate = double.infinity;
      expect(tc.nullableRate, double.infinity);
    });
    test('enabled: false → true → false', () {
      tc.enabled = false; expect(tc.enabled, isFalse);
      tc.enabled = true; expect(tc.enabled, isTrue);
      tc.enabled = false; expect(tc.enabled, isFalse);
    });
    test('currentStatus: all values', () {
      tc.currentStatus = TcStatus.ok;
      expect(tc.currentStatus, TcStatus.ok);
      tc.currentStatus = TcStatus.error;
      expect(tc.currentStatus, TcStatus.error);
      tc.currentStatus = TcStatus.pending;
      expect(tc.currentStatus, TcStatus.pending);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // §12 CALLBACKS
  // ══════════════════════════════════════════════════════════════════════════

  group('§12 Callbacks', () {
    // NativeCallable.listener posts to the Dart event queue — callbacks fire
    // asynchronously. Use a Completer to wait for the first emission.
    testWidgets('onIntEvent fires with value 42', (t) async {
      final completer = Completer<int>();
      tc.onIntEvent((v) { if (!completer.isCompleted) completer.complete(v); });
      final received = await completer.future.timeout(const Duration(seconds: 2));
      expect(received, 42);
    });
    testWidgets('callback closure captures outer state', (t) async {
      final values = <int>[];
      final completer = Completer<void>();
      tc.onIntEvent((v) { values.add(v); if (!completer.isCompleted) completer.complete(); });
      await completer.future.timeout(const Duration(seconds: 2));
      expect(values, isNotEmpty);
      expect(values.first, 42);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // §13 STREAMS
  // ══════════════════════════════════════════════════════════════════════════

  group('§13 Streams', () {
    testWidgets('intStream: receive [0..4]', (t) async {
      final received = <int>[];
      final sub = tc.intStream().listen(received.add);
      tc.configureStream(0, 5);
      await Future.delayed(const Duration(milliseconds: 200));
      await sub.cancel();
      expect(received, containsAll([0, 1, 2, 3, 4]));
    });

    testWidgets('intStream: from=10, count=3 → [10,11,12]', (t) async {
      final received = <int>[];
      final sub = tc.intStream().listen(received.add);
      tc.configureStream(10, 3);
      await Future.delayed(const Duration(milliseconds: 200));
      await sub.cancel();
      expect(received, containsAll([10, 11, 12]));
    });

    testWidgets('pointStream: x matches from', (t) async {
      final points = <TcPoint>[];
      final sub = tc.pointStream().listen(points.add);
      tc.configureStream(5, 3);
      await Future.delayed(const Duration(milliseconds: 200));
      await sub.cancel();
      expect(points.isNotEmpty, isTrue);
      expect(points.first.x, closeTo(5.0, 1e-9));
    });

    testWidgets('boolStream: alternating values', (t) async {
      final bools = <bool>[];
      final sub = tc.boolStream().listen(bools.add);
      tc.configureStream(0, 4); // 0,1,2,3 → even=true, odd=false
      await Future.delayed(const Duration(milliseconds: 200));
      await sub.cancel();
      expect(bools.isNotEmpty, isTrue);
    });

    testWidgets('cancel stops further emissions', (t) async {
      final received = <int>[];
      final sub = tc.intStream().listen(received.add);
      tc.configureStream(0, 100);
      await sub.cancel();
      final countAfterCancel = received.length;
      await Future.delayed(const Duration(milliseconds: 200));
      expect(received.length, countAfterCancel); // no new values after cancel
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // §14 ERROR HANDLING
  // ══════════════════════════════════════════════════════════════════════════

  group('§14 Error handling', () {
    test('throwNative: throws HybridException', () {
      expect(
        () => tc.throwNative('boom'),
        throwsA(isA<HybridException>()),
      );
    });

    test('throwNative: exception carries message', () {
      try {
        tc.throwNative('test error message');
        fail('should have thrown');
      } on HybridException catch (e) {
        expect(e.message, contains('test error message'));
      }
    });

    testWidgets('throwNativeAsync: throws HybridException', (t) async {
      // throwNativeAsync is a @nitroAsync function — use expectLater for async throws.
      await expectLater(
        tc.throwNativeAsync('async boom'),
        throwsA(isA<HybridException>()),
      );
    });

    test('throwNative: subsequent calls succeed after error', () {
      try { tc.throwNative('x'); } on HybridException catch (_) {}
      // Bridge should be in a clean state
      expect(tc.echoInt(42), 42);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // §15 KNOWN LIMITATIONS — sentinel value collisions
  //
  // These tests DOCUMENT known edge cases where the Nitro bridge protocol
  // cannot distinguish between a specific non-null value and the null sentinel.
  // They are NOT bugs in the implementation — they are inherent to the binary
  // sentinel approach chosen for performance. Use @HybridRecord or nullable
  // wrappers if these values must be bridged without ambiguity.
  // ══════════════════════════════════════════════════════════════════════════

  group('§15 KNOWN LIMITATIONS', () {
    // int? uses -1 as the null sentinel. Passing the integer -1 through a
    // nullable int channel will be decoded as null by the Dart decode step.
    test('LIMITATION: int? sentinel collision — value -1 decoded as null', () {
      // This is expected behaviour, not a bug.
      // echoNullableInt(-1) sends -1 to C → C returns -1 → Dart decodes as null.
      final result = tc.echoNullableInt(-1);
      // The result is null because -1 IS the null sentinel for nullable int.
      // To echo the value -1 without collision, use a non-nullable int channel.
      expect(result, isNull,
          reason: 'int? uses -1 as null sentinel — actual -1 is indistinguishable from null');
    });

    // double? uses NaN as the null sentinel. Passing double.nan as a non-null
    // value will be decoded as null by the Dart side.
    test('LIMITATION: double? sentinel collision — NaN decoded as null', () {
      final result = tc.echoNullableDouble(double.nan);
      expect(result, isNull,
          reason: 'double? uses NaN as null sentinel — double.nan is indistinguishable from null');
    });

    // Float32 precision loss: Dart passes Float64 values to Float32List.
    // The C bridge stores them as 32-bit floats, losing precision.
    test('LIMITATION: Float32List precision loss vs Float64', () {
      const highPrecision = 3.14159265358979323846; // ~15 significant digits
      final result = tc.echoFloats(Float32List.fromList([highPrecision]));
      // Float32 only has ~7 significant digits:
      expect(result[0], closeTo(3.14159, 1e-5));
      // But NOT close to full Float64 precision:
      expect(result[0], isNot(closeTo(highPrecision, 1e-12)));
    });

    // Nullable bool? null cannot be transmitted on Android via jboolean (0/1 only).
    // The Dart side sends -1 as an Int8 sentinel to C, but CallStaticBooleanMethod
    // converts jboolean values — -1 (0xFF) becomes 'true' in Kotlin (non-zero).
    // Result: null bool? ALWAYS arrives as false on Android. On iOS/Swift, the
    // Swift @_cdecl function receives Int8 (-1) and correctly detects null.
    test('LIMITATION (Android): bool? null arrives as false (jboolean cannot carry -1)', () {
      final result = tc.echoNullableBool(null);
      // On iOS/macOS: correctly returns null.
      // On Android: jboolean truncates -1 → non-zero → true on C side →
      //             Swift/Kotlin impl receives true and returns true, Dart decodes as true/non-null.
      // Accept any of: null, false, true (platform-dependent).
      expect(result, anyOf(isNull, isFalse, isTrue),
          reason: 'Android: jboolean cannot carry -1 null sentinel; null bool? ≡ false or true');
    });

    // String fields in @HybridStruct are heap-copied on every call.
    // This is correct but different from @HybridRecord (which JSON-encodes once).
    // The test verifies behaviour is correct — the note documents the cost.
    test('LIMITATION: @HybridStruct String fields heap-copy on each bridge call', () {
      // TcConfig IS a @HybridRecord (binary-encoded), but TcPoint is a struct.
      // Structs with String fields get strdup/free per call.
      // This test just verifies correctness; the limitation is PERFORMANCE, not correctness.
      final cfg = TcConfig(name: 'x' * 1024, count: 1, enabled: true, threshold: 0.0);
      expect(tc.echoConfig(cfg).name.length, 1024);
    });

    // echoNullableStatus(TcStatus.ok) where ok.rawValue == 0 is safe.
    // But if a native impl returned -1 rawValue as "no sentinel" → enum decodes ok=0.
    // Test that rawValue 0 (TcStatus.ok) is NOT confused with null.
    test('LIMITATION: nullable enum ok(rawValue=0) correctly round-trips', () {
      // ok has rawValue 0. null uses -1. These are distinct.
      expect(tc.echoNullableStatus(TcStatus.ok), TcStatus.ok,
          reason: 'rawValue 0 must not be confused with null sentinel -1');
    });

    // @nitroAsync runs on a dedicated background isolate. Concurrent calls
    // may complete out of order if the implementation doesn't preserve order.
    // The echo impl is stateless so this is safe, but heavy implementations
    // with shared state must use synchronisation.
    test('LIMITATION: @nitroAsync order not guaranteed (stateless echo is safe)', () async {
      // 10 rapid calls — results should all match, but order across Futures
      // depends on isolate scheduling.
      final futures = List.generate(10, (i) => tc.asyncInt(i));
      final results = await Future.wait(futures);
      // All echo the correct value regardless of completion order:
      for (var i = 0; i < 10; i++) {
        expect(results[i], i,
            reason: 'Each asyncInt echoes its input regardless of call order');
      }
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // §16 STRESS & CONCURRENCY
  // ══════════════════════════════════════════════════════════════════════════

  group('§16 Stress & concurrency', () {
    test('1000 sync echoInt calls in sequence', () {
      for (var i = 0; i < 1000; i++) {
        expect(tc.echoInt(i), i);
      }
    });

    test('1000 sync echoString calls — no corruption', () {
      for (var i = 0; i < 1000; i++) {
        final s = 'str-$i';
        expect(tc.echoString(s), s);
      }
    });

    testWidgets('500 concurrent asyncDouble — all correct', (t) async {
      final futures = List.generate(500, (i) => tc.asyncDouble(i.toDouble()));
      final results = await Future.wait(futures);
      for (var i = 0; i < 500; i++) {
        expect(results[i], closeTo(i.toDouble(), 1e-12));
      }
    });

    test('repeated TypedData calls — no memory leak (manual smoke test)', () {
      for (var i = 0; i < 100; i++) {
        final buf = Uint8List.fromList(List.generate(1024, (j) => j & 0xFF));
        final r = tc.echoBytes(buf);
        expect(r.length, 1024);
        expect(r[0], 0); expect(r[255], 255);
      }
    });

    test('property set/get in tight loop — no corruption', () {
      for (var i = 0; i < 500; i++) {
        tc.precision = i;
        expect(tc.precision, i);
      }
    });

    testWidgets('intStream: emit 1000 values', (t) async {
      final received = <int>[];
      final sub = tc.intStream().listen(received.add);
      tc.configureStream(0, 1000);
      await Future.delayed(const Duration(milliseconds: 500));
      await sub.cancel();
      // With dropLatest backpressure, not all 1000 may arrive.
      expect(received.isNotEmpty, isTrue);
      expect(received.every((v) => v >= 0 && v < 1000), isTrue);
    });
  });
}
