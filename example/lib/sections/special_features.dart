import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nitro/nitro.dart';
import 'package:nitro_type_coverage/nitro_type_coverage.dart' as plugin;
import '../models.dart';

typedef ApiRunner = Future<void> Function(String name, String code, FutureOr<dynamic> Function() action);

ApiSection getSpecialFeaturesSection(plugin.NitroTypeCoverage api, ApiRunner runApi) {
  return ApiSection(
    title: 'Owned, Variant & Result',
    icon: Icons.verified_user_outlined,
    items: [
      ApiItem(
        name: 'acquireBuffer',
        code: 'api.acquireBuffer(1024)',
        description: 'Allocates buffer native-side, returning an opaque NativeHandle.',
        run: () => runApi('acquireBuffer', 'acquireBuffer(1024)', () => api.acquireBuffer(1024)),
      ),
      ApiItem(
        name: 'asyncAcquireBuffer',
        code: 'await api.asyncAcquireBuffer(2048)',
        description: 'Allocates buffer async native-side, returning NativeHandle.',
        run: () => runApi('asyncAcquireBuffer', 'asyncAcquireBuffer(2048)', () => api.asyncAcquireBuffer(2048)),
      ),
      ApiItem(
        name: 'echoEvent (TcEventTap)',
        code: 'api.echoEvent(TcEventTap(x: 10, y: 20))',
        description: 'Sends and echoes a sealed class variant event Tap.',
        run: () => runApi(
          'echoEvent',
          'echoEvent(TcEventTap)',
          () => api.echoEvent(const plugin.TcEventTap(x: 10, y: 20)),
        ),
      ),
      ApiItem(
        name: 'echoEvent (TcEventScroll)',
        code: 'api.echoEvent(TcEventScroll(delta: -2.5))',
        description: 'Sends and echoes a sealed class variant event Scroll.',
        run: () => runApi(
          'echoEvent',
          'echoEvent(TcEventScroll)',
          () => api.echoEvent(const plugin.TcEventScroll(delta: -2.5)),
        ),
      ),
      ApiItem(
        name: 'echoEvent (TcEventResize)',
        code: 'api.echoEvent(TcEventResize(width: 800, height: 600))',
        description: 'Sends and echoes a sealed class variant event Resize.',
        run: () => runApi(
          'echoEvent',
          'echoEvent(TcEventResize)',
          () => api.echoEvent(const plugin.TcEventResize(width: 800, height: 600)),
        ),
      ),
      ApiItem(
        name: 'echoEvent (TcEventNullable)',
        code: 'api.echoEvent(TcEventNullable(count: null, ...))',
        description: 'Sends and echoes a variant event containing nullable fields.',
        run: () => runApi(
          'echoEvent',
          'echoEvent(TcEventNullable)',
          () => api.echoEvent(const plugin.TcEventNullable(count: null, status: null, config: null, samples: null)),
        ),
      ),
      ApiItem(
        name: 'asyncEchoEvent',
        code: 'await api.asyncEchoEvent(TcEventTap(x: 5, y: 5))',
        description: 'Echoes a variant event in a background thread.',
        run: () => runApi(
          'asyncEchoEvent',
          'asyncEchoEvent(...)',
          () => api.asyncEchoEvent(const plugin.TcEventTap(x: 5, y: 5)),
        ),
      ),
      ApiItem(
        name: 'safeDiv (OK)',
        code: 'api.safeDiv(10, 2)',
        description: 'Returns NitroResultValue: NitroOk(5.0).',
        run: () => runApi('safeDiv', 'safeDiv(10, 2)', () => api.safeDiv(10.0, 2.0)),
      ),
      ApiItem(
        name: 'safeDiv (Error)',
        code: 'api.safeDiv(10, 0)',
        description: 'Returns NitroResultValue: NitroErr("division by zero").',
        run: () => runApi('safeDiv', 'safeDiv(10, 0)', () => api.safeDiv(10.0, 0.0)),
      ),
      ApiItem(
        name: 'asyncSafeDiv',
        code: 'await api.asyncSafeDiv(15, 0)',
        description: 'Asynchronous safe division returning a Result class.',
        run: () => runApi('asyncSafeDiv', 'asyncSafeDiv(...)', () => api.asyncSafeDiv(15.0, 0.0)),
      ),
      ApiItem(
        name: 'validateLabel (OK)',
        code: 'api.validateLabel("  valid  ")',
        description: 'Returns NitroOk with trimmed label.',
        run: () => runApi('validateLabel', 'validateLabel(...)', () => api.validateLabel('  valid  ')),
      ),
      ApiItem(
        name: 'validateLabel (Error)',
        code: 'api.validateLabel("")',
        description: 'Returns NitroErr with empty label error.',
        run: () => runApi('validateLabel', 'validateLabel("")', () => api.validateLabel('')),
      ),
      ApiItem(
        name: 'asyncValidateLabel',
        code: 'await api.asyncValidateLabel("")',
        description: 'Asynchronous label validation returning a Result.',
        run: () => runApi('asyncValidateLabel', 'asyncValidateLabel(...)', () => api.asyncValidateLabel('')),
      ),
      ApiItem(
        name: 'echoNullableIntSafe',
        code: 'api.echoNullableIntSafe(NitroNullableInt.fromNullable(42))',
        description: 'Tests safe binary collision-free Nullable Int.',
        run: () => runApi(
          'echoNullableIntSafe',
          'echoNullableIntSafe(...)',
          () => api.echoNullableIntSafe(NitroNullableInt.fromNullable(42)),
        ),
      ),
      ApiItem(
        name: 'echoNullableDoubleSafe',
        code: 'api.echoNullableDoubleSafe(NitroNullableDouble.fromNullable(null))',
        description: 'Tests safe binary collision-free Nullable Double (null).',
        run: () => runApi(
          'echoNullableDoubleSafe',
          'echoNullableDoubleSafe(null)',
          () => api.echoNullableDoubleSafe(NitroNullableDouble.fromNullable(null)),
        ),
      ),
      ApiItem(
        name: 'echoNullableBoolSafe',
        code: 'api.echoNullableBoolSafe(NitroNullableBool.fromNullable(true))',
        description: 'Tests safe binary collision-free Nullable Bool.',
        run: () => runApi(
          'echoNullableBoolSafe',
          'echoNullableBoolSafe(true)',
          () => api.echoNullableBoolSafe(NitroNullableBool.fromNullable(true)),
        ),
      ),
    ],
  );
}
