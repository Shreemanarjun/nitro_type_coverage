package nitro.nitro_type_coverage_example

import android.app.Activity
import android.os.Bundle
import nitro.nitro_type_coverage_module.NitroTypeCoverageJniBridge

/// URL-scheme twin of [NitroBgJobReceiver] so the same `nitrobg://run?text=…`
/// link triggers a background job on Android and iOS (Patrol's `openUrl`).
/// Theme.NoDisplay: no window is shown and the activity finishes at once; the
/// Dart entry runs in a headless FlutterEngine in this (possibly fresh) process.
class NitroBgJobActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val text = intent?.data?.getQueryParameter("text") ?: "from-url"
        val entry = intent?.data?.getQueryParameter("entry") ?: "bgPersist"
        NitroTypeCoverageJniBridge.runInBackground(applicationContext, entry, text) { jobId, error ->
            android.util.Log.i("NitroBgJob", "$entry job $jobId done: ${error ?: "ok"}")
        }
        finish()
    }
}
