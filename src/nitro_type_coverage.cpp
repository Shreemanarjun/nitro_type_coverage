#include <stdint.h>
#include <stdbool.h>
#include "nitro.h"

#include "../lib/src/generated/cpp/nitro_type_coverage.bridge.g.h"

extern "C" {
}

// §39: Kotlin can't post to Dart directly, so its coalescer buffers pairs and
// calls this JNI helper to post the batch as one kArray of int64.
#ifdef __ANDROID__
#include <jni.h>
#include <vector>
#include "dart_api_dl.h"

extern "C" JNIEXPORT void JNICALL
Java_nitro_nitro_1type_1coverage_NitroTypeCoverageImpl_nativeCoalescePost(
    JNIEnv* env, jobject /*thiz*/, jlong port, jlongArray pairs) {
  const jsize len = env->GetArrayLength(pairs);
  if (len <= 0) return;
  std::vector<int64_t> flat(static_cast<size_t>(len));
  env->GetLongArrayRegion(pairs, 0, len, reinterpret_cast<jlong*>(flat.data()));
  // flat = [callId0, value0, callId1, value1, ...] — post as one kArray of int64.
  std::vector<Dart_CObject> elems(static_cast<size_t>(len));
  std::vector<Dart_CObject*> ptrs(static_cast<size_t>(len));
  for (jsize i = 0; i < len; ++i) {
    elems[i].type = Dart_CObject_kInt64;
    elems[i].value.as_int64 = flat[i];
    ptrs[i] = &elems[i];
  }
  Dart_CObject arr;
  arr.type = Dart_CObject_kArray;
  arr.value.as_array.length = len;
  arr.value.as_array.values = ptrs.data();
  Dart_PostCObject_DL(static_cast<Dart_Port_DL>(port), &arr);
}
#endif
