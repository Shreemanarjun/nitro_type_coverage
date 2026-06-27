import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nitro_type_coverage/nitro_type_coverage.dart' as plugin;
import '../models.dart';

typedef ApiRunner = Future<void> Function(String name, String code, FutureOr<dynamic> Function() action);

ApiSection getNullablePrimitivesSyncSection(plugin.NitroTypeCoverage api, ApiRunner runApi) {
  return ApiSection(
    title: 'Nullable Primitives (Sync)',
    icon: Icons.question_mark_outlined,
    items: [
      ApiItem(
        name: 'echoNullableInt(null)',
        code: 'api.echoNullableInt(null)',
        description: 'Sends and receives a null integer.',
        run: () => runApi('echoNullableInt', 'echoNullableInt(null)', () => api.echoNullableInt(null)),
      ),
      ApiItem(
        name: 'echoNullableInt(99)',
        code: 'api.echoNullableInt(99)',
        description: 'Sends and receives a non-null nullable integer.',
        run: () => runApi('echoNullableInt', 'echoNullableInt(99)', () => api.echoNullableInt(99)),
      ),
      ApiItem(
        name: 'echoNullableDouble',
        code: 'api.echoNullableDouble(2.718)',
        description: 'Sends and receives a nullable double.',
        run: () => runApi('echoNullableDouble', 'echoNullableDouble(2.718)', () => api.echoNullableDouble(2.718)),
      ),
      ApiItem(
        name: 'echoNullableBool',
        code: 'api.echoNullableBool(null)',
        description: 'Sends and receives a null boolean.',
        run: () => runApi('echoNullableBool', 'echoNullableBool(null)', () => api.echoNullableBool(null)),
      ),
      ApiItem(
        name: 'echoNullableString',
        code: 'api.echoNullableString("Active")',
        description: 'Sends and receives a nullable string.',
        run: () => runApi('echoNullableString', 'echoNullableString("Active")', () => api.echoNullableString('Active')),
      ),
    ],
  );
}
