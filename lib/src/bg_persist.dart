/// Where a background entry point leaves its result for the app to read later.
/// `Directory.systemTemp` resolves to the app's own cache/tmp dir on Android
/// and iOS, so a headless engine and the UI process see the same file.
library;

export 'bg_persist_io.dart' if (dart.library.js_interop) 'bg_persist_web.dart';
