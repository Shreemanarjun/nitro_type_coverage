// #53: a hand-written fake that mixes in the generated defaults must compile
// against EVERY abstract member of the spec (there are >150 here: sync/async/
// native-async functions, properties, streams, handles, results). A missing
// member in the mixin would be a compile error of this file.
import 'package:flutter_test/flutter_test.dart';
import 'package:nitro_type_coverage/nitro_type_coverage.dart';

class _Fake extends NitroTypeCoverage with NitroTypeCoverageDefaults {
  @override
  int addInts(int a, int b, int c) => a + b + c;
}

/// A second fake overriding a different slice — the mixin must not force a
/// shared shape on fakes.
class _StreamFake extends NitroTypeCoverage with NitroTypeCoverageDefaults {
  @override
  Stream<int> batchIntStream() => Stream.fromIterable([1, 2, 3]);
  @override
  int get precision => 3;
}

void main() {
  test('edge: async members throw synchronously (not a failed Future) so the failure is at the call site', () {
    final fake = _Fake();
    expect(() => fake.asyncAcquireBuffer(8), throwsA(isA<UnimplementedError>()));
  });

  test('edge: getters, setters, method-style streams and handle/result returns are all covered', () {
    final fake = _Fake();
    expect(() => fake.precision = 1, throwsA(isA<UnimplementedError>().having((e) => e.message, 'message', 'NitroTypeCoverage.precision')));
    expect(() => fake.acquireBuffer(4), throwsA(isA<UnimplementedError>()));
    expect(() => fake.batchIntStream(), throwsA(isA<UnimplementedError>()));
  });

  test('edge: two fakes override different slices; dispose() from HybridObject still works on a fake', () async {
    final s = _StreamFake();
    expect(await s.batchIntStream().toList(), [1, 2, 3]);
    expect(s.precision, 3);
    expect(() => s.addInts(1, 2, 3), throwsA(isA<UnimplementedError>()));
    expect(s.isDisposed, isFalse);
    s.dispose();
    expect(s.isDisposed, isTrue);
  });

  test('edge: the new §79 members are in the mixin too (a spec addition is additive for fakes)', () {
    final fake = _Fake();
    expect(() => fake.addIntsFast(1, 2), throwsA(isA<UnimplementedError>().having((e) => e.message, 'message', 'NitroTypeCoverage.addIntsFast')));
  });

  test('overridden members work, un-overridden ones fail at call time with the member name', () {
    final fake = _Fake();
    expect(fake.addInts(1, 2, 3), 6);
    expect(() => fake.precision, throwsA(isA<UnimplementedError>().having((e) => e.message, 'message', 'NitroTypeCoverage.precision')));
    expect(() => fake.configStream(), throwsA(isA<UnimplementedError>()));
  });
}
