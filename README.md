# nitro_type_coverage

A comprehensive integration-test plugin for the [Nitrogen](https://github.com/shreemanarjunsahu/nitro_ecosystem) code generator. It exercises every type, annotation, and platform path the generator supports — from simple scalars to `@NitroVariant`, `@NitroResult`, and `@NitroOwned` — and verifies them end-to-end on macOS, iOS, Android, Linux, and Windows.

---

## Purpose

`nitro_type_coverage` is **not** a library you publish or ship. It is a living test harness that:

- Confirms the generator produces valid native code for every supported type
- Catches regressions across all five target platforms with a single command
- Documents expected behaviour for each Nitrogen annotation as runnable tests

---

## What Is Tested

### Scalar types
`int`, `double`, `bool`, `String`, `void` — sync and async, as params and return values.

### Nullable scalars
`int?`, `double?`, `bool?`, `String?` — `NitroNullable` wire encoding confirmed on all platforms.

### Collections & Buffers
All 10 `TypedData` variants: `Uint8List`, `Int8List`, `Int16List`, `Int32List`, `Uint16List`, `Uint32List`, `Float32List`, `Float64List`, `Int64List`, `Uint64List`.

### Custom types
| Annotation | What is tested |
|---|---|
| `@HybridStruct` | Flat, nested, and deeply-nested structs as params and return values |
| `@HybridEnum` | Enum-typed params, returns, and nullable enums |
| `@HybridRecord` | Compact binary-encoded complex types; `List<@HybridRecord>` |

### Advanced annotations
| Annotation | What is tested |
|---|---|
| `@NitroVariant` | Discriminated union (sealed class) round-trip — encode/decode across `TcEvent` (Tap/Scroll/Resize) |
| `@NitroResult<T>` | `NitroOk<T>` / `NitroErr` path — `safeDiv` (double) and `validateLabel` (String) |
| `@NitroOwned` | `NativeHandle<T>` via `acquireBuffer`; finalizer release symbol verified on all platforms |
| `@nitroAsync` | Background-isolate dispatch for async methods |
| `@NitroStream` | Native-to-Dart event streams with all backpressure modes |
| `@ZeroCopy` | Zero-copy `Uint8List` transfer path |

### Properties
Getter-only and getter+setter properties for every scalar and custom type.

---

## Repository Structure

```
nitro_type_coverage/
├── lib/
│   ├── nitro_type_coverage.dart          # public re-exports
│   └── src/
│       ├── nitro_type_coverage.native.dart   # spec file (source of truth)
│       ├── nitro_type_coverage.g.dart         # generated Dart FFI impl
│       └── generated/
│           ├── swift/   *.bridge.g.swift      # Swift @_cdecl bridge
│           ├── kotlin/  *.bridge.g.kt         # Kotlin JNI bridge
│           └── cpp/     *.bridge.g.{h,cpp}    # C/C++ headers + bridge
├── ios/Classes/
│   ├── NitroTypeCoverageImpl.swift        # iOS Swift implementation
│   ├── nitro_type_coverage.bridge.g.swift # synced from generated/swift/
│   └── nitro_type_coverage.bridge.g.mm   # synced from generated/cpp/
├── macos/Classes/
│   └── (same layout as ios/Classes/)
├── android/src/main/kotlin/
│   └── NitroTypeCoverageImpl.kt          # Android Kotlin implementation
├── example/
│   └── integration_test/type_coverage_test.dart  # ~2,700 lines of tests
└── scripts/
    └── run_tests.sh                       # cross-platform test runner
```

---

## Running the Tests

### One-command auto-detect

```sh
cd nitro_type_coverage
./scripts/run_tests.sh
```

The script regenerates all bridges, syncs platform files, detects every available device, and runs integration tests. It skips platforms unavailable on the current host (macOS required for iOS; Linux/Windows host required for their respective targets).

### Platform-specific runs

```sh
./scripts/run_tests.sh macos      # macOS desktop
./scripts/run_tests.sh ios        # first connected iOS device/simulator
./scripts/run_tests.sh android    # first connected Android device/emulator
./scripts/run_tests.sh linux      # Linux desktop (Linux host only)
./scripts/run_tests.sh windows    # Windows desktop (Windows host only)
./scripts/run_tests.sh all        # every available platform + all Android devices
```

### Manual

```sh
# 1. Regenerate bridges
cd nitro_type_coverage
dart run build_runner build --delete-conflicting-outputs

# 2. Sync Apple platform files
cp lib/src/generated/swift/nitro_type_coverage.bridge.g.swift ios/Classes/
cp lib/src/generated/swift/nitro_type_coverage.bridge.g.swift macos/Classes/
cp lib/src/generated/cpp/nitro_type_coverage.bridge.g.cpp     ios/Classes/nitro_type_coverage.bridge.g.mm
cp lib/src/generated/cpp/nitro_type_coverage.bridge.g.cpp     macos/Classes/nitro_type_coverage.bridge.g.mm
cp lib/src/generated/cpp/nitro_type_coverage.bridge.g.h       ios/Classes/
cp lib/src/generated/cpp/nitro_type_coverage.bridge.g.h       macos/Classes/

# 3. Run on a specific device
cd example
flutter test integration_test/type_coverage_test.dart -d macos
```

---

## Key Implementation Notes

### `@NitroOwned` — `acquireBuffer`

`acquireBuffer(int size) → NativeHandle<Void>` allocates a raw buffer on the native side and hands ownership to Dart via a `NativeFinalizer`. The generated bridge emits a `_release` symbol (`nitro_type_coverage_acquire_buffer_release`) in the **global section** of the C++ bridge, before any platform guard:

```cpp
// In nitro_type_coverage.bridge.g.cpp — compiled on ALL platforms:
extern "C" {
NITRO_EXPORT void nitro_type_coverage_acquire_buffer_release(void* handle) {
#ifdef __ANDROID__
    (void)handle;       // jlong handle — Kotlin GC manages lifecycle
#else
    if (handle) { free(handle); }  // malloc'd by UnsafeMutableRawPointer.allocate
#endif
}
}
```

### `@NitroVariant` — `TcEvent`

`TcEvent` is a discriminated union with three cases: `TcTap`, `TcScroll`, `TcResize`. The wire format is `[4B length][1B tag][fields]`. Swift generates a `fromReader`/`writeFields` enum; Kotlin generates a sealed class. The protocol method uses `TcEvent` (not `Any`) as both param and return type.

### `@NitroResult<T>` — `safeDiv` / `validateLabel`

Methods annotated with `@NitroResult` return a `NitroResultValue<T>` in Dart (`NitroOk<T>` or `NitroErr`). The Swift protocol uses `throws -> T`. The wire format is `[1B tag: 0=ok, 1=err][payload]`.

### Platform sync requirement

After every `build_runner build`, the following files **must** be manually copied to the platform directories (the `run_tests.sh` script does this automatically):

| Source | Destination(s) |
|---|---|
| `lib/src/generated/swift/*.bridge.g.swift` | `ios/Classes/`, `macos/Classes/`, `macos/nitro_type_coverage/Sources/NitroTypeCoverage/` |
| `lib/src/generated/cpp/*.bridge.g.cpp` | `ios/Classes/*.bridge.g.mm`, `macos/Classes/*.bridge.g.mm` |
| `lib/src/generated/cpp/*.bridge.g.h` | `ios/Classes/`, `macos/Classes/` |

---

## Generator Tests

The unit tests for the generator itself live in the parent monorepo:

```sh
cd ../../nitro_ecosystem
dart test packages/nitro_generator/test/
# → 3200 tests, 0 failures
```

Key test files covering the types used in this plugin:

| Test file | Covers |
|---|---|
| `nitro_variant_test.dart` | `@NitroVariant` Swift/Kotlin/C++; `@NitroResult`; `@NitroOwned` guard/release |
| `native_handle_test.dart` | `NativeHandle<T>` full 5-generator implementation |
| `all_generators_type_coverage_test.dart` | Every type across all generators in parallel |
