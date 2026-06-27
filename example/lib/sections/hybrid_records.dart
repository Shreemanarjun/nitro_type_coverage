import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nitro/nitro.dart';
import 'package:nitro_type_coverage/nitro_type_coverage.dart' as plugin;
import '../models.dart';

typedef ApiRunner = Future<void> Function(String name, String code, FutureOr<dynamic> Function() action);

ApiSection getHybridRecordsSection(plugin.NitroTypeCoverage api, ApiRunner runApi) {
  return ApiSection(
    title: 'Hybrid Records',
    icon: Icons.assignment_outlined,
    items: [
      ApiItem(
        name: 'echoConfig',
        code: 'api.echoConfig(TcConfig(name: "dev", count: 12, enabled: true, threshold: 0.8))',
        description: 'Serializes and round-trips a record class.',
        run: () => runApi(
          'echoConfig',
          'echoConfig(TcConfig(name: "dev", count: 12, enabled: true, threshold: 0.8))',
          () => api.echoConfig(plugin.TcConfig(name: 'dev', count: 12, enabled: true, threshold: 0.8)),
        ),
      ),
      ApiItem(
        name: 'echoMeta',
        code: 'api.echoMeta(TcMeta(version: 5, weight: 1.25, active: true, label: "prod"))',
        description: 'Tests record codec position-stability with mixed field order.',
        run: () => runApi(
          'echoMeta',
          'echoMeta(TcMeta(...))',
          () => api.echoMeta(plugin.TcMeta(version: 5, weight: 1.25, active: true, label: 'prod')),
        ),
      ),
      ApiItem(
        name: 'echoPacket',
        code: 'api.echoPacket(TcPacket(name: "data", sequence: 25, status: TcStatus.pending, valid: true))',
        description: 'Round-trips a record class containing an enum field.',
        run: () => runApi(
          'echoPacket',
          'echoPacket(TcPacket(...))',
          () => api.echoPacket(plugin.TcPacket(name: 'data', sequence: 25, status: plugin.TcStatus.pending, valid: true)),
        ),
      ),
      ApiItem(
        name: 'echoNested',
        code: 'api.echoNested(TcNested(label: "root", config: config, version: 1))',
        description: 'Round-trips a nested record structure.',
        run: () => runApi(
          'echoNested',
          'echoNested(TcNested(...))',
          () => api.echoNested(
            plugin.TcNested(
              label: 'root',
              config: plugin.TcConfig(name: 'sub', count: 3, enabled: true, threshold: 0.2),
              version: 1,
            ),
          ),
        ),
      ),
      ApiItem(
        name: 'echoNullableWrapper',
        code: 'api.echoNullableWrapper(TcNullableWrapper(...))',
        description: 'Tests NitroNullable library types inside record fields.',
        run: () => runApi(
          'echoNullableWrapper',
          'echoNullableWrapper(TcNullableWrapper(...))',
          () => api.echoNullableWrapper(
            plugin.TcNullableWrapper(
              count: NitroNullableInt.fromNullable(400),
              rate: NitroNullableDouble.fromNullable(null),
              name: 'null-wrapper',
            ),
          ),
        ),
      ),
      ApiItem(
        name: 'echoStructHolder',
        code: 'api.echoStructHolder(TcStructHolder(...))',
        description: 'Tests @HybridStruct inline embedded inside a @HybridRecord field.',
        run: () => runApi(
          'echoStructHolder',
          'echoStructHolder(TcStructHolder(...))',
          () => api.echoStructHolder(
            plugin.TcStructHolder(
              label: 'holder',
              origin: plugin.TcPoint(x: 1.5, y: 2.5, z: 3.5),
              radius: 10.0,
            ),
          ),
        ),
      ),
      ApiItem(
        name: 'echoNullableConfig',
        code: 'api.echoNullableConfig(null)',
        description: 'Round-trips a nullable config record (sent as null).',
        run: () => runApi('echoNullableConfig', 'echoNullableConfig(null)', () => api.echoNullableConfig(null)),
      ),
    ],
  );
}
