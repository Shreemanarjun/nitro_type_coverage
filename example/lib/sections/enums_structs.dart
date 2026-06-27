import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nitro_type_coverage/nitro_type_coverage.dart' as plugin;
import '../models.dart';

typedef ApiRunner = Future<void> Function(String name, String code, FutureOr<dynamic> Function() action);

ApiSection getEnumsStructsSection(plugin.NitroTypeCoverage api, ApiRunner runApi) {
  return ApiSection(
    title: 'Enums & Structs',
    icon: Icons.category_outlined,
    items: [
      ApiItem(
        name: 'echoStatus(ok)',
        code: 'api.echoStatus(TcStatus.ok)',
        description: 'Sends and receives a status enum value.',
        run: () => runApi('echoStatus', 'echoStatus(TcStatus.ok)', () => api.echoStatus(plugin.TcStatus.ok)),
      ),
      ApiItem(
        name: 'echoNullableStatus',
        code: 'api.echoNullableStatus(null)',
        description: 'Sends and receives a null status enum.',
        run: () => runApi('echoNullableStatus', 'echoNullableStatus(null)', () => api.echoNullableStatus(null)),
      ),
      ApiItem(
        name: 'echoPoint',
        code: 'api.echoPoint(TcPoint(x: 1, y: 2, z: 3))',
        description: 'Sends and receives a 3D coordinate struct inline over FFI.',
        run: () => runApi(
          'echoPoint',
          'echoPoint(TcPoint(x: 1, y: 2, z: 3))',
          () => api.echoPoint(plugin.TcPoint(x: 1.0, y: 2.0, z: 3.0)),
        ),
      ),
      ApiItem(
        name: 'echoNullablePoint',
        code: 'api.echoNullablePoint(null)',
        description: 'Sends and receives a null Struct pointer.',
        run: () => runApi('echoNullablePoint', 'echoNullablePoint(null)', () => api.echoNullablePoint(null)),
      ),
    ],
  );
}
