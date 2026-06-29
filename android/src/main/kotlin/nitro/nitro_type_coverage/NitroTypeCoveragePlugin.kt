package nitro.nitro_type_coverage

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import nitro.nitro_type_coverage_module.NitroTypeCoverageJniBridge

class NitroTypeCoveragePlugin : FlutterPlugin, ActivityAware {

    companion object {
        init { System.loadLibrary("nitro_type_coverage") }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // Register the constructor factory once — instances are created on demand
        // when Dart calls getInstance(key), mirroring RN Nitro's HybridObjectRegistry.
        NitroTypeCoverageJniBridge.registerFactory({ NitroTypeCoverageImpl() }, binding.applicationContext)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // Instance cleanup is driven by Dart's dispose() → destroy_instance C bridge call.
        // No manual per-instance teardown needed here at the type level.
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        NitroTypeCoverageJniBridge.onActivityAttached(binding.activity)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        NitroTypeCoverageJniBridge.onActivityDetached()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        NitroTypeCoverageJniBridge.onActivityAttached(binding.activity)
    }

    override fun onDetachedFromActivity() {
        NitroTypeCoverageJniBridge.onActivityDetached()
    }
}