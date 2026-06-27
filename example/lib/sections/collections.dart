import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nitro_type_coverage/nitro_type_coverage.dart' as plugin;
import '../models.dart';

typedef ApiRunner = Future<void> Function(String name, String code, FutureOr<dynamic> Function() action);

ApiSection getCollectionsSection(plugin.NitroTypeCoverage api, ApiRunner runApi) {
  return ApiSection(
    title: 'Collections (Lists & Maps)',
    icon: Icons.grid_view_outlined,
    items: [
      ApiItem(
        name: 'echoIntList',
        code: 'await api.echoIntList([1, 2, 3])',
        description: 'JSON-serialized async transport of an integer list.',
        run: () => runApi('echoIntList', 'echoIntList([1, 2, 3])', () => api.echoIntList([1, 2, 3])),
      ),
      ApiItem(
        name: 'echoDoubleList',
        code: 'await api.echoDoubleList([1.1, 2.2])',
        description: 'JSON-serialized async transport of a double list.',
        run: () => runApi('echoDoubleList', 'echoDoubleList([1.1, 2.2])', () => api.echoDoubleList([1.1, 2.2])),
      ),
      ApiItem(
        name: 'echoStringList',
        code: 'await api.echoStringList(["A", "B", "C"])',
        description: 'JSON-serialized async transport of a string list.',
        run: () => runApi(
          'echoStringList',
          'echoStringList(["A", "B", "C"])',
          () => api.echoStringList(['A', 'B', 'C']),
        ),
      ),
      ApiItem(
        name: 'echoConfigList',
        code: 'await api.echoConfigList([config1, config2])',
        description: 'JSON-serialized async transport of a record list.',
        run: () => runApi(
          'echoConfigList',
          'echoConfigList(...)',
          () => api.echoConfigList([
            plugin.TcConfig(name: 'c1', count: 1, enabled: true, threshold: 0.1),
            plugin.TcConfig(name: 'c2', count: 2, enabled: false, threshold: 0.9),
          ]),
        ),
      ),
      ApiItem(
        name: 'echoConfigListSync',
        code: 'await api.echoConfigListSync([config1])',
        description: 'Sync FFI method accepting list of records parameter.',
        run: () => runApi(
          'echoConfigListSync',
          'echoConfigListSync(...)',
          () => api.echoConfigListSync([
            plugin.TcConfig(name: 'syncList', count: 5, enabled: true, threshold: 0.5),
          ]),
        ),
      ),
      ApiItem(
        name: 'echoListBool',
        code: 'await api.echoListBool([true, false, true])',
        description: 'Async transport of a boolean list.',
        run: () => runApi('echoListBool', 'echoListBool(...)', () => api.echoListBool([true, false, true])),
      ),
      ApiItem(
        name: 'echoPointList',
        code: 'await api.echoPointList([point1, point2])',
        description: 'Async transport of a list of struct objects.',
        run: () => runApi(
          'echoPointList',
          'echoPointList(...)',
          () => api.echoPointList([
            plugin.TcPoint(x: 1.0, y: 1.0, z: 1.0),
            plugin.TcPoint(x: 2.0, y: 2.0, z: 2.0),
          ]),
        ),
      ),
      ApiItem(
        name: 'echoIntMap',
        code: 'api.echoIntMap({"a": 1, "b": 2})',
        description: 'JSON-encoded map of integers.',
        run: () => runApi('echoIntMap', 'echoIntMap({"a": 1, "b": 2})', () => api.echoIntMap({'a': 1, 'b': 2})),
      ),
      ApiItem(
        name: 'echoStringMap',
        code: 'api.echoStringMap({"key": "val"})',
        description: 'JSON-encoded map of strings.',
        run: () => runApi(
          'echoStringMap',
          'echoStringMap(...)',
          () => api.echoStringMap({'key': 'val'}),
        ),
      ),
      ApiItem(
        name: 'echoDoubleMap',
        code: 'api.echoDoubleMap({"x": 1.25})',
        description: 'JSON-encoded map of doubles.',
        run: () => runApi('echoDoubleMap', 'echoDoubleMap(...)', () => api.echoDoubleMap({'x': 1.25})),
      ),
      ApiItem(
        name: 'echoBoolMap',
        code: 'api.echoBoolMap({"active": true})',
        description: 'JSON-encoded map of booleans.',
        run: () => runApi('echoBoolMap', 'echoBoolMap(...)', () => api.echoBoolMap({'active': true})),
      ),
    ],
  );
}
