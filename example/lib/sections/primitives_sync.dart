import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nitro_type_coverage/nitro_type_coverage.dart' as plugin;
import '../models.dart';

typedef ApiRunner = Future<void> Function(String name, String code, FutureOr<dynamic> Function() action);

ApiSection getPrimitivesSyncSection(plugin.NitroTypeCoverage api, ApiRunner runApi) {
  return ApiSection(
    title: 'Primitives (Sync)',
    icon: Icons.looks_one_outlined,
    items: [
      ApiItem(
        name: 'echoInt',
        code: 'api.echoInt(42)',
        description: 'Passes and returns a primitive 64-bit integer synchronously.',
        run: () => runApi('echoInt', 'echoInt(42)', () => api.echoInt(42)),
      ),
      ApiItem(
        name: 'echoDouble',
        code: 'api.echoDouble(3.14159)',
        description: 'Passes and returns a double-precision float synchronously.',
        run: () => runApi('echoDouble', 'echoDouble(3.14159)', () => api.echoDouble(3.14159)),
      ),
      ApiItem(
        name: 'echoBool',
        code: 'api.echoBool(true)',
        description: 'Passes and returns a boolean synchronously.',
        run: () => runApi('echoBool', 'echoBool(true)', () => api.echoBool(true)),
      ),
      ApiItem(
        name: 'echoString',
        code: 'api.echoString("Hello Nitro")',
        description: 'Passes and returns a UTF-8 string synchronously.',
        run: () => runApi('echoString', 'echoString("Hello Nitro")', () => api.echoString('Hello Nitro')),
      ),
    ],
  );
}
