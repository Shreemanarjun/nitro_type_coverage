// Native leak check — drives the REAL generated bridge + impl through the
// C ABI under AddressSanitizer/LeakSanitizer, playing Dart's role exactly:
//
//   • params it allocates are freed by it (like Dart's Arena),
//   • returns whose ownership transfers to Dart are freed via
//     <lib>_nitro_free / release_typed_data_return (like generated Dart code),
//   • callback returns are allocated via <lib>_nitro_alloc (like the
//     generated trampolines' NitroNativeAllocator).
//
// Anything LeakSanitizer reports at exit is a genuine leak in the generated
// dispatch or the hand-written impl — no Flutter engine or Dart VM noise.
//
// Scope: SYNC dispatch paths. Streams/@nitroNativeAsync post to Dart ports
// (Dart_PostCObject_DL) and are exercised by the integration suite's RSS
// soak tests plus focused ASan harnesses instead.
//
// Build (see native_leak_check.sh): clang++ -fsanitize=address -std=c++17 ...

#include <cassert>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

#include "nitro_type_coverage.bridge.g.h"

static const int kIterations = 2000;

// ── Dart-role helpers ─────────────────────────────────────────────────────────

// Record/list/map wire helper: [4B len][payload].
struct Blob {
    std::vector<uint8_t> bytes;
    void i32(int32_t v) { bytes.insert(bytes.end(), (uint8_t*)&v, (uint8_t*)&v + 4); }
    void i64(int64_t v) { bytes.insert(bytes.end(), (uint8_t*)&v, (uint8_t*)&v + 8); }
    void f64(double v) { bytes.insert(bytes.end(), (uint8_t*)&v, (uint8_t*)&v + 8); }
    void b(bool v) { bytes.push_back(v ? 1 : 0); }
    void str(const std::string& s) { i32((int32_t)s.size()); bytes.insert(bytes.end(), s.begin(), s.end()); }
    // Returns a [4B len][payload] buffer, caller-owned (Dart Arena role).
    std::vector<uint8_t> framed() const {
        std::vector<uint8_t> out;
        int32_t len = (int32_t)bytes.size();
        out.insert(out.end(), (uint8_t*)&len, (uint8_t*)&len + 4);
        out.insert(out.end(), bytes.begin(), bytes.end());
        return out;
    }
};

// TcConfig payload: [str name][i64 count][b enabled][f64 threshold].
static Blob tcConfig(const std::string& name) {
    Blob b;
    b.str(name);
    b.i64(42);
    b.b(true);
    b.f64(0.5);
    return b;
}

// Callback returning a string: must allocate via nitro_alloc — the bridge
// wrapper frees it with C-runtime free() after copying (the exact contract
// the generated Dart trampolines follow via NitroNativeAllocator).
static const char* stringTransformCb(int64_t v) {
    char buf[64];
    snprintf(buf, sizeof(buf), "transformed-%lld", (long long)v);
    size_t n = strlen(buf) + 1;
    char* out = (char*)nitro_type_coverage_nitro_alloc(n);
    memcpy(out, buf, n);
    return out;
}

int main() {
    NitroError err;
    memset(&err, 0, sizeof(err));
    int64_t id = nitro_type_coverage_create_instance("leak-check");

    const std::string bigName(2048, 'x');  // kB-sized so per-iteration leaks are loud

    for (int i = 0; i < kIterations; i++) {
        // ── String return: native strdup → "Dart" frees via nitro_free ──────
        {
            const char* r = nitro_type_coverage_echo_string(id, "hello-leak-check", &err);
            assert(r && strcmp(r, "hello-leak-check") == 0);
            nitro_type_coverage_nitro_free((void*)r);
        }

        // ── Record round-trip: param is caller-owned, return is Dart-owned ──
        {
            auto param = tcConfig(bigName).framed();
            void* r = nitro_type_coverage_echo_config(id, param.data(), &err);
            assert(r != nullptr);
            nitro_type_coverage_nitro_free(r);
        }

        // ── Map<String, record> round-trip (§L4a wire: [4B outer][4B inner]) ─
        {
            Blob m;
            m.i32(2);  // count
            for (int k = 0; k < 2; k++) {
                m.str("key-" + std::to_string(k));
                m.bytes.push_back(5);  // tag 5 = binary record
                Blob rec = tcConfig(bigName);
                m.i32((int32_t)rec.bytes.size() + 4);  // outer blob length
                m.i32((int32_t)rec.bytes.size());      // record's own prefix
                m.bytes.insert(m.bytes.end(), rec.bytes.begin(), rec.bytes.end());
            }
            auto param = m.framed();
            uint8_t* r = nitro_type_coverage_echo_config_map(id, param.data(), &err);
            assert(r != nullptr && err.hasError == 0);
            nitro_type_coverage_nitro_free(r);
        }

        // ── Zero-copy TypedData return: envelope released like the Dart
        //    NativeFinalizer does ─────────────────────────────────────────────
        {
            std::vector<uint8_t> data(4096, (uint8_t)i);
            uint8_t* env = nitro_type_coverage_echo_bytes(id, data.data(), data.size(), &err);
            assert(env != nullptr);
            nitro_type_coverage_release_typed_data_return(env);
        }

        // ── String-returning callback: wrapper frees the nitro_alloc'd copy ──
        {
            nitro_type_coverage_on_string_transform(id, stringTransformCb, &err);
            assert(err.hasError == 0);
        }
    }

    printf("native_leak_check: %d iterations of 5 sync paths complete — "
           "LeakSanitizer verdict follows at exit.\n", kIterations);
    return 0;
}
