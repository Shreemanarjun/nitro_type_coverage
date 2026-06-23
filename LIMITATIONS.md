# Nitro Bridge — Known Limitations

This document catalogs every known limitation of the Nitro cross-platform bridge,
explains the root cause, shows what behaviour to expect on each platform, and gives
a concrete workaround or fix for each case.

---

## Table of Contents

1. [Sentinel Collisions — nullable primitives](#1-sentinel-collisions--nullable-primitives)
   - 1.1 [`int?` — Int64.min sentinel collision](#11-int--int64min-sentinel-collision)
   - 1.2 [`double?` — NaN sentinel collision](#12-double--nan-sentinel-collision)
   - 1.3 [`bool?` — FIXED in all platforms](#13-bool--fixed-in-all-platforms)
2. [Map Types](#2-map-types)
   - 2.1 [Only `Map<String, T>` is supported](#21-only-mapstring-t-is-supported)
   - 2.2 [`Map<String, @HybridRecord>` is not type-safe](#22-mapstring-hybridrecord-is-not-type-safe)
   - 2.3 [NaN and Infinity in `Map<String, double>`](#23-nan-and-infinity-in-mapstring-double)
   - 2.4 [Large integers in `Map<String, int>`](#24-large-integers-in-mapstring-int)
3. [Callbacks](#3-callbacks)
   - 3.1 [Struct params in callbacks (Android async)](#31-struct-params-in-callbacks-android-async)
4. [TypedData](#4-typeddata)
   - 4.1 [`Float32List` precision loss](#41-float32list-precision-loss)
5. [`@HybridStruct` with String fields](#5-hybridstruct-with-string-fields)
6. [Async ordering](#6-async-ordering)
7. [NitroNullable — collision-free fix](#7-nitronullable--collision-free-fix)
8. [Fixed limitations (history)](#8-fixed-limitations-history)

---

## 1. Sentinel Collisions — nullable primitives

Nitro bridges nullable primitives over a C ABI that only carries non-nullable values.
It uses a **sentinel value** to represent `null`:

| Type | Sentinel | JNI type |
|------|----------|----------|
| `int?` | `Int64.min` = `-9223372036854775808` | `jlong J` |
| `double?` | `NaN` | `jdouble D` |
| `bool?` | `-1` (via `Int` 3-state) | `jint I` |

When a real value happens to equal the sentinel, the bridge decodes it as `null`
instead — this is the **sentinel collision**.

### 1.1 `int?` — Int64.min sentinel collision

#### Root cause

The null sentinel for `int?` is `Long.MIN_VALUE` (`-9223372036854775808`). If a
caller passes that exact value as a non-null `int?`, the bridge decodes it as `null`.

#### Behaviour

```dart
tc.echoNullableInt(-9223372036854775808)  // → null  (sentinel collision)
tc.echoNullableInt(-1)                    // → -1    ✅ works (not the sentinel)
tc.echoNullableInt(null)                  // → null  ✅ works
```

#### Workaround — use `NitroNullableInt`

```dart
// In your spec:
NitroNullableInt safeCount();

// In Dart call site:
final result = module.safeCount();
final value = result.nullable;  // int? — null or the real value

// Any int64 including Int64.min works:
module.passCount(NitroNullableInt.fromNullable(-9223372036854775808));
// → impl receives the actual value, never confused with null
```

See [§7 NitroNullable](#7-nitronullable--collision-free-fix) for the full solution.

---

### 1.2 `double?` — NaN sentinel collision

#### Root cause

The null sentinel for `double?` is `double.nan`. Any NaN bit-pattern (including
signaling NaN) is decoded as `null`.

#### Behaviour

```dart
tc.echoNullableDouble(double.nan)       // → null  (sentinel collision)
tc.echoNullableDouble(double.infinity)  // → infinity ✅ works
tc.echoNullableDouble(null)             // → null  ✅ works
```

#### Workaround — use `NitroNullableDouble`

```dart
// In your spec:
NitroNullableDouble safeRatio();

// NaN is now a real value, not null:
final r = module.safeRatio();
if (r.hasValue && r.value.isNaN) {
  // real NaN, not null
}
```

---

### 1.3 `bool?` — FIXED in all platforms

**Previously a limitation. Now fixed.**

#### History

`jboolean` in JNI is a `uint8_t` (0 or 1). It cannot carry the value `-1` used
as the null sentinel. On Android, `bool? null` always arrived as `false`.

#### Fix applied

`bool?` now uses a 3-state `Int` (`jint I`):

| Value | Meaning |
|-------|---------|
| `-1`  | `null`  |
| `0`   | `false` |
| `1`   | `true`  |

```dart
tc.echoNullableBool(null)   // → null  ✅ all platforms
tc.echoNullableBool(true)   // → true  ✅ all platforms
tc.echoNullableBool(false)  // → false ✅ all platforms
```

No workaround needed — works correctly on iOS, Android, and macOS.

---

## 2. Map Types

Maps bridge as JSON strings (`const char*` / `Ljava/lang/String;`). This means
only JSON-serialisable values are supported.

### 2.1 Only `Map<String, T>` is supported

#### Root cause

The Nitro bridge encodes maps as JSON objects (`{"key": value}`). JSON object keys
are always strings — non-string keys have no representation.

#### Behaviour

```dart
// ✅ Supported
Map<String, int>    echoIntMap(Map<String, int> value);
Map<String, String> echoStringMap(Map<String, String> value);
Map<String, double> echoDoubleMap(Map<String, double> value);
Map<String, bool>   echoBoolMap(Map<String, bool> value);

// ❌ Not supported
Map<int, String>    notSupported(Map<int, String> value);
Map<TcStatus, int>  notSupported(Map<TcStatus, int> value);
```

#### Workaround

Convert to `Map<String, T>` before bridging:

```dart
final input = {TcStatus.ok: 1, TcStatus.error: 2};
final bridged = input.map((k, v) => MapEntry(k.name, v));
final result = module.echoStringMap(bridged);
```

---

### 2.2 `Map<String, @HybridRecord>` is not type-safe

#### Root cause

The Kotlin bridge uses `Any?` for map value types when the value is a
`@HybridRecord`. Type information is erased at the JNI boundary.

#### Behaviour

```dart
// The method compiles but the Kotlin interface is Any? → Any?
Future<Map<String, TcConfig>> echoConfigMap(Map<String, TcConfig> values);
// ⚠ values are not binary-encoded; JSON serialisation of TcConfig is undefined
```

#### Workaround — use `List<T>` instead

```dart
// ✅ Type-safe alternative:
Future<List<TcConfig>> echoConfigList(List<TcConfig> values);

// Or add a key field to the record and collect after:
final configs = await module.echoConfigList(input.values.toList());
final map = {for (final c in configs) c.name: c};
```

---

### 2.3 NaN and Infinity in `Map<String, double>`

#### Root cause

JSON does not represent `Infinity`, `-Infinity`, or `NaN`. Dart's `jsonEncode`
throws `JsonUnsupportedObjectError` for these values.

#### Behaviour

```dart
tc.echoDoubleMap({'pi': 3.14})          // ✅ works
tc.echoDoubleMap({'inf': double.infinity}) // ❌ throws JsonUnsupportedObjectError
tc.echoDoubleMap({'nan': double.nan})      // ❌ throws JsonUnsupportedObjectError
```

#### Workaround

Use a sentinel value or encode as a special string:

```dart
// Option A: use a sentinel (agreed contract with the native side)
final safe = values.map((k, v) => MapEntry(k, v.isFinite ? v : 0.0));

// Option B: use Map<String, NitroNullableDouble> (encodes as @HybridRecord — not yet supported)
// Option C: use a separate List<NitroNullableDouble> for non-finite values
```

---

### 2.4 Large integers in `Map<String, int>`

#### Root cause

JSON integers are parsed as JavaScript `Number` (IEEE 754 double) in many runtimes.
Values with more than 53 significant bits may lose precision when round-tripping
through `org.json.JSONObject` on Android.

#### Behaviour

```dart
tc.echoIntMap({'big': 9007199254740991})   // ✅ exact (2^53 - 1, max safe JS int)
tc.echoIntMap({'huge': 9007199254740992})  // ⚠ may lose precision on Android
```

#### Workaround

For large 64-bit integers in maps, use a `String` value and parse on both ends:

```dart
// Encode as string
final stringMap = bigIntMap.map((k, v) => MapEntry(k, v.toString()));
final encoded = tc.echoStringMap(stringMap);
final decoded = encoded.map((k, v) => MapEntry(k, int.parse(v!)));
```

---

## 3. Callbacks

### 3.1 Struct params in callbacks (Android async)

#### Root cause

`NativeCallable.listener` in Dart FFI fires synchronously **only for `Int64`
parameters**. Other C ABI types — including `Pointer<Void>` (struct pointer) — are
dispatched asynchronously on Android and may arrive on a different thread.

#### Behaviour

| Callback param type | iOS/macOS | Android |
|--------------------|-----------|---------|
| `int`, `bool`, `double` (via Int64 encoding) | sync ✅ | sync ✅ |
| `String` | sync ✅ | async ⚠ |
| `@HybridStruct T` (via `Pointer<Void>`) | sync ✅ | async ⚠ |
| `@HybridRecord T` | sync ✅ | async ⚠ |

```dart
// ✅ Always synchronous — Int64 fast-path:
void onIntEvent(void Function(int value) callback);
void onBoolEvent(void Function(bool value) boolCb);
void onDoubleEvent(void Function(double value) doubleCb);

// ⚠ May be asynchronous on Android:
void onPointEvent(void Function(TcPoint point) pointCb);
```

#### Workaround — use `Completer` + `Future.delayed`

```dart
// For struct callbacks on Android, add a small delay:
testWidgets('struct callback', (t) async {
  final completer = Completer<TcPoint>();
  tc.onPointEvent((p) {
    if (!completer.isCompleted) completer.complete(p);
  });

  // Give the async callback time to fire on Android:
  await Future.delayed(const Duration(milliseconds: 50));

  if (completer.isCompleted) {
    final p = await completer.future;
    expect(p.x, closeTo(1.0, 1e-9));
  }
  // OR use expectLater with a timeout for guaranteed async completion
});
```

#### Alternative — encode struct as primitives

For fully synchronous cross-platform callbacks, encode the struct fields as
individual `int`/`double` parameters:

```dart
// ✅ Always synchronous on all platforms:
void onPointEvent(void Function(double x, double y, double z) pointCb);

// Implementation (Swift):
func onPointEvent(pointCb: @escaping (Double, Double, Double) -> Void) {
    pointCb(point.x, point.y, point.z)
}
```

---

## 4. TypedData

### 4.1 `Float32List` precision loss

#### Root cause

Dart's `Float32List` stores each element as an IEEE 754 **32-bit float** (~7
significant decimal digits). Dart's `double` is 64-bit (~15 digits). When a `double`
is stored into a `Float32List`, the extra bits are discarded.

#### Behaviour

```dart
const highPrecision = 3.14159265358979323846; // 20 significant digits
final result = tc.echoFloats(Float32List.fromList([highPrecision]));

expect(result[0], closeTo(3.14159, 1e-5));   // ✅ ~7 digits preserved
expect(result[0], closeTo(highPrecision, 1e-12)); // ❌ fails — precision lost
```

#### Workaround — use `Float64List` / `echoFloat64s`

```dart
// ✅ Full 64-bit precision preserved:
final result = tc.echoFloat64s(Float64List.fromList([highPrecision]));
expect(result[0], closeTo(highPrecision, 1e-12)); // ✅
```

---

## 5. `@HybridStruct` with String fields

#### Root cause

`@HybridStruct` is a C-layout struct. Strings are `char*` pointers — each bridge
crossing performs a `strdup` (allocate + copy) for every string field on the way
in and a `free` on the way out. For structs with many or large string fields, this
adds measurable allocator pressure per call.

#### Behaviour

This is a **performance** limitation, not a correctness issue. The values are
always correct.

```dart
// Works correctly but allocates on every call:
tc.echoPoint(TcPoint(x: 1.0, y: 2.0, z: 3.0));  // ✅ no strings — zero extra alloc
```

If your struct has large `String` fields that cross the bridge frequently:

#### Workaround — use `@HybridRecord`

```dart
// ✅ @HybridRecord: binary-encoded once, zero-copy transport
@HybridRecord()
class TcConfig {
  final String name;    // encoded as length-prefixed bytes, not char*
  final int count;
  final bool enabled;
  final double threshold;
  TcConfig({required this.name, required this.count, required this.enabled, required this.threshold});
}
```

---

## 6. Async ordering

#### Root cause

`@nitroAsync` dispatches to a thread pool (Kotlin `_asyncExecutor`, Swift `Task`).
Multiple concurrent async calls may complete in a different order from submission.

#### Behaviour

```dart
final f1 = tc.asyncInt(1);
final f2 = tc.asyncInt(2);
final f3 = tc.asyncInt(3);

final results = await Future.wait([f1, f2, f3]);
// results == [1, 2, 3]  ✅ VALUES are always correct
// but f2 may have completed before f1 internally
```

For **stateless echo** functions this does not matter — you always get back exactly
what you sent. For **stateful** async operations (e.g., incrementing a counter on
the native side), the order is undefined.

#### Workaround — sequential awaits

```dart
// If order matters:
final r1 = await tc.asyncStatefulOp(1);
final r2 = await tc.asyncStatefulOp(2);
final r3 = await tc.asyncStatefulOp(3);
```

---

## 7. NitroNullable — collision-free fix

`package:nitro` ships three built-in types that **eliminate sentinel collisions
entirely** for nullable primitives. These types are part of the library — no spec
declaration needed.

### Wire format

```
NitroNullableInt:    [1B: hasValue (bool)][8B: value (int64_le)]  = 9 bytes
NitroNullableDouble: [1B: hasValue (bool)][8B: value (float64_le)]= 9 bytes
NitroNullableBool:   [1B: hasValue (bool)][1B: value (bool)]       = 2 bytes
```

Null is encoded as `hasValue = false`. The `value` field is irrelevant when null.
**No value is unreachable** — the entire domain is preserved.

### Usage

```dart
// In your spec (no declaration needed — imported from package:nitro):
NitroNullableInt  echoNullableIntSafe(NitroNullableInt value);
NitroNullableDouble echoNullableDoubleSafe(NitroNullableDouble value);
NitroNullableBool echoNullableBoolSafe(NitroNullableBool value);
```

```dart
// ── Dart call site ───────────────────────────────────────────────────────────

// Wrap with factory:
final arg = NitroNullableInt.fromNullable(-9223372036854775808); // Int64.min as real value ✅
final result = tc.echoNullableIntSafe(arg);
final dartValue = result.nullable;  // int? — correct value, never null

// Extension helper:
int? negOne = -1;
final wrapped = negOne.toNitroNullable();  // NitroNullableInt(hasValue: true, value: -1)

// NaN as a real double (not null):
double? nan = double.nan;
final wrappedNan = nan.toNitroNullable(); // NitroNullableDouble(hasValue: true, value: NaN)
final result2 = tc.echoNullableDoubleSafe(wrappedNan);
result2.nullable!.isNaN;  // true ✅ — NaN is preserved, not treated as null
```

```swift
// ── Swift implementation ─────────────────────────────────────────────────────
func echoNullableIntSafe(value: NitroNullableInt) -> NitroNullableInt { value }

// Or with conversion:
func getSomeCount() -> NitroNullableInt {
    let maybeCount: Int64? = computeCount()
    return NitroNullableInt(maybeCount)  // nil → hasValue=false
}
```

```kotlin
// ── Kotlin implementation ────────────────────────────────────────────────────
override fun echoNullableIntSafe(value: NitroNullableInt): NitroNullableInt = value

// Or with conversion:
fun getSomeCount(): NitroNullableInt {
    val maybeCount: Long? = computeCount()
    return NitroNullableInt(maybeCount)  // null → hasValue=false
}
```

### Comparison table

| Feature | `int?` (sentinel) | `NitroNullableInt` |
|---|---|---|
| Wire size | 8 bytes | 9 bytes (+1 byte) |
| Null representation | `Int64.min` sentinel | `hasValue = false` flag |
| Full int64 domain | ❌ Int64.min unreachable | ✅ all values |
| Platform consistency | ✅ | ✅ |
| Spec declaration needed | No | No (in `package:nitro`) |
| Ergonomic `.nullable` getter | — | ✅ |

---

## 8. Fixed limitations (history)

These were previously documented as limitations. All are now fixed.

| Limitation | Fix | Version |
|---|---|---|
| `bool?` null arrives as `false` on Android (jboolean cannot carry -1) | Changed to Int 3-state encoding (`-1/0/1` via `jint`) | This session |
| All negative `int?` values returned as `null` on Android (`< 0L` check) | Changed check to `== Long.MIN_VALUE` (exact sentinel only) | This session |
| `int?` property setter used old `-1` sentinel (missed `encodePropertyValue`) | Fixed `dart_ffi_return_helpers.dart` | This session |
| Nullable struct return throws `StateError` instead of returning `null` | Added `isNullable` check in `ReturnKind.struct` | This session |
| Map params encoded as `ByteArray` (binary record path, caused crash) | Added `isMap` guard before `isRecord` in `jni_method_emitter.dart` | This session |
| Map return double-free crash (`toDartStringWithFree` + `malloc.free`) | Changed to `toDartString()` (single ownership) | This session |
| `int?` sentinel was `-1` (all negatives = null on Android) | Changed to `Int64.min` | This session |

---

## Quick reference

```
LIMITATION           TYPE              PLATFORM       SEVERITY     FIX
─────────────────────────────────────────────────────────────────────────
Int64.min = null     int?              All            Minor        NitroNullableInt
NaN = null           double?           All            Minor        NitroNullableDouble
Map non-String keys  Map<K,T>          All            Design       Use Map<String,T>
Map<String,Record>   Map<String,T>     All            Design       Use List<T>
Map NaN/Infinity     Map<String,double>All            JSON limit   Avoid or encode
Map int > 2^53       Map<String,int>   Android        Minor        Use String values
Float32 precision    Float32List       All            Type limit   Use Float64List
Struct in callback   @HybridStruct     Android        Async        Use primitive params
@HybridStruct str    String fields     All            Perf only    Use @HybridRecord
@nitroAsync order    async methods     All            Design       Sequential await
```
