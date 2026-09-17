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

### §79 — `...Fast` hot paths and `NativeHandle` parameters

Every scalar shape a hot loop uses (`int`, `void`, `double`, `bool`, enum,
nullable) as a `Fast` method, a `Fast` method with a String argument (keeps the
arena path), a `Fast` method whose native side throws (swallowed by contract;
the next checked call must still be clean because the bridge clears the error
slot per call), and methods taking a `NativeHandle` (`bufferFill`,
`bufferFirstByteFast`) over a buffer from `acquireBuffer`, and the same
contract via the `@nitroFast` annotation without a name suffix (`addIntsHot`,
`bufferFirstByteHot`). All five native
implementations carry them; the Kotlin one reads bytes through `Unsafe` and
masks the JVM's signed `Byte` — the first thing this section caught.

`addIntsInline` is `@nitroFast` + `@nitroNativeAsync`: the Dart signature is
`Future<int>` but the bridge call is synchronous and the future completes
inline (no port, no isolate wake); every native impl is a plain sync method.
The test compares it against `nativeAsyncInt` (port post) and requires it to
be at least 2× faster on every native platform.

### §80 — `@NitroEntryPoint` with every parameter kind

`bgProgress`, `bgHandleFirstByte`, `bgKeyedMaps`, `bgAnyNative`,
`bgTickWithCallback` and `bgRecordCallback` cover: `void` callbacks (each call
is proxied back to the submitting isolate; the proxy ports close when the job
ends), an optional nullable callback, `NativeHandle<Void>` by address (caller
keeps ownership), `Map<int, …>` / `Map<TcStatus, …>`, `AnyNativeObject` by id,
nullable handles inside a list, a stream entry with a callback, struct + enum
callback arguments, and 20 concurrent callback jobs. Runs on macOS (spawned
isolate), Android and iOS (headless engines).

### Patrol — OS-driven `@NitroEntryPoint` checks

`integration_test/bg_patrol_test.dart` uses [Patrol](https://patrol.leancode.co)
for the cases plain integration tests cannot drive: the app is sent to the
background and a job is started **by the OS** through the `nitrobg://run?text=…`
link (`NitroBgJobActivity` on Android, the scene delegate on iOS), then the app
is brought back and the card is checked against the persisted result.

```bash
dart pub global activate patrol_cli   # once
cd example
patrol test -t integration_test/bg_patrol_test.dart -d emulator-5554
patrol test -t integration_test/bg_patrol_test.dart -d "iPhone 17 Pro"
```

Native wiring lives in `example/android/app/build.gradle.kts` +
`androidTest/.../MainActivityTest.java` and `example/ios/RunnerUITests`
(a UI-testing bundle in the `Runner` scheme). Scenarios: in-app job, OS-started
while backgrounded / foregrounded, a burst of 5, a failing entry followed by a
good one, a slow job overlapping a fast one, a Dart-started job surviving
backgrounding — each ending with `activeNitroTypeCoverageBackgroundJobs() == 0`.

The **app-killed** path cannot be driven from Patrol (its Dart side runs inside
the app), so `scripts/bg_native_check.sh android|ios|all` force-stops /
terminates the app before every scenario, starts the jobs purely from the OS
(broadcast, VIEW intent, URL scheme), and reads what the entries persisted:
single job in a fresh process, burst of 5, fast + slow + failing together
(order, and the failure text reaching the native `onDone` callback and the
`Nitro` log tag). Manual one-liners for the same thing:

```bash
adb shell am broadcast -a nitro.BG_JOB \
  -n nitro.nitro_type_coverage_example/.NitroBgJobReceiver --es entry bgAppend --es text hello
xcrun simctl openurl booted "nitrobg://run?entry=bgAppend&text=hello"
```

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

## Linux in a container (colima / Docker)

`scripts/linux_container_test.sh` mirrors the CI Linux jobs in a Docker
container (Flutter pinned to the host version, arm64 or amd64): unit suites of
every nitro package, the benchmark's Linux build, then this plugin's full
integration suite on Linux desktop under xvfb. Sources are copied in, so host
`.dart_tool/` and `build/` stay untouched; `/work` and the pub cache persist in
named volumes between runs.

```sh
scripts/linux_container_test.sh          # everything
scripts/linux_container_test.sh '§80'    # one integration group
```

It found the direct-C++ struct-return double free (§71) that macOS, iOS and
Android never exercise, since those go through Swift and Kotlin.
