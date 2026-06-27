import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nitro_type_coverage/nitro_type_coverage.dart' as plugin;
import '../models.dart';

typedef ApiRunner = Future<void> Function(String name, String code, FutureOr<dynamic> Function() action);
typedef LogCallback = void Function(String message);

ApiSection getCallbacksSection(plugin.NitroTypeCoverage api, ApiRunner runApi, LogCallback log) {
  return ApiSection(
    title: 'Bidirectional Callbacks',
    icon: Icons.swap_calls_outlined,
    items: [
      ApiItem(
        name: 'onIntEvent',
        code: 'api.onIntEvent((val) => log(val))',
        description: 'Registers callback to receive int events from native.',
        run: () => runApi(
          'onIntEvent',
          'onIntEvent(callback)',
          () {
            api.onIntEvent((val) {
              log('[Callback] onIntEvent triggered with: $val');
            });
            return 'Registered onIntEvent callback';
          },
        ),
      ),
      ApiItem(
        name: 'onBoolEvent',
        code: 'api.onBoolEvent((val) => log(val))',
        description: 'Registers callback to receive bool events from native.',
        run: () => runApi(
          'onBoolEvent',
          'onBoolEvent(callback)',
          () {
            api.onBoolEvent((val) {
              log('[Callback] onBoolEvent triggered with: $val');
            });
            return 'Registered onBoolEvent callback';
          },
        ),
      ),
      ApiItem(
        name: 'onDoubleEvent',
        code: 'api.onDoubleEvent((val) => log(val))',
        description: 'Registers callback to receive double events from native.',
        run: () => runApi(
          'onDoubleEvent',
          'onDoubleEvent(callback)',
          () {
            api.onDoubleEvent((val) {
              log('[Callback] onDoubleEvent triggered with: $val');
            });
            return 'Registered onDoubleEvent callback';
          },
        ),
      ),
      ApiItem(
        name: 'onPointEvent',
        code: 'api.onPointEvent((val) => log(val))',
        description: 'Registers callback to receive TcPoint struct events from native.',
        run: () => runApi(
          'onPointEvent',
          'onPointEvent(callback)',
          () {
            api.onPointEvent((val) {
              log('[Callback] onPointEvent triggered with point: (${val.x}, ${val.y}, ${val.z})');
            });
            return 'Registered onPointEvent callback';
          },
        ),
      ),
      ApiItem(
        name: 'onDetailEvent',
        code: 'api.onDetailEvent((id, score) => log(id, score))',
        description: 'Registers callback receiving multiple parameters (int, double).',
        run: () => runApi(
          'onDetailEvent',
          'onDetailEvent(callback)',
          () {
            api.onDetailEvent((id, score) {
              log('[Callback] onDetailEvent triggered with id: $id, score: $score');
            });
            return 'Registered onDetailEvent callback';
          },
        ),
      ),
      ApiItem(
        name: 'onTransformEvent (int -> int)',
        code: 'api.onTransformEvent((val) => val * 2)',
        description: 'Registers callback that computes and returns an int value to native.',
        run: () => runApi(
          'onTransformEvent',
          'onTransformEvent((v) => v * 2)',
          () {
            api.onTransformEvent((val) {
              final res = val * 2;
              log('[Callback] onTransformEvent triggered ($val) -> returning $res');
              return res;
            });
            return 'Registered onTransformEvent callback';
          },
        ),
      ),
      ApiItem(
        name: 'onStringTransform (int -> String)',
        code: 'api.onStringTransform((val) => "val: \$val")',
        description: 'Registers callback returning a String value to native.',
        run: () => runApi(
          'onStringTransform',
          'onStringTransform(...)',
          () {
            api.onStringTransform((val) {
              final res = 'String val is $val';
              log('[Callback] onStringTransform triggered ($val) -> returning "$res"');
              return res;
            });
            return 'Registered onStringTransform callback';
          },
        ),
      ),
      ApiItem(
        name: 'onDoubleTransform (int -> double)',
        code: 'api.onDoubleTransform((val) => val * 1.5)',
        description: 'Registers callback returning a double value to native.',
        run: () => runApi(
          'onDoubleTransform',
          'onDoubleTransform(...)',
          () {
            api.onDoubleTransform((val) {
              final res = val * 1.5;
              log('[Callback] onDoubleTransform triggered ($val) -> returning $res');
              return res;
            });
            return 'Registered onDoubleTransform callback';
          },
        ),
      ),
      ApiItem(
        name: 'onBoolTransform (int -> bool)',
        code: 'api.onBoolTransform((val) => val % 2 == 0)',
        description: 'Registers callback returning a bool value to native.',
        run: () => runApi(
          'onBoolTransform',
          'onBoolTransform(...)',
          () {
            api.onBoolTransform((val) {
              final res = val % 2 == 0;
              log('[Callback] onBoolTransform triggered ($val) -> returning $res');
              return res;
            });
            return 'Registered onBoolTransform callback';
          },
        ),
      ),
      ApiItem(
        name: 'onStatusTransform (int -> TcStatus)',
        code: 'api.onStatusTransform((val) => Status)',
        description: 'Registers callback returning a Status enum to native.',
        run: () => runApi(
          'onStatusTransform',
          'onStatusTransform(...)',
          () {
            api.onStatusTransform((val) {
              final res = val % 2 == 0 ? plugin.TcStatus.ok : plugin.TcStatus.error;
              log('[Callback] onStatusTransform triggered ($val) -> returning ${res.name}');
              return res;
            });
            return 'Registered onStatusTransform callback';
          },
        ),
      ),
    ],
  );
}
