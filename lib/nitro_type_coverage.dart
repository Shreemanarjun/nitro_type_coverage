export 'src/nitro_type_coverage.native.dart';
// On web the WASM module loads asynchronously, so callers MUST await this
// before touching NitroTypeCoverage.instance. It is a no-op on every native
// platform, which makes `await ensureNitroTypeCoverageReady()` in main() the
// one portable startup line. Without this re-export web consumers would have
// to reach into src/ for it.
export 'src/nitro_type_coverage.platform.g.dart' show ensureNitroTypeCoverageReady;
// Re-export NitroNullable types so users don't need to import package:nitro separately.
export 'package:nitro/nitro.dart' show NitroNullableInt, NitroNullableDouble, NitroNullableBool,
    IntNullableExt, DoubleNullableExt, BoolNullableExt,
    NitroNullableIntExt, NitroNullableDoubleExt, NitroNullableBoolExt,
    NitroResultValue, NitroOk, NitroErr,
    NativeHandle;
