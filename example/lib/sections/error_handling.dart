import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nitro_type_coverage/nitro_type_coverage.dart' as plugin;
import '../models.dart';

typedef ApiRunner = Future<void> Function(String name, String code, FutureOr<dynamic> Function() action);

ApiSection getErrorHandlingSection(plugin.NitroTypeCoverage api, ApiRunner runApi) {
  return ApiSection(
    title: 'Error Handling',
    icon: Icons.error_outline,
    items: [
      ApiItem(
        name: 'throwNative',
        code: 'api.throwNative("test native error")',
        description: 'Throws a native C++ exception synchronously which is propagated into Dart.',
        run: () => runApi('throwNative', 'throwNative(...)', () => api.throwNative('test native error')),
      ),
      ApiItem(
        name: 'throwNativeAsync',
        code: 'await api.throwNativeAsync("async error")',
        description: 'Throws an exception asynchronously in a background thread that rejects the Future.',
        run: () => runApi('throwNativeAsync', 'throwNativeAsync(...)', () => api.throwNativeAsync('async error')),
      ),
    ],
  );
}
