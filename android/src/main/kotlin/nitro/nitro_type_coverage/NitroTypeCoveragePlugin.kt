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
        NitroTypeCoverageJniBridge.register(NitroTypeCoverageImpl(), binding.applicationContext)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        NitroTypeCoverageJniBridge.onDetached()
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