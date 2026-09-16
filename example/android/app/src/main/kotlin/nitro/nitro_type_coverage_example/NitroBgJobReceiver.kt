package nitro.nitro_type_coverage_example

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import nitro.nitro_type_coverage_module.NitroTypeCoverageJniBridge

/// Native-initiated background job with NO Flutter UI: the app process may be
/// started just for this receiver. Trigger from a shell:
///   adb shell am broadcast -a nitro.BG_JOB \
///     -n nitro.nitro_type_coverage_example/.NitroBgJobReceiver --es text hello
/// The Dart entry `bgPersist` runs in a headless FlutterEngine and persists
/// its line; the app shows it in the "Background job" card when opened.
class NitroBgJobReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val text = intent.getStringExtra("text") ?: "from-broadcast"
        val entry = intent.getStringExtra("entry") ?: "bgPersist"
        NitroTypeCoverageJniBridge.runInBackground(context, entry, text) { jobId, error ->
            android.util.Log.i("NitroBgJob", "$entry job $jobId done: ${error ?: "ok"}")
        }
    }
}
