import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nitro_type_coverage/nitro_type_coverage.dart' as plugin;
import '../models.dart';

typedef ApiRunner = Future<void> Function(String name, String code, FutureOr<dynamic> Function() action);
typedef StreamToggler = void Function(String name, Stream<dynamic> Function() getStream);

ApiSection getStreamsBackpressureSection(plugin.NitroTypeCoverage api, ApiRunner runApi, StreamToggler toggleStream) {
  return ApiSection(
    title: 'Streams & Backpressure',
    icon: Icons.waves_outlined,
    items: [
      ApiItem(
        name: 'Listen: intStream',
        code: 'api.intStream().listen(...)',
        description: 'Starts listening to the 64-bit integer stream.',
        run: () => toggleStream('intStream', () => api.intStream()),
      ),
      ApiItem(
        name: 'Listen: pointStream',
        code: 'api.pointStream().listen(...)',
        description: 'Starts listening to the 3D Point struct stream.',
        run: () => toggleStream('pointStream', () => api.pointStream()),
      ),
      ApiItem(
        name: 'Listen: boolStream',
        code: 'api.boolStream().listen(...)',
        description: 'Starts listening to the boolean stream.',
        run: () => toggleStream('boolStream', () => api.boolStream()),
      ),
      ApiItem(
        name: 'Listen: doubleStream',
        code: 'api.doubleStream().listen(...)',
        description: 'Starts listening to the double stream.',
        run: () => toggleStream('doubleStream', () => api.doubleStream()),
      ),
      ApiItem(
        name: 'Listen: statusStream',
        code: 'api.statusStream().listen(...)',
        description: 'Starts listening to the Status enum stream.',
        run: () => toggleStream('statusStream', () => api.statusStream()),
      ),
      ApiItem(
        name: 'Listen: configStream',
        code: 'api.configStream().listen(...)',
        description: 'Starts listening to the hybrid record config stream.',
        run: () => toggleStream('configStream', () => api.configStream()),
      ),
      ApiItem(
        name: 'Listen: stringStream',
        code: 'api.stringStream().listen(...)',
        description: 'Starts listening to the String stream.',
        run: () => toggleStream('stringStream', () => api.stringStream()),
      ),
      ApiItem(
        name: 'Listen: blockIntStream',
        code: 'api.blockIntStream().listen(...)',
        description: 'Starts listening to the Backpressure.block stream.',
        run: () => toggleStream('blockIntStream', () => api.blockIntStream()),
      ),
      ApiItem(
        name: 'Listen: batchIntStream',
        code: 'api.batchIntStream().listen(...)',
        description: 'Starts listening to the Backpressure.batch (size: 16) int stream.',
        run: () => toggleStream('batchIntStream', () => api.batchIntStream()),
      ),
      ApiItem(
        name: 'Listen: batchDoubleStream',
        code: 'api.batchDoubleStream().listen(...)',
        description: 'Starts listening to the Backpressure.batch double stream.',
        run: () => toggleStream('batchDoubleStream', () => api.batchDoubleStream()),
      ),
      ApiItem(
        name: 'Listen: batchBoolStream',
        code: 'api.batchBoolStream().listen(...)',
        description: 'Starts listening to the Backpressure.batch bool stream.',
        run: () => toggleStream('batchBoolStream', () => api.batchBoolStream()),
      ),
      ApiItem(
        name: 'Configure / Trigger Streams',
        code: 'api.configureStream(...)',
        description: 'Triggers/Configures all active streams to emit test events.',
        run: () => runApi(
          'configureStreams',
          'api.configureXStream(...)',
          () {
            api.configureStream(10, 5);
            api.configureDoubleStream(0.25, 4);
            api.configureStatusStream(3);
            api.configureConfigStream(plugin.TcConfig(name: 'seed', count: 0, enabled: true, threshold: 0.1), 3);
            api.configureStringStream(['a', 'b', 'c', 'd']);
            api.configureBlockIntStream(100, 3);
            api.configureBatchStream(50, 20);
            api.configureBatchDoubleStream([1.5, 2.5, 3.5, 4.5]);
            api.configureBatchBoolStream([true, false, true, true]);
            return 'All stream configurations invoked!';
          },
        ),
      ),
    ],
  );
}
