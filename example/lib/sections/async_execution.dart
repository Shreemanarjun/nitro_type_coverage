import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nitro_type_coverage/nitro_type_coverage.dart' as plugin;
import '../models.dart';

typedef ApiRunner = Future<void> Function(String name, String code, FutureOr<dynamic> Function() action);

ApiSection getAsyncExecutionSection(plugin.NitroTypeCoverage api, ApiRunner runApi) {
  return ApiSection(
    title: 'Asynchronous Execution',
    icon: Icons.timer_outlined,
    items: [
      ApiItem(
        name: 'asyncInt',
        code: 'await api.asyncInt(100)',
        description: 'Dispatches task to native background thread and awaits int.',
        run: () => runApi('asyncInt', 'asyncInt(100)', () => api.asyncInt(100)),
      ),
      ApiItem(
        name: 'asyncDouble',
        code: 'await api.asyncDouble(9.99)',
        description: 'Dispatches task to native background thread and awaits double.',
        run: () => runApi('asyncDouble', 'asyncDouble(9.99)', () => api.asyncDouble(9.99)),
      ),
      ApiItem(
        name: 'asyncBool',
        code: 'await api.asyncBool(false)',
        description: 'Dispatches task to native background thread and awaits bool.',
        run: () => runApi('asyncBool', 'asyncBool(false)', () => api.asyncBool(false)),
      ),
      ApiItem(
        name: 'asyncString',
        code: 'await api.asyncString("hello async")',
        description: 'Dispatches task to native background thread and awaits string.',
        run: () => runApi('asyncString', 'asyncString("hello async")', () => api.asyncString('hello async')),
      ),
      ApiItem(
        name: 'asyncConfig',
        code: 'await api.asyncConfig(config)',
        description: 'Dispatches record class conversion to native thread.',
        run: () => runApi(
          'asyncConfig',
          'asyncConfig(...)',
          () => api.asyncConfig(plugin.TcConfig(name: 'async-rec', count: 99, enabled: true, threshold: 0.99)),
        ),
      ),
      ApiItem(
        name: 'asyncNullableInt',
        code: 'await api.asyncNullableInt(null)',
        description: 'Dispatches task returning nullable int.',
        run: () => runApi('asyncNullableInt', 'asyncNullableInt(null)', () => api.asyncNullableInt(null)),
      ),
      ApiItem(
        name: 'asyncNullableDouble',
        code: 'await api.asyncNullableDouble(2.5)',
        description: 'Dispatches task returning nullable double.',
        run: () => runApi('asyncNullableDouble', 'asyncNullableDouble(2.5)', () => api.asyncNullableDouble(2.5)),
      ),
      ApiItem(
        name: 'asyncNullableBool',
        code: 'await api.asyncNullableBool(true)',
        description: 'Dispatches task returning nullable bool.',
        run: () => runApi('asyncNullableBool', 'asyncNullableBool(true)', () => api.asyncNullableBool(true)),
      ),
      ApiItem(
        name: 'asyncNullableString',
        code: 'await api.asyncNullableString(null)',
        description: 'Dispatches task returning nullable string.',
        run: () => runApi('asyncNullableString', 'asyncNullableString(null)', () => api.asyncNullableString(null)),
      ),
      ApiItem(
        name: 'asyncPoint',
        code: 'await api.asyncPoint(point)',
        description: 'Dispatches task returning struct point.',
        run: () => runApi(
          'asyncPoint',
          'asyncPoint(...)',
          () => api.asyncPoint(plugin.TcPoint(x: 10.0, y: 20.0, z: 30.0)),
        ),
      ),
      ApiItem(
        name: 'asyncNullableStatus',
        code: 'await api.asyncNullableStatus(TcStatus.pending)',
        description: 'Dispatches task returning nullable enum.',
        run: () => runApi(
          'asyncNullableStatus',
          'asyncNullableStatus(...)',
          () => api.asyncNullableStatus(plugin.TcStatus.pending),
        ),
      ),
      ApiItem(
        name: 'asyncMeta',
        code: 'await api.asyncMeta(meta)',
        description: 'Dispatches task returning meta record.',
        run: () => runApi(
          'asyncMeta',
          'asyncMeta(...)',
          () => api.asyncMeta(plugin.TcMeta(version: 1, weight: 5.5, active: true, label: 'asyncMeta')),
        ),
      ),
      ApiItem(
        name: 'nativeAsyncInt',
        code: 'await api.nativeAsyncInt(10)',
        description: 'Runs native async returning int (uses @NitroNativeAsync annotation).',
        run: () => runApi('nativeAsyncInt', 'nativeAsyncInt(10)', () => api.nativeAsyncInt(10)),
      ),
      ApiItem(
        name: 'nativeAsyncDouble',
        code: 'await api.nativeAsyncDouble(1.5)',
        description: 'Runs native async returning double.',
        run: () => runApi('nativeAsyncDouble', 'nativeAsyncDouble(1.5)', () => api.nativeAsyncDouble(1.5)),
      ),
      ApiItem(
        name: 'nativeAsyncBool',
        code: 'await api.nativeAsyncBool(true)',
        description: 'Runs native async returning bool.',
        run: () => runApi('nativeAsyncBool', 'nativeAsyncBool(true)', () => api.nativeAsyncBool(true)),
      ),
      ApiItem(
        name: 'nativeAsyncString',
        code: 'await api.nativeAsyncString("native-async")',
        description: 'Runs native async returning string.',
        run: () => runApi(
          'nativeAsyncString',
          'nativeAsyncString(...)',
          () => api.nativeAsyncString('native-async'),
        ),
      ),
    ],
  );
}
