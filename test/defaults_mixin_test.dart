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

void main() {
  test('overridden members work, un-overridden ones fail at call time with the member name', () {
    final fake = _Fake();
    expect(fake.addInts(1, 2, 3), 6);
    expect(() => fake.precision, throwsA(isA<UnimplementedError>().having((e) => e.message, 'message', 'NitroTypeCoverage.precision')));
    expect(() => fake.configStream(), throwsA(isA<UnimplementedError>()));
  });
}
