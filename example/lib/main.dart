import 'dart:async';
import 'dart:typed_data';
import 'package:nitro/nitro.dart';
import 'package:flutter/material.dart';
import 'package:nitro_type_coverage/nitro_type_coverage.dart' as plugin;
import 'package:signals_flutter/signals_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  NitroConfig.instance
    ..debugMode = true
    ..timelineTracingEnabled = true
    ..isolatePoolSize = 4
    ..logLevel = NitroLogLevel.verbose
    ..slowCallThresholdUs = 16000;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NitroTypeCoverage Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.deepPurple),
      home: const _DemoPage(),
    );
  }
}

class _DemoPage extends StatefulWidget {
  const _DemoPage();
  @override
  State<_DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<_DemoPage> {
  final _result = signal<String>('—');
  final _loading = signal<bool>(false);

  plugin.NitroTypeCoverage get _api => plugin.NitroTypeCoverage.instance;

  // ── Primitives ────────────────────────────────────────────────────────────

  Future<void> _echoInt() async {
    final v = _api.echoInt(42);
    _result.value = 'echoInt(42) = $v';
  }

  Future<void> _echoDouble() async {
    final v = _api.echoDouble(3.14);
    _result.value = 'echoDouble(3.14) = $v';
  }

  Future<void> _echoBool() async {
    final v = _api.echoBool(true);
    _result.value = 'echoBool(true) = $v';
  }

  Future<void> _echoString() async {
    final v = _api.echoString('Hello Nitro');
    _result.value = 'echoString("Hello Nitro") = $v';
  }

  // ── Multi-param ──────────────────────────────────────────────────────────

  Future<void> _addInts() async {
    final v = _api.addInts(1, 2, 3);
    _result.value = 'addInts(1, 2, 3) = $v';
  }

  Future<void> _mulDoubles() async {
    final v = _api.mulDoubles(2.5, 4.0);
    _result.value = 'mulDoubles(2.5, 4.0) = $v';
  }

  Future<void> _joinStrings() async {
    final v = _api.joinStrings('Hello', 'World', ' ');
    _result.value = 'joinStrings("Hello", "World", " ") = $v';
  }

  // ── Nullable ─────────────────────────────────────────────────────────────

  Future<void> _echoNullableInt() async {
    final v = _api.echoNullableInt(null);
    _result.value = 'echoNullableInt(null) = $v';
  }

  Future<void> _echoNullableDouble() async {
    final v = _api.echoNullableDouble(2.718);
    _result.value = 'echoNullableDouble(2.718) = $v';
  }

  Future<void> _echoNullableBool() async {
    final v = _api.echoNullableBool(null);
    _result.value = 'echoNullableBool(null) = $v';
  }

  Future<void> _echoNullableString() async {
    final v = _api.echoNullableString('nullable');
    _result.value = 'echoNullableString("nullable") = $v';
  }

  // ── Enum ─────────────────────────────────────────────────────────────────

  Future<void> _echoStatus() async {
    final v = _api.echoStatus(plugin.TcStatus.ok);
    _result.value = 'echoStatus(TcStatus.ok) = ${v.name}';
  }

  Future<void> _echoNullableStatus() async {
    final v = _api.echoNullableStatus(plugin.TcStatus.pending);
    _result.value = 'echoNullableStatus(TcStatus.pending) = ${v?.name}';
  }

  // ── Struct ───────────────────────────────────────────────────────────────

  Future<void> _echoPoint() async {
    final v = _api.echoPoint(plugin.TcPoint(x: 1.0, y: 2.0, z: 3.0));
    _result.value = 'echoPoint(1,2,3) = (${v.x}, ${v.y}, ${v.z})';
  }

  // ── Record ───────────────────────────────────────────────────────────────

  Future<void> _echoConfig() async {
    final v = _api.echoConfig(
      plugin.TcConfig(name: 'test', count: 10, enabled: true, threshold: 0.5),
    );
    _result.value =
        'echoConfig(name:${v.name}, count:${v.count}, enabled:${v.enabled})';
  }

  // ── TypedData (zero-copy) ────────────────────────────────────────────────

  Future<void> _echoBytes() async {
    final v = _api.echoBytes(Uint8List.fromList([1, 2, 3, 4]));
    _result.value = 'echoBytes([1,2,3,4]) = $v';
  }

  Future<void> _echoFloats() async {
    final v = _api.echoFloats(Float32List.fromList([1.1, 2.2, 3.3]));
    _result.value = 'echoFloats([1.1,2.2,3.3]) = $v';
  }

  Future<void> _echoFloat64s() async {
    final v = _api.echoFloat64s(Float64List.fromList([1.1, 2.2, 3.3]));
    _result.value = 'echoFloat64s([1.1,2.2,3.3]) = $v';
  }

  Future<void> _echoInt32s() async {
    final v = _api.echoInt32s(Int32List.fromList([10, 20, 30]));
    _result.value = 'echoInt32s([10,20,30]) = $v';
  }

  // ── Lists (async) ────────────────────────────────────────────────────────

  Future<void> _echoIntList() async {
    final v = await _api.echoIntList([1, 2, 3]);
    _result.value = 'echoIntList([1,2,3]) = $v';
  }

  Future<void> _echoDoubleList() async {
    final v = await _api.echoDoubleList([1.1, 2.2]);
    _result.value = 'echoDoubleList([1.1,2.2]) = $v';
  }

  Future<void> _echoStringList() async {
    final v = await _api.echoStringList(['a', 'b', 'c']);
    _result.value = 'echoStringList(["a","b","c"]) = $v';
  }

  Future<void> _echoConfigList() async {
    final v = await _api.echoConfigList([
      plugin.TcConfig(name: 'x', count: 1, enabled: false, threshold: 0.1),
      plugin.TcConfig(name: 'y', count: 2, enabled: true, threshold: 0.9),
    ]);
    _result.value = 'echoConfigList([2 configs]) = ${v.length} items';
  }

  // ── Async primitives ─────────────────────────────────────────────────────

  Future<void> _asyncInt() async {
    final v = await _api.asyncInt(100);
    _result.value = 'asyncInt(100) = $v';
  }

  Future<void> _asyncDouble() async {
    final v = await _api.asyncDouble(9.99);
    _result.value = 'asyncDouble(9.99) = $v';
  }

  Future<void> _asyncBool() async {
    final v = await _api.asyncBool(false);
    _result.value = 'asyncBool(false) = $v';
  }

  Future<void> _asyncString() async {
    final v = await _api.asyncString('async-hello');
    _result.value = 'asyncString("async-hello") = $v';
  }

  Future<void> _asyncConfig() async {
    final v = await _api.asyncConfig(
      plugin.TcConfig(name: 'async', count: 7, enabled: true, threshold: 0.3),
    );
    _result.value = 'asyncConfig(name:${v.name}) = ${v.count}';
  }

  // ── Async nullable ───────────────────────────────────────────────────────

  Future<void> _asyncNullableInt() async {
    final v = await _api.asyncNullableInt(null);
    _result.value = 'asyncNullableInt(null) = $v';
  }

  Future<void> _asyncNullableString() async {
    final v = await _api.asyncNullableString('hi');
    _result.value = 'asyncNullableString("hi") = $v';
  }

  // ── Callback ─────────────────────────────────────────────────────────────

  Future<void> _onIntEvent() async {
    _api.onIntEvent((value) {
      _result.value = 'onIntEvent callback: $value';
    });
    _result.value = 'onIntEvent registered ✓';
  }

  // ── Properties ───────────────────────────────────────────────────────────

  Future<void> _getSetPrecision() async {
    _api.precision = 42;
    final v = _api.precision;
    _result.value = 'precision get/set = $v';
  }

  Future<void> _getSetTag() async {
    _api.tag = 'demo-tag';
    final v = _api.tag;
    _result.value = 'tag get/set = "$v"';
  }

  Future<void> _getSetNullableRate() async {
    _api.nullableRate = 0.75;
    final v = _api.nullableRate;
    _result.value = 'nullableRate get/set = $v';
  }

  Future<void> _getSetEnabled() async {
    _api.enabled = true;
    final v = _api.enabled;
    _result.value = 'enabled get/set = $v';
  }

  Future<void> _getSetCurrentStatus() async {
    _api.currentStatus = plugin.TcStatus.ok;
    final v = _api.currentStatus;
    _result.value = 'currentStatus get/set = ${v.name}';
  }

  // ── Streams ──────────────────────────────────────────────────────────────

  StreamSubscription<int>? _intSub;
  Future<void> _listenIntStream() async {
    _intSub?.cancel();
    _intSub = _api.intStream().listen((v) {
      _result.value = 'intStream: $v';
    });
    _result.value = 'intStream listening ✓';
  }

  StreamSubscription<plugin.TcPoint>? _pointSub;
  Future<void> _listenPointStream() async {
    _pointSub?.cancel();
    _pointSub = _api.pointStream().listen((v) {
      _result.value = 'pointStream: (${v.x}, ${v.y}, ${v.z})';
    });
    _result.value = 'pointStream listening ✓';
  }

  StreamSubscription<bool>? _boolSub;
  Future<void> _listenBoolStream() async {
    _boolSub?.cancel();
    _boolSub = _api.boolStream().listen((v) {
      _result.value = 'boolStream: $v';
    });
    _result.value = 'boolStream listening ✓';
  }

  Future<void> _configureStream() async {
    _api.configureStream(0, 5);
    _result.value =
        'configureStream(from:0, count:5) ✓ — check stream listeners';
  }

  Future<void> _cancelStreams() async {
    _intSub?.cancel();
    _pointSub?.cancel();
    _boolSub?.cancel();
    _intSub = null;
    _pointSub = null;
    _boolSub = null;
    _result.value = 'all streams cancelled ✓';
  }

  // ── Error handling ───────────────────────────────────────────────────────

  Future<void> _throwNative() async {
    try {
      _api.throwNative('test error');
    } catch (e) {
      _result.value = 'throwNative caught: $e';
    }
  }

  Future<void> _throwNativeAsync() async {
    try {
      await _api.throwNativeAsync('async error');
    } catch (e) {
      _result.value = 'throwNativeAsync caught: $e';
    }
  }

  @override
  void dispose() {
    _intSub?.cancel();
    _pointSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NitroTypeCoverage Demo')),
      body: Column(
        children: [
          // Result banner
          SignalBuilder(
            builder: (c) => Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: _loading.value
                  ? Colors.amber.shade100
                  : Colors.green.shade50,
              child: Text(
                _result.value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          if (_loading.value) const LinearProgressIndicator(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: [
                _section('Primitives (sync)', [
                  _btn('echoInt(42)', _echoInt),
                  _btn('echoDouble(3.14)', _echoDouble),
                  _btn('echoBool(true)', _echoBool),
                  _btn('echoString', _echoString),
                ]),
                _section('Multi-param (sync)', [
                  _btn('addInts(1,2,3)', _addInts),
                  _btn('mulDoubles(2.5,4)', _mulDoubles),
                  _btn('joinStrings', _joinStrings),
                ]),
                _section('Nullable (sync)', [
                  _btn('echoNullableInt(null)', _echoNullableInt),
                  _btn('echoNullableDouble(2.718)', _echoNullableDouble),
                  _btn('echoNullableBool(null)', _echoNullableBool),
                  _btn('echoNullableString', _echoNullableString),
                ]),
                _section('Enum', [
                  _btn('echoStatus(ok)', _echoStatus),
                  _btn('echoNullableStatus(pending)', _echoNullableStatus),
                ]),
                _section('Struct / Record', [
                  _btn('echoPoint(1,2,3)', _echoPoint),
                  _btn('echoConfig(test,10)', _echoConfig),
                ]),
                _section('TypedData (zero-copy)', [
                  _btn('echoBytes([1,2,3,4])', _echoBytes),
                  _btn('echoFloats([1.1,2.2,3.3])', _echoFloats),
                  _btn('echoFloat64s', _echoFloat64s),
                  _btn('echoInt32s([10,20,30])', _echoInt32s),
                ]),
                _section('Lists (async)', [
                  _btn('echoIntList', _echoIntList),
                  _btn('echoDoubleList', _echoDoubleList),
                  _btn('echoStringList', _echoStringList),
                  _btn('echoConfigList', _echoConfigList),
                ]),
                _section('Async primitives', [
                  _btn('asyncInt(100)', _asyncInt),
                  _btn('asyncDouble(9.99)', _asyncDouble),
                  _btn('asyncBool(false)', _asyncBool),
                  _btn('asyncString', _asyncString),
                  _btn('asyncConfig', _asyncConfig),
                ]),
                _section('Async nullable', [
                  _btn('asyncNullableInt(null)', _asyncNullableInt),
                  _btn('asyncNullableString("hi")', _asyncNullableString),
                ]),
                _section('Callback', [
                  _btn('onIntEvent register', _onIntEvent),
                ]),
                _section('Properties', [
                  _btn('precision get/set', _getSetPrecision),
                  _btn('tag get/set', _getSetTag),
                  _btn('nullableRate get/set', _getSetNullableRate),
                  _btn('enabled get/set', _getSetEnabled),
                  _btn('currentStatus get/set', _getSetCurrentStatus),
                ]),
                _section('Streams', [
                  _btn('listen intStream', _listenIntStream),
                  _btn('listen pointStream', _listenPointStream),
                  _btn('listen boolStream', _listenBoolStream),
                  _btn('▶ configureStream(0,5)', _configureStream),
                  _btn('cancel all streams', _cancelStreams),
                ]),
                _section('Error handling', [
                  _btn('throwNative', _throwNative),
                  _btn('throwNativeAsync', _throwNativeAsync),
                ]),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: children),
            ],
          ),
        ),
      ),
    );
  }

  // Accept FutureOr<void> so both sync and async handlers work and are awaited.
  Widget _btn(String label, Future<void> Function()? onPressed) {
    return ElevatedButton(
      onPressed: onPressed == null
          ? null
          : () async {
              _loading.value = true;
              try {
                await onPressed();
              } catch (e) {
                _result.value = 'ERROR: $e';
              } finally {
                _loading.value = false;
              }
            },
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}
