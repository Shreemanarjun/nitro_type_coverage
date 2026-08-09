package nitro.nitro_type_coverage_example

import android.os.Debug
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    /// Improvement E — JVM allocation counter for the JNI benchmark harness.
    ///
    /// The JNI bridge's real cost is the garbage it creates (every per-call
    /// `NewByteArray` is a JVM heap object), which shows up as GC pressure
    /// rather than CPU time. `Debug.getGlobalAllocSize()` gives the running
    /// total of bytes allocated, so the harness can report bytes-per-call and
    /// measure improvement D (reusing a direct ByteBuffer) directly.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "nitro_type_coverage/jvm_stats",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "allocatedBytes" -> {
                    // Allocation counting is off by default; enabling it is
                    // idempotent and cheap, and the harness only samples twice
                    // per case (before/after the measured window).
                    Debug.startAllocCounting()
                    result.success(Debug.getGlobalAllocSize().toLong())
                }
                else -> result.notImplemented()
            }
        }
    }
}
