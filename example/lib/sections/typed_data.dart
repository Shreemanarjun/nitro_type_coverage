import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:nitro/nitro.dart';
import 'package:nitro_type_coverage/nitro_type_coverage.dart' as plugin;
import '../models.dart';

typedef ApiRunner = Future<void> Function(String name, String code, FutureOr<dynamic> Function() action);

ApiSection getTypedDataSection(plugin.NitroTypeCoverage api, ApiRunner runApi) {
  return ApiSection(
    title: 'Typed Data (Zero-Copy)',
    icon: Icons.storage_outlined,
    items: [
      ApiItem(
        name: 'echoBytes (Uint8List)',
        code: 'api.echoBytes(Uint8List.fromList([10, 20, 30]))',
        description: 'Zero-copy exchange of raw byte array.',
        run: () => runApi(
          'echoBytes',
          'echoBytes(Uint8List.fromList([10, 20, 30]))',
          () => api.echoBytes(Uint8List.fromList([10, 20, 30])),
        ),
      ),
      ApiItem(
        name: 'echoFloats (Float32List)',
        code: 'api.echoFloats(Float32List.fromList([1.2, 3.4]))',
        description: 'Zero-copy float array (32-bit).',
        run: () => runApi(
          'echoFloats',
          'echoFloats(Float32List.fromList([1.2, 3.4]))',
          () => api.echoFloats(Float32List.fromList([1.2, 3.4])),
        ),
      ),
      ApiItem(
        name: 'echoFloat64s (Float64List)',
        code: 'api.echoFloat64s(Float64List.fromList([1.2, 3.4]))',
        description: 'Zero-copy double array (64-bit).',
        run: () => runApi(
          'echoFloat64s',
          'echoFloat64s(...)',
          () => api.echoFloat64s(Float64List.fromList([1.2, 3.4])),
        ),
      ),
      ApiItem(
        name: 'echoInt8s (Int8List)',
        code: 'api.echoInt8s(Int8List.fromList([-1, 0, 1]))',
        description: 'Zero-copy signed 8-bit integers.',
        run: () => runApi(
          'echoInt8s',
          'echoInt8s(...)',
          () => api.echoInt8s(Int8List.fromList([-1, 0, 1])),
        ),
      ),
      ApiItem(
        name: 'echoInt16s (Int16List)',
        code: 'api.echoInt16s(Int16List.fromList([-10, 0, 10]))',
        description: 'Zero-copy signed 16-bit integers.',
        run: () => runApi(
          'echoInt16s',
          'echoInt16s(...)',
          () => api.echoInt16s(Int16List.fromList([-10, 0, 10])),
        ),
      ),
      ApiItem(
        name: 'echoInt32s (Int32List)',
        code: 'api.echoInt32s(Int32List.fromList([-100, 0, 100]))',
        description: 'Zero-copy signed 32-bit integers.',
        run: () => runApi(
          'echoInt32s',
          'echoInt32s(...)',
          () => api.echoInt32s(Int32List.fromList([-100, 0, 100])),
        ),
      ),
      ApiItem(
        name: 'echoInt64s (Int64List)',
        code: 'api.echoInt64s(Int64List.fromList([-1000, 0, 1000]))',
        description: 'Zero-copy signed 64-bit integers.',
        run: () => runApi(
          'echoInt64s',
          'echoInt64s(...)',
          () => api.echoInt64s(Int64List.fromList([-1000, 0, 1000])),
        ),
      ),
      ApiItem(
        name: 'echoDataRecord',
        code: 'api.echoDataRecord(TcDataRecord(...))',
        description: 'Tests record binary codec containing multiple zero-copy TypedData arrays.',
        run: () => runApi(
          'echoDataRecord',
          'echoDataRecord(TcDataRecord(...))',
          () => api.echoDataRecord(
            plugin.TcDataRecord(
              bytes: Uint8List.fromList([255, 128]),
              values: Int32List.fromList([100000, -200000]),
              scores: Float64List.fromList([3.1415, 2.7182]),
              label: 'mixed-typed-data',
            ),
          ),
        ),
      ),
    ],
  );
}
