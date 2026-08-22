// Type-coverage browser tests: the whole wire surface through the WASM bridge.
//
// This is the same C++ implementation the Windows and Linux targets compile —
// src/HybridNitroTypeCoverage.cpp, built by em++ — so a failure here is the
// web bridge, not the implementation.
//
// Build the module first, then run under BOTH compilers. They differ at the
// js_interop boundary (dart2js `.toDart` is a cast, dart2wasm's is a copy, and
// out-of-range typed-data indices wrap to 0 under i32 instead of trapping), so
// a green dart2js run does not imply dart2wasm:
//   web/build_web.sh
//   dart test -p chrome
//   dart test -p chrome -c dart2wasm
@TestOn('browser')
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:nitro_type_coverage/nitro_type_coverage.dart';

void main() {
  late NitroTypeCoverage api;

  setUpAll(() async {
    final channel = spawnHybridUri('asset_server.dart');
    // dart2wasm hands JS numbers over as double — never cast with `as int`.
    final port = ((await channel.stream.first)! as num).toInt();
    await ensureNitroTypeCoverageReady(
      jsUrl: 'http://localhost:$port/nitro_type_coverage.js',
    );
    api = NitroTypeCoverage.instance;
  });

  group('primitives', () {
    test('int round-trips, including past the 32-bit boundary', () {
      expect(api.echoInt(0), 0);
      expect(api.echoInt(-7), -7);
      // Above 2^32: a value that an i32 truncation would mangle.
      expect(api.echoInt(1 << 40), 1 << 40);
    });

    test('double, bool, String', () {
      expect(api.echoDouble(3.5), 3.5);
      expect(api.echoDouble(-0.125), -0.125);
      expect(api.echoBool(true), isTrue);
      expect(api.echoBool(false), isFalse);
      expect(api.echoString('hello'), 'hello');
      expect(api.echoString(''), '');
      // Multi-byte: the string crosses as UTF-8 bytes, not UTF-16 units.
      expect(api.echoString('ünïcødé ✓ 日本語'), 'ünïcødé ✓ 日本語');
    });

    test('multi-param signatures keep argument order', () {
      expect(api.addInts(1, 2, 3), 6);
      expect(api.mulDoubles(1.5, 4), 6.0);
      expect(api.joinStrings('a', 'b', '-'), 'a-b');
    });
  });

  group('nullables', () {
    test('nullable primitives carry null distinctly from zero', () {
      expect(api.echoNullableInt(null), isNull);
      expect(api.echoNullableInt(0), 0);
      expect(api.echoNullableDouble(null), isNull);
      expect(api.echoNullableDouble(0), 0.0);
      expect(api.echoNullableBool(null), isNull);
      expect(api.echoNullableBool(false), isFalse);
      expect(api.echoNullableString(null), isNull);
      expect(api.echoNullableString(''), '');
    });

    test('NitroNullable* wrappers survive the packed layout', () {
      // hasValue travels beside the value, so 0-with-a-value stays distinct
      // from absent — the whole point of the wrapper over a sentinel.
      final present = api.echoNullableIntSafe(NitroNullableInt.fromNullable(42));
      expect(present.hasValue, isTrue);
      expect(present.nullable, 42);

      final zero = api.echoNullableIntSafe(NitroNullableInt.fromNullable(0));
      expect(zero.hasValue, isTrue);
      expect(zero.nullable, 0);

      final absent = api.echoNullableIntSafe(NitroNullableInt.fromNullable(null));
      expect(absent.hasValue, isFalse);
      expect(absent.nullable, isNull);
    });
  });

  group('DateTime', () {
    test('crosses as ms-epoch int64 without drift', () {
      final now = DateTime.fromMillisecondsSinceEpoch(1755731234567);
      expect(api.echoDateTime(now).millisecondsSinceEpoch, now.millisecondsSinceEpoch);
      expect(api.echoNullableDateTime(null), isNull);
    });
  });

  group('enum / struct / record', () {
    test('enum values round-trip by native value', () {
      expect(api.echoStatus(TcStatus.ok), TcStatus.ok);
      expect(api.echoStatus(TcStatus.pending), TcStatus.pending);
      expect(api.echoNullableStatus(null), isNull);
      expect(api.echoNullableStatus(TcStatus.error), TcStatus.error);
    });

    test('@HybridStruct packed layout', () {
      final p = api.echoPoint(TcPoint(x: 1.5, y: -2.5, z: 0.25));
      expect(p.x, 1.5);
      expect(p.y, -2.5);
      expect(p.z, 0.25);
    });

    test('@HybridRecord framed codec, mixed field kinds', () {
      final c = api.echoConfig(
        TcConfig(name: 'cfg', count: 7, enabled: true, threshold: 2.5),
      );
      expect(c.name, 'cfg');
      expect(c.count, 7);
      expect(c.enabled, isTrue);
      expect(c.threshold, 2.5);

      // Enum field inside a record — field ordering is what breaks first when
      // a codec drifts, so assert every field.
      final pk = api.echoPacket(
        TcPacket(name: 'p', sequence: 3, status: TcStatus.pending, valid: true),
      );
      expect(pk.name, 'p');
      expect(pk.sequence, 3);
      expect(pk.status, TcStatus.pending);
      expect(pk.valid, isTrue);
    });

    test('record with TypedData fields', () {
      final r = api.echoDataRecord(TcDataRecord(
        bytes: Uint8List.fromList([1, 2, 3]),
        values: Int32List.fromList([-1, 0, 7]),
        scores: Float64List.fromList([0.5, 2.25]),
        label: 'mixed',
      ));
      expect(r.bytes, [1, 2, 3]);
      expect(r.values, [-1, 0, 7]);
      expect(r.scores, [0.5, 2.25]);
      expect(r.label, 'mixed');
    });
  });

  group('typed data (@zeroCopy)', () {
    test('element types keep their width and sign', () {
      expect(api.echoBytes(Uint8List.fromList([0, 127, 255])), [0, 127, 255]);
      expect(api.echoInt8s(Int8List.fromList([-128, 0, 127])), [-128, 0, 127]);
      expect(api.echoInt16s(Int16List.fromList([-32768, 0, 32767])), [-32768, 0, 32767]);
      expect(
        api.echoInt32s(Int32List.fromList([-2147483648, 0, 2147483647])),
        [-2147483648, 0, 2147483647],
      );
      expect(api.echoFloats(Float32List.fromList([0.5, -2.25])), [0.5, -2.25]);
      expect(api.echoFloat64s(Float64List.fromList([0.5, -2.25, 1e300])), [0.5, -2.25, 1e300]);
    });

    test('the length argument is elements, not bytes', () {
      // The C side takes `(const T* v, size_t v_length)` and multiplies by
      // sizeof(T). Passing lengthInBytes here returned sizeof(T)x too many
      // elements — with trailing heap garbage — for every type wider than a
      // byte, while Uint8List/Int8List looked fine because there the two
      // lengths coincide. Assert the exact length, not just the prefix.
      expect(api.echoInt32s(Int32List.fromList([1, 2, 3])), hasLength(3));
      expect(api.echoInt16s(Int16List.fromList([1, 2, 3])), hasLength(3));
      expect(api.echoFloat64s(Float64List.fromList([1, 2, 3])), hasLength(3));
    });

    test('empty buffers survive the length-prefix path', () {
      expect(api.echoBytes(Uint8List(0)), isEmpty);
      expect(api.echoInt32s(Int32List(0)), isEmpty);
    });
  });

  group('tuple / variant', () {
    test('@NitroTuple positional record', () {
      final pair = api.echoPair((7, 'seven'));
      expect(pair.$1, 7);
      expect(pair.$2, 'seven');
    });

    test('nullable tuple keeps null distinct', () {
      expect(api.echoNullablePair(null), isNull);
      final pair = api.echoNullablePair((1, 'one'));
      expect(pair!.$1, 1);
      expect(pair.$2, 'one');
    });

    test('@NitroVariant dispatches on the case tag', () {
      final tap = api.echoEvent(TcEventTap(x: 3, y: 4));
      expect(tap, isA<TcEventTap>());
      expect((tap as TcEventTap).x, 3);
      expect(tap.y, 4);

      final scroll = api.echoEvent(TcEventScroll(delta: -1.5));
      expect(scroll, isA<TcEventScroll>());
      expect((scroll as TcEventScroll).delta, -1.5);
    });
  });

  group('maps', () {
    test('primitive-valued maps', () {
      expect(api.echoIntMap({'a': 1, 'b': 2}), {'a': 1, 'b': 2});
      expect(api.echoStringMap({'k': 'v'}), {'k': 'v'});
      expect(api.echoIntMap(const {}), isEmpty);
    });

    test('record-valued map (tagged blob values)', () {
      final out = api.echoConfigMap({
        'one': TcConfig(name: 'one', count: 1, enabled: true, threshold: 0.5),
      });
      expect(out.keys, ['one']);
      expect(out['one']!.name, 'one');
      expect(out['one']!.threshold, 0.5);
    });
  });

  group('lists (@nitroAsync)', () {
    test('primitive lists', () async {
      expect(await api.echoIntList([1, 2, 3]), [1, 2, 3]);
      expect(await api.echoIntList(const []), isEmpty);
      expect(await api.echoStringList(['a', '']), ['a', '']);
    });

    test('List<@HybridRecord> — the indexed offset-table path', () async {
      // Variable-length names on purpose: a fixed-size record can mask an
      // offset-table bug whose stride happens to stay uniform.
      final out = await api.echoConfigList([
        TcConfig(name: '', count: 0, enabled: false, threshold: 0),
        TcConfig(name: 'a', count: 1, enabled: true, threshold: 1.5),
        TcConfig(name: 'a much longer name', count: 2, enabled: false, threshold: -2.5),
      ]);
      expect(out, hasLength(3));
      expect(out[0].name, '');
      expect(out[1].name, 'a');
      expect(out[1].threshold, 1.5);
      expect(out[2].name, 'a much longer name');
      expect(out[2].count, 2);
    });
  });

  group('async (@nitroAsync)', () {
    test('scalars and records', () async {
      expect(await api.asyncInt(5), 5);
      expect(await api.asyncString('s'), 's');
      expect(await api.asyncNullableInt(null), isNull);
      final c = await api.asyncConfig(
        TcConfig(name: 'x', count: 1, enabled: false, threshold: 0.25),
      );
      expect(c.name, 'x');
      expect(c.threshold, 0.25);
    });
  });

  group('native async (@nitroNativeAsync)', () {
    // On web these complete inline and are delivered on a microtask — the
    // std::thread the native build uses aborts in a single-threaded wasm.
    test('completes through the post callback', () async {
      expect(await api.nativeAsyncInt(11), 11);
      expect(await api.nativeAsyncDouble(1.5), 1.5);
      expect(await api.nativeAsyncBool(true), isTrue);
      expect(await api.nativeAsyncString('posted'), 'posted');
    });

    test('concurrent calls each resolve to their own value', () async {
      final results = await Future.wait([
        api.nativeAsyncInt(1),
        api.nativeAsyncInt(2),
        api.nativeAsyncInt(3),
      ]);
      expect(results, [1, 2, 3]);
    });
  });

  group('streams', () {
    test('int stream emits in order', () async {
      final got = <int>[];
      final sub = api.intStream().listen(got.add);
      api.configureStream(10, 5);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await sub.cancel();
      expect(got, [10, 11, 12, 13, 14]);
    });

    test('record stream carries framed payloads', () async {
      final got = <TcConfig>[];
      final sub = api.configStream().listen(got.add);
      api.configureConfigStream(
        TcConfig(name: 'seed', count: 1, enabled: true, threshold: 0.5),
        3,
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await sub.cancel();
      expect(got, hasLength(3));
    });
  });

  group('@NitroResult', () {
    test('ok branch carries the value', () {
      final r = api.safeDiv(9, 3);
      expect(r, isA<NitroOk<double>>());
      expect((r as NitroOk<double>).value, 3.0);

      final label = api.validateLabel('  spaced  ');
      expect((label as NitroOk<String>).value, 'spaced');

      final cfg = api.getConfigOrFail(false);
      expect((cfg as NitroOk<TcConfig>).value.name, 'desktop-fix');
    });

    test('err branch carries the native message instead of throwing', () {
      final r = api.safeDiv(1, 0);
      expect(r, isA<NitroErr>());
      expect((r as NitroErr).message, contains('division by zero'));

      expect((api.validateLabel('   ') as NitroErr).message, contains('empty label'));
      expect((api.getConfigOrFail(true) as NitroErr).message, contains('shouldFail'));
    });
  });

  group('callbacks', () {
    // The C++ impl invokes these synchronously inside the call, so a value
    // must be in hand the moment the call returns. A timeout rather than a
    // bare `await` — a callback that never fires would otherwise hang the
    // suite instead of failing it.
    test('void callbacks fire synchronously', () async {
      final bools = <bool>[];
      api.onBoolEvent(bools.add);
      expect(bools, isNotEmpty, reason: 'boolCb(true) is called inline by C++');

      final doubles = <double>[];
      api.onDoubleEvent(doubles.add);
      expect(doubles, isNotEmpty);
      expect(doubles.first, closeTo(2.71828, 1e-9));
    });

    test('a Completer-style callback resolves', () async {
      final c = Completer<bool>();
      api.onBoolEvent(c.complete);
      await expectLater(
        c.future.timeout(const Duration(seconds: 5)),
        completion(isA<bool>()),
      );
    });
  });

  // Web analogues of the §M RSS soak. A browser exposes no per-tab RSS, but
  // the two resources the WASM bridge can actually exhaust — function-table
  // slots and the module refcount — are observable by their symptoms.
  group('soak (web resource leaks)', () {
    test('re-registering a callback many times neither throws nor stops firing', () {
      // Each registration adds a table entry and releases the previous one on
      // a microtask. When removeFunction was missing from
      // EXPORTED_RUNTIME_METHODS that release threw NoSuchMethodError out of
      // the microtask, landing in whatever test ran next; one registration
      // never showed it.
      for (var i = 0; i < 500; i++) {
        final seen = <bool>[];
        api.onBoolEvent(seen.add);
        expect(seen, isNotEmpty, reason: 'registration $i must still fire');
      }
    });

    test('create/dispose cycles do not evict the module', () {
      // dispose() releases a lib reference, so the constructor must take one.
      // Without the matching retain the FIRST dispose dropped the refcount to
      // zero and every later call died with "WASM module not loaded yet".
      for (var i = 0; i < 50; i++) {
        final inst = NitroTypeCoverage.getInstance('soak-$i');
        expect(inst.echoInt(i), i);
        inst.dispose();
      }
      // The shared default instance must be untouched by all that churn.
      expect(api.echoInt(7), 7);
    });
  });

  group('errors', () {
    test('a C++ exception surfaces as a HybridException', () {
      expect(
        () => api.throwNative('boom from wasm'),
        throwsA(predicate((e) => '$e'.contains('boom from wasm'))),
      );
    });
  });
}
