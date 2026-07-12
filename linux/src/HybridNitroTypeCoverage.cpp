// HybridNitroTypeCoverage — NativeImpl.cpp implementation (Windows/Linux).
//
// Complete echo implementation mirroring android/.../NitroTypeCoverageImpl.kt
// and ios/.../NitroTypeCoverageImpl.swift — every method returns exactly what
// it receives (or a deterministically-derived value), so the same Dart
// integration tests that pass on Android/iOS/macOS can run here too.
//
// Wire-format notes (reverse-engineered from the generated Dart FFI file,
// lib/src/nitro_type_coverage.g.dart, which is the authoritative source of
// truth — see RecordWriter/RecordReader in packages/nitro/lib/src/record_codec.dart):
//   * @HybridRecord / @HybridStruct params/returns: NitroCppBuffer, decoded via
//     T::fromNative(buf) and encoded via T().toNativeBuffer() (both generated
//     into nitro_type_coverage.native.g.h — no manual byte-fiddling needed).
//   * List<primitive> (int/double/bool/String): PARAM uses the *indexed*
//     [4B count][8B*count offsets][items...] layout (RecordWriter.encodeIndexedList
//     on the Dart side); RETURN uses the *simple* [4B count][items...] layout
//     (RecordReader.decodeList / no offset table) — this is a real asymmetry,
//     confirmed directly from the generated Dart source, not assumed.
//   * List<@HybridRecord> / List<@HybridStruct> (TcConfig, TcPoint): PARAM and
//     RETURN both use the *indexed* layout (LazyRecordList on the Dart side).
//   * List<@HybridEnum> / List<@NitroVariant> (TcStatus, TcEvent): PARAM and
//     RETURN both use the *simple* layout (no offset table either direction).
//   * Map<String, V>: symmetric wire format for both directions —
//     [4B payloadLen][4B count]{[4B keyLen][key][1B tag][value]}*, tag is
//     1=int64, 2=float64, 3=bool, 4=string, 5=record/variant (nested
//     [4B len][payload] blob). The tag byte is written but never
//     interpreted on decode (the Dart side just skips it) — same here.
//   * NitroAnyMap: opaque to native — same self-describing [4B len][payload]
//     convention as records. Echoed by copying the raw bytes through
//     unchanged (no need to interpret internal AnyValue tags for an echo).
//   * @nitroNativeAsync methods own their own result encoding + posting via
//     Dart_PostCObject_DL — see doc/advanced/async.md's "Native implementation
//     pattern" section. _nitro_err is unused here (no method in this module
//     has a native-async error path to exercise); on error you'd populate
//     hasError/name/message (strdup'd) before posting.
//
// Streams: emit_<name>(...) helpers are non-virtual and provided by the base
// class (declared in nitro_type_coverage.native.g.h) — call them from a
// detached std::thread to push items asynchronously, mirroring the Kotlin
// impl's `CoroutineScope(Dispatchers.Default).launch { ... }` pattern.

#include "../../lib/src/generated/cpp/nitro_type_coverage.native.g.h"
#include "dart_api_dl.h"

#include <atomic>
#include <cstdlib>
#include <cstring>
#include <functional>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

// ── Generic list codecs ─────────────────────────────────────────────────────
// See the file-header comment above for which lists use which layout.

// Decodes an incoming list PARAM. `indexed` selects whether to skip the
// offset table (indexed layout: primitives, records, structs) or not
// (simple layout: enums, variants) — either way items are laid out
// consecutively afterward, so a plain sequential read works for both; we
// never need random access here.
template <typename T>
static std::vector<T> nitro_decode_list_param(NitroCppBuffer buf, bool indexed, T (*readItem)(NitroRecordReader&)) {
    NitroRecordReader r(buf);
    int32_t count = r.readInt32();
    if (indexed) { r._offset += 8 * (size_t)count; }
    std::vector<T> result;
    result.reserve((size_t)count);
    for (int32_t i = 0; i < count; i++) result.push_back(readItem(r));
    return result;
}

// Encodes a list RETURN using the simple [4B count][items...] layout (used
// for primitive/enum/variant item lists).
template <typename T>
static NitroCppBuffer nitro_encode_simple_list(const std::vector<T>& items, void (*writeItem)(NitroRecordWriter&, const T&)) {
    NitroRecordWriter w;
    w.writeInt32((int32_t)items.size());
    for (const auto& e : items) writeItem(w, e);
    return w.toNativeBuffer();
}

// Encodes a list RETURN using the indexed [4B count][offsets...][items...]
// layout (used for record/struct item lists, matching LazyRecordList).
template <typename T>
static NitroCppBuffer nitro_encode_indexed_list(const std::vector<T>& items, void (*writeItem)(NitroRecordWriter&, const T&)) {
    std::vector<std::vector<uint8_t>> blobs;
    blobs.reserve(items.size());
    for (const auto& e : items) {
        NitroRecordWriter w;
        writeItem(w, e);
        blobs.push_back(std::move(w._buf));
    }
    NitroRecordWriter out;
    out.writeInt32((int32_t)items.size());
    int64_t pos = 4 + 8 * (int64_t)items.size();
    for (const auto& b : blobs) { out.writeInt(pos); pos += (int64_t)b.size(); }
    for (const auto& b : blobs) { out.writeBytes(b.data(), b.size()); }
    return out.toNativeBuffer();
}

// Reader-based TcEvent decode (mirrors nitro_decode_TcEvent's switch body,
// but reads from an existing NitroRecordReader instead of constructing one
// from a full buffer — needed for reading TcEvent items out of a list).
static TcEvent nitro_decode_TcEvent_fromReader(NitroRecordReader& _r) {
    int8_t tag = _r.readInt8();
    switch (tag) {
    case 0: {
        TcEventTap _c{};
        _c.x = _r.readInt();
        _c.y = _r.readInt();
        return _c;
    }
    case 1: {
        TcEventScroll _c{};
        _c.delta = _r.readDouble();
        return _c;
    }
    case 2: {
        TcEventResize _c{};
        _c.width = _r.readInt();
        _c.height = _r.readInt();
        return _c;
    }
    case 3: {
        TcEventNullable _c{};
        if (_r.readBool()) { _c.count = _r.readInt(); }
        if (_r.readBool()) { _c.status = nitro_TcStatus_fromIndex(_r.readInt()); }
        if (_r.readBool()) { _c.config = TcConfig::fromReader(_r); }
        if (_r.readBool()) { int32_t _n = _r.readInt32(); auto& _vec = _c.samples.emplace(); _vec.reserve((size_t)_n); for (int32_t _i = 0; _i < _n; _i++) _vec.push_back(_r.readInt()); }
        return _c;
    }
    default: throw std::runtime_error("TcEvent: unknown tag");
    }
}

// ── Generic Map<String, V> codec ────────────────────────────────────────────
// Symmetric wire format for both directions — see the file-header comment.

template <typename V>
static std::vector<std::pair<std::string, V>> nitro_decode_map_param(NitroCppBuffer buf, V (*readVal)(NitroRecordReader&)) {
    NitroRecordReader r(buf);
    int32_t count = r.readInt32();
    std::vector<std::pair<std::string, V>> result;
    result.reserve((size_t)count);
    for (int32_t i = 0; i < count; i++) {
        std::string key = r.readString();
        r.readInt8(); // skip type tag — value type is already known from context
        result.emplace_back(std::move(key), readVal(r));
    }
    return result;
}

template <typename V>
static NitroCppBuffer nitro_encode_map(const std::vector<std::pair<std::string, V>>& entries, int8_t tag, void (*writeVal)(NitroRecordWriter&, const V&)) {
    NitroRecordWriter w;
    w.writeInt32((int32_t)entries.size());
    for (const auto& e : entries) {
        w.writeString(e.first);
        w.writeInt8(tag);
        writeVal(w, e.second);
    }
    return w.toNativeBuffer();
}

// ── Native-async post helpers ───────────────────────────────────────────────
// Every @nitroNativeAsync method owns its own result encoding + posting; see
// the file-header comment. These small helpers cover the primitive/record
// wire shapes so each method body stays a one-liner.

static void nitro_post_null(int64_t dartPort) {
    Dart_CObject obj;
    obj.type = Dart_CObject_kNull;
    Dart_PostCObject_DL(dartPort, &obj);
}
static void nitro_post_int64(int64_t dartPort, int64_t v) {
    Dart_CObject obj;
    obj.type = Dart_CObject_kInt64;
    obj.value.as_int64 = v;
    Dart_PostCObject_DL(dartPort, &obj);
}
static void nitro_post_double(int64_t dartPort, double v) {
    Dart_CObject obj;
    obj.type = Dart_CObject_kDouble;
    obj.value.as_double = v;
    Dart_PostCObject_DL(dartPort, &obj);
}
static void nitro_post_bool(int64_t dartPort, bool v) {
    Dart_CObject obj;
    obj.type = Dart_CObject_kBool;
    obj.value.as_bool = v;
    Dart_PostCObject_DL(dartPort, &obj);
}
static void nitro_post_string(int64_t dartPort, const std::string& v) {
    Dart_CObject obj;
    obj.type = Dart_CObject_kString;
    obj.value.as_string = const_cast<char*>(v.c_str());
    Dart_PostCObject_DL(dartPort, &obj);
}
// Posts a malloc'd self-describing [4B len][payload] buffer's address as
// kInt64 — used for record/variant/AnyMap native-async returns. A nullptr
// buffer posts address 0 (not kNull), matching every other pointer-backed
// native-async return in this codebase.
static void nitro_post_buffer(int64_t dartPort, NitroCppBuffer buf) {
    nitro_post_int64(dartPort, buf.data == nullptr ? 0 : reinterpret_cast<int64_t>(buf.data));
}
// Posts a malloc'd copy of a plain-old-data struct (TcPoint) — address as
// kInt64, matching the sync-return struct convention.
template <typename T>
static void nitro_post_struct_copy(int64_t dartPort, const T& value) {
    T* copy = (T*)malloc(sizeof(T));
    *copy = value;
    nitro_post_int64(dartPort, reinterpret_cast<int64_t>(copy));
}
// Nullable-primitive pointer post (NitroOptInt64/Float64/Bool convention:
// [1B hasValue][value bytes]) — matches the sync/@nitroAsync desktop path.
static void nitro_post_opt_int64(int64_t dartPort, std::optional<int64_t> v) {
    uint8_t* buf = (uint8_t*)malloc(9);
    buf[0] = v.has_value() ? 1 : 0;
    if (v.has_value()) { int64_t x = *v; memcpy(buf + 1, &x, 8); }
    nitro_post_int64(dartPort, reinterpret_cast<int64_t>(buf));
}
static void nitro_post_opt_double(int64_t dartPort, std::optional<double> v) {
    uint8_t* buf = (uint8_t*)malloc(9);
    buf[0] = v.has_value() ? 1 : 0;
    if (v.has_value()) { double x = *v; memcpy(buf + 1, &x, 8); }
    nitro_post_int64(dartPort, reinterpret_cast<int64_t>(buf));
}
static void nitro_post_opt_bool(int64_t dartPort, std::optional<bool> v) {
    uint8_t* buf = (uint8_t*)malloc(2);
    buf[0] = v.has_value() ? 1 : 0;
    buf[1] = (v.has_value() && *v) ? 1 : 0;
    nitro_post_int64(dartPort, reinterpret_cast<int64_t>(buf));
}
// Runs `fn` on a detached background thread — every native-async method in
// this impl completes this way (matches Kotlin's `_asyncExecutor.execute {}` /
// Swift's `Task.detached {}`; the framework accepts a post from any thread).
static void nitro_run_detached(std::function<void()> fn) {
    std::thread(std::move(fn)).detach();
}

// ── Implementation ───────────────────────────────────────────────────────────

class HybridNitroTypeCoverageImpl final : public HybridNitroTypeCoverage {
public:
    HybridNitroTypeCoverageImpl() = default;
    ~HybridNitroTypeCoverageImpl() override = default;

    // ── Primitives ───────────────────────────────────────────────────────────
    int64_t echoInt(int64_t value) override { return value; }
    double echoDouble(double value) override { return value; }
    bool echoBool(bool value) override { return value; }
    std::string echoString(const std::string& value) override { return value; }

    // ── Multi-param ──────────────────────────────────────────────────────────
    int64_t addInts(int64_t a, int64_t b, int64_t c) override { return a + b + c; }
    double mulDoubles(double a, double b) override { return a * b; }
    std::string joinStrings(const std::string& a, const std::string& b, const std::string& separator) override { return a + separator + b; }

    // ── DateTime ─────────────────────────────────────────────────────────────
    int64_t echoDateTime(int64_t value) override { return value; }
    std::optional<int64_t> echoNullableDateTime(std::optional<int64_t> value) override { return value; }

    // ── Nullable primitives ──────────────────────────────────────────────────
    std::optional<int64_t> echoNullableInt(std::optional<int64_t> value) override { return value; }
    std::optional<double> echoNullableDouble(std::optional<double> value) override { return value; }
    std::optional<bool> echoNullableBool(std::optional<bool> value) override { return value; }
    std::optional<std::string> echoNullableString(const std::optional<std::string>& value) override { return value; }

    // ── Enum ─────────────────────────────────────────────────────────────────
    TcStatus echoStatus(TcStatus value) override { return value; }
    std::optional<TcStatus> echoNullableStatus(std::optional<TcStatus> value) override { return value; }

    // ── Struct ───────────────────────────────────────────────────────────────
    TcPoint echoPoint(const TcPoint& value) override { return value; }

    // ── @HybridRecord ────────────────────────────────────────────────────────
    NitroCppBuffer echoConfig(NitroCppBuffer value) override { return TcConfig::fromNative(value).toNativeBuffer(); }

    // ── TypedData (zero-copy) ────────────────────────────────────────────────
    // The base pointer is malloc'd and owned by Dart after return (matches the
    // sync @zeroCopy TypedData return convention — Dart frees via the
    // generated _release_typed_data_return helper).
    NitroCppBuffer echoBytes(const uint8_t* value, size_t value_length) override {
        uint8_t* copy = (uint8_t*)malloc(value_length);
        if (value_length > 0) memcpy(copy, value, value_length);
        return NitroCppBuffer{ copy, value_length };
    }
    NitroCppBuffer echoFloats(const float* value, size_t value_length) override {
        // NitroCppBuffer.size is in BYTES, not elements — Dart computes the
        // element count as size / sizeof(float). Returning value_length here
        // silently truncated the list (10k floats -> 2500; 3 -> 0).
        size_t bytes = value_length * sizeof(float);
        uint8_t* copy = (uint8_t*)malloc(bytes);
        if (bytes > 0) memcpy(copy, value, bytes);
        return NitroCppBuffer{ copy, bytes };
    }
    NitroCppBuffer echoFloat64s(const double* value, size_t value_length) override {
        // NitroCppBuffer.size is in BYTES, not elements — Dart computes the
        // element count as size / sizeof(double). Returning value_length here
        // silently truncated the list (10k floats -> 2500; 3 -> 0).
        size_t bytes = value_length * sizeof(double);
        uint8_t* copy = (uint8_t*)malloc(bytes);
        if (bytes > 0) memcpy(copy, value, bytes);
        return NitroCppBuffer{ copy, bytes };
    }
    NitroCppBuffer echoInt32s(const int32_t* value, size_t value_length) override {
        // NitroCppBuffer.size is in BYTES, not elements — Dart computes the
        // element count as size / sizeof(int32_t). Returning value_length here
        // silently truncated the list (10k floats -> 2500; 3 -> 0).
        size_t bytes = value_length * sizeof(int32_t);
        uint8_t* copy = (uint8_t*)malloc(bytes);
        if (bytes > 0) memcpy(copy, value, bytes);
        return NitroCppBuffer{ copy, bytes };
    }
    NitroCppBuffer echoInt8s(const int8_t* value, size_t value_length) override {
        uint8_t* copy = (uint8_t*)malloc(value_length);
        if (value_length > 0) memcpy(copy, value, value_length);
        return NitroCppBuffer{ copy, value_length };
    }
    NitroCppBuffer echoInt16s(const int16_t* value, size_t value_length) override {
        // NitroCppBuffer.size is in BYTES, not elements — Dart computes the
        // element count as size / sizeof(int16_t). Returning value_length here
        // silently truncated the list (10k floats -> 2500; 3 -> 0).
        size_t bytes = value_length * sizeof(int16_t);
        uint8_t* copy = (uint8_t*)malloc(bytes);
        if (bytes > 0) memcpy(copy, value, bytes);
        return NitroCppBuffer{ copy, bytes };
    }
    NitroCppBuffer echoInt64s(const int64_t* value, size_t value_length) override {
        // NitroCppBuffer.size is in BYTES, not elements — Dart computes the
        // element count as size / sizeof(int64_t). Returning value_length here
        // silently truncated the list (10k floats -> 2500; 3 -> 0).
        size_t bytes = value_length * sizeof(int64_t);
        uint8_t* copy = (uint8_t*)malloc(bytes);
        if (bytes > 0) memcpy(copy, value, bytes);
        return NitroCppBuffer{ copy, bytes };
    }

    // ── Lists (async) ────────────────────────────────────────────────────────
    NitroCppBuffer echoIntList(NitroCppBuffer value) override {
        auto items = nitro_decode_list_param<int64_t>(value, true, [](NitroRecordReader& r) -> int64_t { return r.readInt(); });
        return nitro_encode_simple_list<int64_t>(items, [](NitroRecordWriter& w, const int64_t& e) { w.writeInt(e); });
    }
    NitroCppBuffer echoDoubleList(NitroCppBuffer value) override {
        auto items = nitro_decode_list_param<double>(value, true, [](NitroRecordReader& r) -> double { return r.readDouble(); });
        return nitro_encode_simple_list<double>(items, [](NitroRecordWriter& w, const double& e) { w.writeDouble(e); });
    }
    NitroCppBuffer echoStringList(NitroCppBuffer value) override {
        auto items = nitro_decode_list_param<std::string>(value, true, [](NitroRecordReader& r) -> std::string { return r.readString(); });
        return nitro_encode_simple_list<std::string>(items, [](NitroRecordWriter& w, const std::string& e) { w.writeString(e); });
    }
    NitroCppBuffer echoConfigList(NitroCppBuffer values) override {
        auto items = nitro_decode_list_param<TcConfig>(values, true, &TcConfig::fromReader);
        return nitro_encode_indexed_list<TcConfig>(items, [](NitroRecordWriter& w, const TcConfig& e) { e.encodeInto(w); });
    }

    // ── Async ────────────────────────────────────────────────────────────────
    int64_t asyncInt(int64_t value) override { return value; }
    double asyncDouble(double value) override { return value; }
    bool asyncBool(bool value) override { return value; }
    std::string asyncString(const std::string& value) override { return value; }
    NitroCppBuffer asyncConfig(NitroCppBuffer value) override { return TcConfig::fromNative(value).toNativeBuffer(); }

    // ── Async nullable ───────────────────────────────────────────────────────
    std::optional<int64_t> asyncNullableInt(std::optional<int64_t> value) override { return value; }
    std::optional<double> asyncNullableDouble(std::optional<double> value) override { return value; }
    std::optional<bool> asyncNullableBool(std::optional<bool> value) override { return value; }
    std::optional<std::string> asyncNullableString(const std::optional<std::string>& value) override { return value.has_value() ? value : std::make_optional(std::string()); }

    // ── Async additions ──────────────────────────────────────────────────────
    TcPoint asyncPoint(const TcPoint& value) override { return value; }
    std::optional<TcStatus> asyncNullableStatus(std::optional<TcStatus> value) override { return value; }
    NitroCppBuffer asyncMeta(NitroCppBuffer value) override { return TcMeta::fromNative(value).toNativeBuffer(); }

    // ── @HybridRecord (TcMeta) ───────────────────────────────────────────────
    NitroCppBuffer echoMeta(NitroCppBuffer value) override { return TcMeta::fromNative(value).toNativeBuffer(); }

    // ── @HybridRecord with TypedData fields ──────────────────────────────────
    NitroCppBuffer echoDataRecord(NitroCppBuffer value) override { return TcDataRecord::fromNative(value).toNativeBuffer(); }

    // ── §30: 6 new type coverage features ────────────────────────────────────

    // #1 Stream<TcConfig>
    void configureConfigStream(NitroCppBuffer seed, int64_t count) override {
        TcConfig s = TcConfig::fromNative(seed);
        nitro_run_detached([this, s, count]() {
            for (int64_t i = 0; i < count; i++) {
                TcConfig item;
                item.name = s.name + "-" + std::to_string(i);
                item.count = s.count + i;
                item.enabled = s.enabled;
                item.threshold = s.threshold + (double)i * 0.1;
                emit_configStream(item.toNativeBuffer());
            }
        });
    }

    // #2 Nullable @HybridRecord
    NitroCppBuffer echoNullableConfig(NitroCppBuffer value) override {
        if (value.data == nullptr) return NitroCppBuffer{ nullptr, 0 };
        return TcConfig::fromNative(value).toNativeBuffer();
    }

    // #3 Nested @HybridRecord
    NitroCppBuffer echoNested(NitroCppBuffer value) override { return TcNested::fromNative(value).toNativeBuffer(); }

    // #4 List<TcConfig> sync param
    NitroCppBuffer echoConfigListSync(NitroCppBuffer values) override {
        auto items = nitro_decode_list_param<TcConfig>(values, true, &TcConfig::fromReader);
        return nitro_encode_indexed_list<TcConfig>(items, [](NitroRecordWriter& w, const TcConfig& e) { e.encodeInto(w); });
    }

    // #5 NitroNullable inside @HybridRecord
    NitroCppBuffer echoNullableWrapper(NitroCppBuffer value) override { return TcNullableWrapper::fromNative(value).toNativeBuffer(); }

    // #6 Bidirectional callback
    void onTransformEvent(std::function<int64_t(int64_t)> transformCb) override {
        transformCb(42);
    }

    // ── NitroNullable built-in types ─────────────────────────────────────────
    NitroCppBuffer echoNullableIntSafe(NitroCppBuffer value) override { return NitroNullableInt::fromNative(value).toNativeBuffer(); }
    NitroCppBuffer echoNullableDoubleSafe(NitroCppBuffer value) override { return NitroNullableDouble::fromNative(value).toNativeBuffer(); }
    NitroCppBuffer echoNullableBoolSafe(NitroCppBuffer value) override { return NitroNullableBool::fromNative(value).toNativeBuffer(); }

    // ── Maps ─────────────────────────────────────────────────────────────────
    NitroCppBuffer echoIntMap(NitroCppBuffer value) override {
        auto entries = nitro_decode_map_param<int64_t>(value, [](NitroRecordReader& r) -> int64_t { return r.readInt(); });
        return nitro_encode_map<int64_t>(entries, 1, [](NitroRecordWriter& w, const int64_t& v) { w.writeInt(v); });
    }
    NitroCppBuffer echoStringMap(NitroCppBuffer value) override {
        auto entries = nitro_decode_map_param<std::string>(value, [](NitroRecordReader& r) -> std::string { return r.readString(); });
        return nitro_encode_map<std::string>(entries, 4, [](NitroRecordWriter& w, const std::string& v) { w.writeString(v); });
    }
    NitroCppBuffer echoDoubleMap(NitroCppBuffer value) override {
        auto entries = nitro_decode_map_param<double>(value, [](NitroRecordReader& r) -> double { return r.readDouble(); });
        return nitro_encode_map<double>(entries, 2, [](NitroRecordWriter& w, const double& v) { w.writeDouble(v); });
    }
    NitroCppBuffer echoBoolMap(NitroCppBuffer value) override {
        auto entries = nitro_decode_map_param<bool>(value, [](NitroRecordReader& r) -> bool { return r.readBool(); });
        return nitro_encode_map<bool>(entries, 3, [](NitroRecordWriter& w, const bool& v) { w.writeBool(v); });
    }
    NitroCppBuffer echoConfigMap(NitroCppBuffer value) override {
        auto entries = nitro_decode_map_param<TcConfig>(value, [](NitroRecordReader& r) -> TcConfig {
            // Wire per value: [4B blobLen][4B recordLen][fields] — the Dart
            // encoder writes an outer blob length AND the record's own
            // self-describing prefix. Both must be consumed before the
            // fields; skipping only one made fromReader read the inner
            // prefix as the first field (buffer underflow on decode).
            r.readInt32(); // outer blob length (recordLen + 4)
            r.readInt32(); // record's own [4B len] prefix
            return TcConfig::fromReader(r);
        });
        return nitro_encode_map<TcConfig>(entries, 5, [](NitroRecordWriter& w, const TcConfig& v) {
            // Mirror of the decode above: [4B blobLen][4B recordLen][fields].
            // Dart's map decoder slices blobLen bytes and hands them to
            // fromNative, which reads the record's own prefix first.
            NitroRecordWriter inner;
            v.encodeInto(inner);
            w.writeInt32((int32_t)inner._buf.size() + 4); // outer blob length
            w.writeInt32((int32_t)inner._buf.size());     // record's own prefix
            w.writeBytes(inner._buf.data(), inner._buf.size());
        });
    }
    NitroCppBuffer echoEventMap(NitroCppBuffer value) override {
        auto entries = nitro_decode_map_param<TcEvent>(value, [](NitroRecordReader& r) -> TcEvent {
            // Same double-prefix wire as the record map above.
            r.readInt32(); // outer blob length (variantLen + 4)
            r.readInt32(); // variant's own [4B len] prefix
            return nitro_decode_TcEvent_fromReader(r);
        });
        return nitro_encode_map<TcEvent>(entries, 5, [](NitroRecordWriter& w, const TcEvent& v) {
            // Mirror of the decode above: [4B blobLen][4B variantLen][tag+fields].
            NitroRecordWriter inner;
            nitro_encode_TcEvent(v, inner);
            w.writeInt32((int32_t)inner._buf.size() + 4); // outer blob length
            w.writeInt32((int32_t)inner._buf.size());     // variant's own prefix
            w.writeBytes(inner._buf.data(), inner._buf.size());
        });
    }

    // ── @HybridRecord with enum field ────────────────────────────────────────
    NitroCppBuffer echoPacket(NitroCppBuffer value) override { return TcPacket::fromNative(value).toNativeBuffer(); }

    // ── Nullable struct ──────────────────────────────────────────────────────
    std::optional<TcPoint> echoNullablePoint(const std::optional<TcPoint>& value) override { return value; }

    // ── @HybridStruct in @HybridRecord ───────────────────────────────────────
    NitroCppBuffer echoStructHolder(NitroCppBuffer value) override { return TcStructHolder::fromNative(value).toNativeBuffer(); }

    // ── Bidirectional callbacks with non-int returns ─────────────────────────
    void onStringTransform(std::function<std::string(int64_t)> stringCb) override { stringCb(42); }
    void onDoubleTransform(std::function<double(int64_t)> doubleCb) override { doubleCb(7); }

    // ── Batch streams ────────────────────────────────────────────────────────
    void configureBatchStream(int64_t from, int64_t count) override {
        nitro_run_detached([this, from, count]() {
            for (int64_t i = 0; i < count; i++) emit_batchIntStream(from + i);
        });
    }
    void configureBatchDoubleStream(NitroCppBuffer values) override {
        auto items = nitro_decode_list_param<double>(values, true, [](NitroRecordReader& r) -> double { return r.readDouble(); });
        nitro_run_detached([this, items]() {
            for (double v : items) emit_batchDoubleStream(v);
        });
    }
    void configureBatchBoolStream(NitroCppBuffer values) override {
        auto items = nitro_decode_list_param<bool>(values, true, [](NitroRecordReader& r) -> bool { return r.readBool(); });
        nitro_run_detached([this, items]() {
            for (bool v : items) emit_batchBoolStream(v);
        });
    }

    // ── Bool/enum bidirectional callbacks ────────────────────────────────────
    void onBoolTransform(std::function<bool(int64_t)> boolCb) override { boolCb(42); }
    void onStatusTransform(std::function<TcStatus(int64_t)> statusCb) override { statusCb(42); }

    // ── List<bool> and List<TcPoint> ─────────────────────────────────────────
    NitroCppBuffer echoListBool(NitroCppBuffer value) override {
        auto items = nitro_decode_list_param<bool>(value, true, [](NitroRecordReader& r) -> bool { return r.readBool(); });
        return nitro_encode_simple_list<bool>(items, [](NitroRecordWriter& w, const bool& e) { w.writeBool(e); });
    }
    NitroCppBuffer echoPointList(NitroCppBuffer values) override {
        auto items = nitro_decode_list_param<TcPoint>(values, true, &nitro_TcPoint_fromReader);
        return nitro_encode_indexed_list<TcPoint>(items, [](NitroRecordWriter& w, const TcPoint& e) { nitro_TcPoint_encodeInto(e, w); });
    }

    // ── @NitroNativeAsync with typed returns ─────────────────────────────────
    void nativeAsyncInt(int64_t value, NitroError*, int64_t dartPort) override {
        nitro_run_detached([value, dartPort]() { nitro_post_int64(dartPort, value); });
    }
    void nativeAsyncDouble(double value, NitroError*, int64_t dartPort) override {
        nitro_run_detached([value, dartPort]() { nitro_post_double(dartPort, value); });
    }
    void nativeAsyncBool(bool value, NitroError*, int64_t dartPort) override {
        nitro_run_detached([value, dartPort]() { nitro_post_bool(dartPort, value); });
    }
    void nativeAsyncString(const std::string& value, NitroError*, int64_t dartPort) override {
        nitro_run_detached([value, dartPort]() { nitro_post_string(dartPort, value); });
    }

    // ── Stream<String> ───────────────────────────────────────────────────────
    void configureStringStream(NitroCppBuffer values) override {
        auto items = nitro_decode_list_param<std::string>(values, true, [](NitroRecordReader& r) -> std::string { return r.readString(); });
        nitro_run_detached([this, items]() {
            for (const auto& v : items) emit_stringStream(v);
        });
    }

    // ── Batch Stream<String> ─────────────────────────────────────────────────
    void configureBatchStringStream(NitroCppBuffer values) override {
        auto items = nitro_decode_list_param<std::string>(values, true, [](NitroRecordReader& r) -> std::string { return r.readString(); });
        nitro_run_detached([this, items]() {
            for (const auto& v : items) emit_batchStringStream(v);
        });
    }

    // ── Backpressure.block stream ────────────────────────────────────────────
    void configureBlockIntStream(int64_t from, int64_t count) override {
        nitro_run_detached([this, from, count]() {
            for (int64_t i = 0; i < count; i++) emit_blockIntStream(from + i);
        });
    }

    // ── Callbacks with struct and multi-params ───────────────────────────────
    void onPointEvent(std::function<void(const TcPoint&)> pointCb) override {
        TcPoint p{}; p.x = 1.0; p.y = 2.0; p.z = 3.0;
        pointCb(p);
    }
    void onDetailEvent(std::function<void(int64_t, double)> detailCb) override { detailCb(42, 9.81); }

    // ── Callback ─────────────────────────────────────────────────────────────
    void onIntEvent(std::function<void(int64_t)> callback) override { callback(42); }
    void onBoolEvent(std::function<void(bool)> boolCb) override { boolCb(true); }
    void onDoubleEvent(std::function<void(double)> doubleCb) override { doubleCb(2.71828); }

    // ── Stream control ───────────────────────────────────────────────────────
    void configureStream(int64_t from, int64_t count) override {
        nitro_run_detached([this, from, count]() {
            for (int64_t i = 0; i < count; i++) {
                int64_t v = from + i;
                emit_intStream(v);
                TcPoint p{}; p.x = (double)v; p.y = (double)v * 0.5; p.z = 0.0;
                emit_pointStream(p);
                emit_boolStream(v % 2 == 0);
            }
        });
    }
    void configureDoubleStream(double start, int64_t count) override {
        nitro_run_detached([this, start, count]() {
            for (int64_t i = 0; i < count; i++) emit_doubleStream(start + (double)i);
        });
    }
    void configureStatusStream(int64_t count) override {
        static const TcStatus statuses[3] = { TCSTATUS_OK, TCSTATUS_ERROR, TCSTATUS_PENDING };
        nitro_run_detached([this, count]() {
            for (int64_t i = 0; i < count; i++) emit_statusStream(statuses[i % 3]);
        });
    }

    // ── Error handling ───────────────────────────────────────────────────────
    void throwNative(const std::string& message) override { throw std::runtime_error(message); }

    void throwNativeAsync(const std::string& message) override { throw std::runtime_error(message); }

    void throwNativeNativeAsync(const std::string& message, NitroError* _nitro_err, int64_t dartPort) override {
        nitro_run_detached([message, _nitro_err, dartPort]() {
            if (_nitro_err) {
                _nitro_err->hasError = 1;
                _nitro_err->name = strdup("RuntimeException");
                _nitro_err->message = strdup(message.c_str());
            }
            nitro_post_null(dartPort);
        });
    }

    // ── §70: desktop C-bridge fixes (GitHub #9) ──────────────────────────────
    NitroCppBuffer getConfigOrFail(bool shouldFail) override {
        if (shouldFail) throw std::runtime_error("getConfigOrFail: shouldFail was true");
        TcConfig cfg;
        cfg.name = "desktop-fix";
        cfg.count = 9;
        cfg.enabled = true;
        cfg.threshold = 1.5;
        return cfg.toNativeBuffer();
    }

    void nativeAsyncEchoOptionalConfig(NitroCppBuffer config, NitroError*, int64_t dartPort) override {
        // config.data == nullptr means the Dart caller omitted the optional
        // param — see GitHub #9 bug 2 (the desktop dispatch now null-guards
        // this before it ever reaches here).
        bool isNull = (config.data == nullptr);
        std::vector<uint8_t> payloadCopy;
        if (!isNull) {
            payloadCopy.assign(config.data, config.data + config.size);
        }
        nitro_run_detached([isNull, payloadCopy, dartPort]() {
            if (isNull) { nitro_post_int64(dartPort, 0); return; }
            TcConfig cfg = TcConfig::fromNative(NitroCppBuffer{ payloadCopy.data(), payloadCopy.size() });
            nitro_post_buffer(dartPort, cfg.toNativeBuffer());
        });
    }

    // ── @NitroOwned ──────────────────────────────────────────────────────────
    void* acquireBuffer(int64_t size) override { return malloc((size_t)size); }

    // ── @NitroVariant ────────────────────────────────────────────────────────
    NitroCppBuffer echoEvent(NitroCppBuffer event) override {
        TcEvent e = nitro_decode_TcEvent(event);
        return nitro_TcEvent_to_native(e);
    }

    // ── @NitroResult ─────────────────────────────────────────────────────────
    double safeDiv(double a, double b) override {
        if (b == 0.0) throw std::runtime_error("division by zero");
        return a / b;
    }
    std::string validateLabel(const std::string& label) override {
        size_t start = label.find_first_not_of(" \t\n\r");
        size_t end = label.find_last_not_of(" \t\n\r");
        std::string trimmed = (start == std::string::npos) ? "" : label.substr(start, end - start + 1);
        if (trimmed.empty()) throw std::runtime_error("empty label");
        return trimmed;
    }

    // ── Slow async ───────────────────────────────────────────────────────────
    int64_t slowAsync(int64_t delayMs) override {
        std::this_thread::sleep_for(std::chrono::milliseconds(delayMs));
        return delayMs;
    }

    // ── Deeply nested @HybridRecord ──────────────────────────────────────────
    NitroCppBuffer echoDeepRecord(NitroCppBuffer value) override { return TcDeepRecord::fromNative(value).toNativeBuffer(); }
    NitroCppBuffer asyncDeepRecord(NitroCppBuffer value) override { return TcDeepRecord::fromNative(value).toNativeBuffer(); }

    // ── @nitroAsync + @NitroOwned/@NitroVariant/@NitroResult ─────────────────
    void* asyncAcquireBuffer(int64_t size) override { return malloc((size_t)size); }
    NitroCppBuffer asyncEchoEvent(NitroCppBuffer event) override {
        TcEvent e = nitro_decode_TcEvent(event);
        return nitro_TcEvent_to_native(e);
    }
    double asyncSafeDiv(double a, double b) override {
        if (b == 0.0) throw std::runtime_error("division by zero");
        return a / b;
    }
    std::string asyncValidateLabel(const std::string& label) override { return validateLabel(label); }

    // ── Gap 9: non-contiguous enum round-trip ────────────────────────────────
    TcPriority echoPriority(TcPriority value) override { return value; }

    // ── Gap 10: Backpressure.bufferDrop stream ───────────────────────────────
    void configureBufferDropIntStream(int64_t from, int64_t count) override {
        nitro_run_detached([this, from, count]() {
            for (int64_t i = 0; i < count; i++) emit_bufferDropIntStream(from + i);
        });
    }

    // ── Gap 13: @NitroVariant as callback parameter ──────────────────────────
    void onEventCallback(std::function<void(NitroCppBuffer)> handler) override {
        TcEventTap tap{}; tap.x = 10; tap.y = 20;
        handler(nitro_TcEvent_to_native(TcEvent{tap}));
        TcEventScroll scroll{}; scroll.delta = 1.5;
        handler(nitro_TcEvent_to_native(TcEvent{scroll}));
    }

    // ── Gap 17: @NitroVariant as Stream item ─────────────────────────────────
    void configureEventStream(int64_t count) override {
        nitro_run_detached([this, count]() {
            for (int64_t i = 0; i < count; i++) {
                if (i % 2 == 0) {
                    TcEventTap tap{}; tap.x = i; tap.y = i * 2;
                    emit_eventStream(nitro_TcEvent_to_native(TcEvent{tap}));
                } else {
                    TcEventScroll scroll{}; scroll.delta = (double)i;
                    emit_eventStream(nitro_TcEvent_to_native(TcEvent{scroll}));
                }
            }
        });
    }

    // ── List<@HybridEnum> ─────────────────────────────────────────────────────
    NitroCppBuffer getStatusList() override {
        std::vector<TcStatus> values = { TCSTATUS_OK, TCSTATUS_ERROR, TCSTATUS_PENDING };
        return nitro_encode_simple_list<TcStatus>(values, [](NitroRecordWriter& w, const TcStatus& e) { w.writeInt(static_cast<int64_t>(e)); });
    }
    NitroCppBuffer echoStatusList(NitroCppBuffer values) override {
        auto items = nitro_decode_list_param<TcStatus>(values, false, [](NitroRecordReader& r) -> TcStatus { return static_cast<TcStatus>(r.readInt()); });
        return nitro_encode_simple_list<TcStatus>(items, [](NitroRecordWriter& w, const TcStatus& e) { w.writeInt(static_cast<int64_t>(e)); });
    }

    // ── List<@NitroVariant> ────────────────────────────────────────────────────
    NitroCppBuffer getEventList() override {
        std::vector<TcEvent> values;
        { TcEventTap c{}; c.x = 1; c.y = 2; values.push_back(c); }
        { TcEventScroll c{}; c.delta = 3.5; values.push_back(c); }
        { TcEventResize c{}; c.width = 100; c.height = 200; values.push_back(c); }
        return nitro_encode_simple_list<TcEvent>(values, [](NitroRecordWriter& w, const TcEvent& e) { nitro_encode_TcEvent(e, w); });
    }
    NitroCppBuffer echoEventList(NitroCppBuffer values) override {
        auto items = nitro_decode_list_param<TcEvent>(values, false, &nitro_decode_TcEvent_fromReader);
        return nitro_encode_simple_list<TcEvent>(items, [](NitroRecordWriter& w, const TcEvent& e) { nitro_encode_TcEvent(e, w); });
    }

    // ── @NitroVariant as property type ───────────────────────────────────────
    NitroCppBuffer get_currentEvent() const override { return const_cast<HybridNitroTypeCoverageImpl*>(this)->_currentEventBuffer(); }
    void set_currentEvent(NitroCppBuffer value) override { _currentEvent = nitro_decode_TcEvent(value); }

    // ── Nullable enum/String stream items ────────────────────────────────────
    void configureNullableStatusStream(int64_t count) override {
        nitro_run_detached([this, count]() {
            for (int64_t i = 0; i < count; i++) {
                if (i % 3 == 0) { emit_nullableStatusStream(std::nullopt); }
                else if (i % 3 == 1) { emit_nullableStatusStream(std::make_optional(TCSTATUS_OK)); }
                else { emit_nullableStatusStream(std::make_optional(TCSTATUS_ERROR)); }
            }
        });
    }
    void configureNullableStringStream(int64_t count) override {
        nitro_run_detached([this, count]() {
            for (int64_t i = 0; i < count; i++) {
                if (i % 2 == 0) { emit_nullableStringStream(std::nullopt); }
                else { emit_nullableStringStream(std::make_optional(std::string("item") + std::to_string(i))); }
            }
        });
    }

    // ── @NitroTuple round-trip ───────────────────────────────────────────────
    NitroCppBuffer echoPair(NitroCppBuffer value) override { return TcPair::fromNative(value).toNativeBuffer(); }
    NitroCppBuffer echoNullablePair(NitroCppBuffer value) override {
        if (value.data == nullptr) return NitroCppBuffer{ nullptr, 0 };
        return TcPair::fromNative(value).toNativeBuffer();
    }

    // ── uint64 round-trip ─────────────────────────────────────────────────────
    uint64_t echoUint64(uint64_t value) override { return value; }
    std::optional<uint64_t> echoNullableUint64(std::optional<uint64_t> value) override { return value; }

    // ── uint64 streams ────────────────────────────────────────────────────────
    void configureUint64Stream(int64_t from, int64_t count) override {
        nitro_run_detached([this, from, count]() {
            for (int64_t i = 0; i < count; i++) emit_uint64Stream((uint64_t)(from + i));
        });
    }
    void configureNullableUint64Stream(int64_t count) override {
        nitro_run_detached([this, count]() {
            for (int64_t i = 0; i < count; i++) {
                if (i % 2 == 0) emit_nullableUint64Stream(std::nullopt);
                else emit_nullableUint64Stream(std::make_optional((uint64_t)i));
            }
        });
    }

    // ── N1: Narrow scalar types ───────────────────────────────────────────────
    int64_t echoInt8(int64_t value) override { return value; }
    int64_t echoInt16(int64_t value) override { return value; }
    int64_t echoInt32(int64_t value) override { return value; }
    int64_t echoUint8(int64_t value) override { return value; }
    int64_t echoUint16(int64_t value) override { return value; }
    int64_t echoUint32(int64_t value) override { return value; }
    double echoFloat(double value) override { return value; }
    std::optional<int64_t> echoNullableInt32(std::optional<int64_t> value) override { return value; }
    std::optional<double> echoNullableFloat(std::optional<double> value) override { return value; }

    // ── N2: Nullable primitive streams ───────────────────────────────────────
    void configureNullableIntStream(int64_t count) override {
        nitro_run_detached([this, count]() {
            for (int64_t i = 0; i < count; i++) {
                if (i % 2 == 0) emit_nullableIntStream(std::nullopt);
                else emit_nullableIntStream(std::make_optional(i));
            }
        });
    }
    void configureNullableDoubleStream(int64_t count) override {
        nitro_run_detached([this, count]() {
            for (int64_t i = 0; i < count; i++) {
                if (i % 2 == 0) emit_nullableDoubleStream(std::nullopt);
                else emit_nullableDoubleStream(std::make_optional((double)i * 0.5));
            }
        });
    }
    void configureNullableBoolStream(int64_t count) override {
        nitro_run_detached([this, count]() {
            for (int64_t i = 0; i < count; i++) {
                int64_t m = i % 3;
                if (m == 0) emit_nullableBoolStream(std::nullopt);
                else if (m == 1) emit_nullableBoolStream(std::make_optional(true));
                else emit_nullableBoolStream(std::make_optional(false));
            }
        });
    }

    // ── N3: @NitroNativeAsync with nullable returns ──────────────────────────
    void nativeAsyncNullableInt(std::optional<int64_t> value, NitroError*, int64_t dartPort) override {
        nitro_run_detached([value, dartPort]() { nitro_post_opt_int64(dartPort, value); });
    }
    void nativeAsyncNullableDouble(std::optional<double> value, NitroError*, int64_t dartPort) override {
        nitro_run_detached([value, dartPort]() { nitro_post_opt_double(dartPort, value); });
    }
    void nativeAsyncNullableBool(std::optional<bool> value, NitroError*, int64_t dartPort) override {
        nitro_run_detached([value, dartPort]() { nitro_post_opt_bool(dartPort, value); });
    }

    // ── §67: @NitroNativeAsync param-decoding + return-dispatch coverage ────
    void nativeAsyncStatus(TcStatus value, NitroError*, int64_t dartPort) override {
        nitro_run_detached([value, dartPort]() { nitro_post_int64(dartPort, static_cast<int64_t>(value)); });
    }
    void nativeAsyncNullableStatus(std::optional<TcStatus> value, NitroError*, int64_t dartPort) override {
        nitro_run_detached([value, dartPort]() {
            nitro_post_int64(dartPort, value.has_value() ? static_cast<int64_t>(*value) : -1LL);
        });
    }
    void nativeAsyncConfig(NitroCppBuffer value, NitroError*, int64_t dartPort) override {
        TcConfig cfg = TcConfig::fromNative(value);
        nitro_run_detached([cfg, dartPort]() { nitro_post_buffer(dartPort, cfg.toNativeBuffer()); });
    }
    void nativeAsyncNullableConfig(NitroCppBuffer value, NitroError*, int64_t dartPort) override {
        bool isNull = (value.data == nullptr);
        std::vector<uint8_t> payloadCopy;
        if (!isNull) payloadCopy.assign(value.data, value.data + value.size);
        nitro_run_detached([isNull, payloadCopy, dartPort]() {
            if (isNull) { nitro_post_int64(dartPort, 0); return; }
            TcConfig cfg = TcConfig::fromNative(NitroCppBuffer{ payloadCopy.data(), payloadCopy.size() });
            nitro_post_buffer(dartPort, cfg.toNativeBuffer());
        });
    }
    void nativeAsyncEvent(NitroCppBuffer value, NitroError*, int64_t dartPort) override {
        TcEvent e = nitro_decode_TcEvent(value);
        nitro_run_detached([e, dartPort]() { nitro_post_buffer(dartPort, nitro_TcEvent_to_native(e)); });
    }
    void nativeAsyncConfigList(NitroCppBuffer values, NitroError*, int64_t dartPort) override {
        auto items = nitro_decode_list_param<TcConfig>(values, true, &TcConfig::fromReader);
        nitro_run_detached([items, dartPort]() {
            NitroCppBuffer out = nitro_encode_indexed_list<TcConfig>(items, [](NitroRecordWriter& w, const TcConfig& e) { e.encodeInto(w); });
            nitro_post_buffer(dartPort, out);
        });
    }
    void nativeAsyncStatusList(NitroCppBuffer values, NitroError*, int64_t dartPort) override {
        auto items = nitro_decode_list_param<TcStatus>(values, false, [](NitroRecordReader& r) -> TcStatus { return static_cast<TcStatus>(r.readInt()); });
        nitro_run_detached([items, dartPort]() {
            NitroCppBuffer out = nitro_encode_simple_list<TcStatus>(items, [](NitroRecordWriter& w, const TcStatus& e) { w.writeInt(static_cast<int64_t>(e)); });
            nitro_post_buffer(dartPort, out);
        });
    }
    void nativeAsyncEventList(NitroCppBuffer values, NitroError*, int64_t dartPort) override {
        auto items = nitro_decode_list_param<TcEvent>(values, false, &nitro_decode_TcEvent_fromReader);
        nitro_run_detached([items, dartPort]() {
            NitroCppBuffer out = nitro_encode_simple_list<TcEvent>(items, [](NitroRecordWriter& w, const TcEvent& e) { nitro_encode_TcEvent(e, w); });
            nitro_post_buffer(dartPort, out);
        });
    }
    void nativeAsyncIntList(NitroCppBuffer values, NitroError*, int64_t dartPort) override {
        auto items = nitro_decode_list_param<int64_t>(values, true, [](NitroRecordReader& r) -> int64_t { return r.readInt(); });
        nitro_run_detached([items, dartPort]() {
            NitroCppBuffer out = nitro_encode_simple_list<int64_t>(items, [](NitroRecordWriter& w, const int64_t& e) { w.writeInt(e); });
            nitro_post_buffer(dartPort, out);
        });
    }
    void nativeAsyncWithCallback(int64_t value, std::function<void(int64_t)> callback, NitroError*, int64_t dartPort) override {
        callback(value);
        nitro_run_detached([value, dartPort]() { nitro_post_int64(dartPort, value * 2); });
    }
    void nativeAsyncCounts(int64_t seed, NitroError*, int64_t dartPort) override {
        std::vector<std::pair<std::string, int64_t>> entries = { { "a", seed }, { "b", seed * 2 } };
        nitro_run_detached([entries, dartPort]() {
            NitroCppBuffer out = nitro_encode_map<int64_t>(entries, 1, [](NitroRecordWriter& w, const int64_t& v) { w.writeInt(v); });
            nitro_post_buffer(dartPort, out);
        });
    }
    void nativeAsyncNullableUint64(std::optional<uint64_t> value, NitroError*, int64_t dartPort) override {
        nitro_run_detached([value, dartPort]() {
            uint8_t* buf = (uint8_t*)malloc(9);
            buf[0] = value.has_value() ? 1 : 0;
            if (value.has_value()) { uint64_t v = *value; memcpy(buf + 1, &v, 8); }
            nitro_post_int64(dartPort, reinterpret_cast<int64_t>(buf));
        });
    }

    // ── §68: Map/AnyMap params, struct returns, AnyMap ───────────────────────
    void nativeAsyncEchoIntMap(NitroCppBuffer value, NitroError*, int64_t dartPort) override {
        auto entries = nitro_decode_map_param<int64_t>(value, [](NitroRecordReader& r) -> int64_t { return r.readInt(); });
        nitro_run_detached([entries, dartPort]() {
            NitroCppBuffer out = nitro_encode_map<int64_t>(entries, 1, [](NitroRecordWriter& w, const int64_t& v) { w.writeInt(v); });
            nitro_post_buffer(dartPort, out);
        });
    }
    void nativeAsyncEchoPoint(const TcPoint& value, NitroError*, int64_t dartPort) override {
        TcPoint p = value;
        nitro_run_detached([p, dartPort]() { nitro_post_struct_copy(dartPort, p); });
    }
    void nativeAsyncEchoAnyMap(void* value, NitroError*, int64_t dartPort) override {
        // NitroAnyMap is opaque to native — `value` already points to a
        // self-describing [4B len][payload] buffer (same convention as
        // records). Echo by copying the raw bytes through unchanged; no need
        // to interpret the internal AnyValue tags for a round-trip test.
        int32_t len = 0;
        std::vector<uint8_t> copy;
        if (value != nullptr) {
            memcpy(&len, value, 4);
            copy.assign((const uint8_t*)value, (const uint8_t*)value + 4 + (size_t)len);
        }
        nitro_run_detached([copy, dartPort]() {
            if (copy.empty()) { nitro_post_int64(dartPort, 0); return; }
            uint8_t* out = (uint8_t*)malloc(copy.size());
            memcpy(out, copy.data(), copy.size());
            nitro_post_int64(dartPort, reinterpret_cast<int64_t>(out));
        });
    }

    // ── Properties ────────────────────────────────────────────────────────────
    int64_t get_precision() const override { return _precision; }
    void set_precision(int64_t value) override { _precision = value; }
    std::string get_tag() const override { return _tag; }
    void set_tag(const std::string& value) override { _tag = value; }
    std::optional<double> get_nullableRate() const override { return _nullableRate; }
    void set_nullableRate(std::optional<double> value) override { _nullableRate = value; }
    bool get_enabled() const override { return _enabled; }
    void set_enabled(bool value) override { _enabled = value; }
    TcStatus get_currentStatus() const override { return _currentStatus; }
    void set_currentStatus(TcStatus value) override { _currentStatus = value; }
    std::optional<int64_t> get_nullableCounter() const override { return _nullableCounter; }
    void set_nullableCounter(std::optional<int64_t> value) override { _nullableCounter = value; }
    std::optional<bool> get_optionalFlag() const override { return _optionalFlag; }
    void set_optionalFlag(std::optional<bool> value) override { _optionalFlag = value; }

private:
    int64_t _precision = 0;
    std::string _tag;
    std::optional<double> _nullableRate;
    bool _enabled = false;
    TcStatus _currentStatus = TCSTATUS_OK;
    std::optional<int64_t> _nullableCounter;
    std::optional<bool> _optionalFlag;
    TcEvent _currentEvent = TcEventTap{0, 0};

    NitroCppBuffer _currentEventBuffer() { return nitro_TcEvent_to_native(_currentEvent); }
};

static HybridNitroTypeCoverageImpl g_impl;

// Auto-register on shared library load — no manual init call needed.
#if defined(_WIN32)
// MSVC lacks __attribute__((constructor)); use a static object instead.
namespace {
  struct _AutoRegister {
    _AutoRegister() { nitro_type_coverage_register_impl(&g_impl); }
  };
  _AutoRegister _auto_register_instance;
}
#else
__attribute__((constructor))
static void nitro_type_coverage_auto_register() {
    nitro_type_coverage_register_impl(&g_impl);
}
#endif
