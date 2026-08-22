// Driver for `flutter drive` runs, including the browser (`-d chrome`).
//
// Uses the EXTENDED driver deliberately. The plain
// `integration_test_driver.dart` has no WebDriver handshake, so against a web
// target it reports "All tests passed" without the suite ever running — a
// deliberately failing assertion still exits 0. The extended driver speaks the
// `web_driver_command` protocol and asks for the real results.
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver();
