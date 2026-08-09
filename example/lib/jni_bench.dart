import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nitro/nitro.dart';
import 'package:nitro_type_coverage/nitro_type_coverage.dart' as plugin;

/// Improvement E — Android/JNI bridge benchmark harness.
///
/// The macOS harness in `benchmark/` measures the Swift and direct-C++ paths;
/// nothing measured the **JNI** path, so the Android-specific wins (improvement
/// D — reusing a direct ByteBuffer instead of a per-call `NewByteArray`) had no
/// before/after signal. This screen fills that gap.
///
/// It reports, per case, nanoseconds per call AND the JVM allocation delta —
/// the JNI path's real cost is the garbage it creates (each `NewByteArray` is a
/// JVM heap object), which shows up as GC pressure rather than CPU time.
///
/// Run with: `flutter run --profile --dart-define=JNI_BENCH=true -d <android>`
class JniBenchScreen extends StatefulWidget {
  const JniBenchScreen({super.key});

  @override
  State<JniBenchScreen> createState() => _JniBenchScreenState();
}

class _JniBenchScreenState extends State<JniBenchScreen> {
  static const _jvm = MethodChannel('nitro_type_coverage/jvm_stats');

  final _api = plugin.NitroTypeCoverage.instance;
  final _results = <_Row>[];
  bool _running = false;
  String _status = 'idle';

  @override
  void initState() {
    super.initState();
    NitroConfig.instance
      ..logLevel = NitroLogLevel.error
      ..timelineTracingEnabled = false;
  }

  /// Total bytes the JVM has allocated so far, via a tiny platform hook.
  /// Returns null off-Android (or if the host side isn't wired up), in which
  /// case the harness still reports timings and just omits the alloc column.
  Future<int?> _jvmAllocatedBytes() async {
    try {
      return await _jvm.invokeMethod<int>('allocatedBytes');
    } on Exception {
      return null;
    }
  }

  Future<_Row> _case(String name, int iters, void Function(int i) body) async {
    // Warm up: let the JIT compile the path and the bridge caches fill, so the
    // measured window reflects steady state rather than first-call costs.
    for (var i = 0; i < 2000; i++) {
      body(i);
    }
    final before = await _jvmAllocatedBytes();
    final sw = Stopwatch()..start();
    for (var i = 0; i < iters; i++) {
      body(i);
    }
    sw.stop();
    final after = await _jvmAllocatedBytes();
    final allocPerCall = (before != null && after != null && after >= before)
        ? (after - before) / iters
        : null;
    return _Row(name, sw.elapsedMicroseconds * 1000 / iters, allocPerCall);
  }

  Future<void> _run() async {
    setState(() {
      _running = true;
      _results.clear();
      _status = 'running…';
    });
    const iters = 50000;
    var sink = 0;

    // Scalar floor — primitive JNI args, no marshalling. Everything else is
    // measured relative to this.
    _results.add(await _case('echoInt (scalar floor)', iters, (i) {
      sink += _api.echoInt(i);
    }));

    // Improvement B territory: nullable primitives cross as a byte payload.
    _results.add(await _case('echoNullableInt (B)', iters, (i) {
      sink += _api.echoNullableInt(i) ?? 0;
    }));
    _results.add(await _case('echoNullableDouble (B)', iters, (i) {
      sink += (_api.echoNullableDouble(i.toDouble()) ?? 0).toInt();
    }));

    // Improvement C territory: struct return.
    _results.add(await _case('echoPoint (C)', iters, (i) {
      sink += _api.echoPoint(plugin.TcPoint(x: i.toDouble(), y: 1, z: 2)).x.toInt();
    }));

    // Improvement F territory: string return.
    _results.add(await _case('echoString 32B (F)', iters, (i) {
      sink += _api.echoString('x' * 32).length;
    }));

    // Record round-trip — the binary codec path, unaffected by B/C/F; included
    // so a regression there is visible too.
    _results.add(await _case('echoConfig (record)', iters ~/ 5, (i) {
      sink += _api
          .echoConfig(plugin.TcConfig(name: 'n', count: i, enabled: true, threshold: 1.5))
          .count;
    }));

    if (!mounted) return;
    setState(() {
      _running = false;
      _status = 'done (sink=$sink)';
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('JNI bench (improvement E)')),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ElevatedButton(
                    onPressed: _running ? null : _run,
                    child: Text(_running ? 'running…' : 'Run benchmark'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_status)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                children: [
                  for (final r in _results)
                    ListTile(
                      dense: true,
                      title: Text(r.name),
                      subtitle: Text(
                        '${r.nsPerCall.toStringAsFixed(1)} ns/call'
                        '${r.allocPerCall != null ? '   ·   ${r.allocPerCall!.toStringAsFixed(1)} B/call JVM alloc' : ''}',
                      ),
                    ),
                  if (_results.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'JVM alloc/call is the JNI-specific signal: each per-call '
                        'NewByteArray is JVM garbage. Improvement D targets exactly '
                        'that column.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _Row {
  const _Row(this.name, this.nsPerCall, this.allocPerCall);
  final String name;
  final double nsPerCall;
  final double? allocPerCall;
}
