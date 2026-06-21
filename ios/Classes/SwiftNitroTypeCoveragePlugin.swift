import Flutter
import UIKit

public class SwiftNitroTypeCoveragePlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        NitroTypeCoverageRegistry.register(NitroTypeCoverageImpl())
    }
}
