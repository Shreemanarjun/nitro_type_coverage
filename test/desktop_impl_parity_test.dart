// The C++ impl exists three times: src/ (Apple/Android/wasm) plus trimmed
// linux/src/ and windows/src/ copies that the desktop CMake builds compile.
// They are maintained by hand, so a method added to the spec reaches src/ and
// silently misses the desktop copies — `echoRichStruct` did exactly that and
// only surfaced from an ad-hoc clang syntax check.
//
// The generated header is the contract: every pure virtual must be
// implemented in ALL THREE copies.
import 'dart:io';

import 'package:test/test.dart';

final _pureVirtual = RegExp(r'^\s*virtual\s+.*?\b(\w+)\s*\([^;]*\)\s*=\s*0\s*;', multiLine: true);
final _override = RegExp(r'^\s*[\w:<>&,\s\*]+?\b(\w+)\s*\([^;{]*\)\s*(?:const\s+)?override\b', multiLine: true);

Set<String> _names(RegExp re, String path) =>
    re.allMatches(File(path).readAsStringSync()).map((m) => m.group(1)!).toSet();

void main() {
  test('every pure virtual is implemented in all three C++ copies', () {
    final required = _names(_pureVirtual, 'lib/src/generated/cpp/nitro_type_coverage.native.g.h');
    expect(required, isNotEmpty, reason: 'no pure virtuals parsed — the regex or header path is wrong');

    for (final impl in ['src', 'linux/src', 'windows/src']) {
      final implemented = _names(_override, '$impl/HybridNitroTypeCoverage.cpp');
      expect(
        required.difference(implemented),
        isEmpty,
        reason: '$impl/HybridNitroTypeCoverage.cpp is missing spec methods — desktop builds will fail to instantiate the impl',
      );
    }
  });
}
