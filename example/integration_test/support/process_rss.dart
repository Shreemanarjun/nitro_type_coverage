// Resident-set-size probe, conditionally implemented.
//
// `dart:io` does not exist on web, so importing ProcessInfo directly makes the
// whole suite uncompilable for `-d chrome` — 276 web-capable tests lost for the
// sake of one that cannot run there anyway. The web twin reports "unavailable"
// and the RSS group skips itself.
export 'process_rss_io.dart' if (dart.library.js_interop) 'process_rss_web.dart';
