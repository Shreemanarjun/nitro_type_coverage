import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nitro_type_coverage/nitro_type_coverage.dart' as plugin;
import '../models.dart';

typedef ApiRunner = Future<void> Function(String name, String code, FutureOr<dynamic> Function() action);

ApiSection getMultiParamSyncSection(plugin.NitroTypeCoverage api, ApiRunner runApi) {
  return ApiSection(
    title: 'Multi-Param (Sync)',
    icon: Icons.star_border,
    items: [
      ApiItem(
        name: 'addInts',
        code: 'api.addInts(10, 20, 30)',
        description: 'Takes 3 integers and returns their sum synchronously.',
        run: () => runApi('addInts', 'addInts(10, 20, 30)', () => api.addInts(10, 20, 30)),
      ),
      ApiItem(
        name: 'mulDoubles',
        code: 'api.mulDoubles(2.5, 4.0)',
        description: 'Takes 2 doubles and returns their product synchronously.',
        run: () => runApi('mulDoubles', 'mulDoubles(2.5, 4.0)', () => api.mulDoubles(2.5, 4.0)),
      ),
      ApiItem(
        name: 'joinStrings',
        code: 'api.joinStrings("Hello", "World", " ⚡ ")',
        description: 'Joins two strings with a separator synchronously.',
        run: () => runApi(
          'joinStrings',
          'joinStrings("Hello", "World", " ⚡ ")',
          () => api.joinStrings('Hello', 'World', ' ⚡ '),
        ),
      ),
    ],
  );
}
