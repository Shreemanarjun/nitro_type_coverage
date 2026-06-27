import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nitro_type_coverage/nitro_type_coverage.dart' as plugin;
import '../models.dart';

typedef ApiRunner = Future<void> Function(String name, String code, FutureOr<dynamic> Function() action);

ApiSection getPropertiesSection(plugin.NitroTypeCoverage api, ApiRunner runApi) {
  return ApiSection(
    title: 'Properties (Get/Set)',
    icon: Icons.settings_outlined,
    items: [
      ApiItem(
        name: 'precision (int)',
        code: 'api.precision = 42; val = api.precision;',
        description: 'Gets and sets a primitive integer property.',
        run: () => runApi(
          'precision',
          'precision',
          () {
            api.precision = 42;
            return api.precision;
          },
        ),
      ),
      ApiItem(
        name: 'tag (String)',
        code: 'api.tag = "demo-tag"; val = api.tag;',
        description: 'Gets and sets a string property.',
        run: () => runApi(
          'tag',
          'tag',
          () {
            api.tag = 'demo-tag';
            return api.tag;
          },
        ),
      ),
      ApiItem(
        name: 'nullableRate (double?)',
        code: 'api.nullableRate = 0.85; val = api.nullableRate;',
        description: 'Gets and sets a nullable double property.',
        run: () => runApi(
          'nullableRate',
          'nullableRate',
          () {
            api.nullableRate = 0.85;
            return api.nullableRate;
          },
        ),
      ),
      ApiItem(
        name: 'enabled (bool)',
        code: 'api.enabled = true; val = api.enabled;',
        description: 'Gets and sets a boolean property.',
        run: () => runApi(
          'enabled',
          'enabled',
          () {
            api.enabled = true;
            return api.enabled;
          },
        ),
      ),
      ApiItem(
        name: 'currentStatus (TcStatus)',
        code: 'api.currentStatus = TcStatus.pending;',
        description: 'Gets and sets an enum property.',
        run: () => runApi(
          'currentStatus',
          'currentStatus',
          () {
            api.currentStatus = plugin.TcStatus.pending;
            return api.currentStatus;
          },
        ),
      ),
      ApiItem(
        name: 'nullableCounter (int?)',
        code: 'api.nullableCounter = 100;',
        description: 'Gets and sets a nullable int property.',
        run: () => runApi(
          'nullableCounter',
          'nullableCounter',
          () {
            api.nullableCounter = 100;
            return api.nullableCounter;
          },
        ),
      ),
      ApiItem(
        name: 'optionalFlag (bool?)',
        code: 'api.optionalFlag = null;',
        description: 'Gets and sets a nullable boolean property to null.',
        run: () => runApi(
          'optionalFlag',
          'optionalFlag',
          () {
            api.optionalFlag = null;
            return api.optionalFlag;
          },
        ),
      ),
    ],
  );
}
