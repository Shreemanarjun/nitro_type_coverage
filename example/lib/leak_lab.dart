// Leak Lab — an on-device screen that soaks the leak-prone paths (single- and
// multi-instance lifecycles, streams, and batch multi-streams) while showing
// live RSS, GC-collection counts, and a bounded-growth verdict. Pair with
// Flutter DevTools → Memory (profile mode) for the retaining-path / allocation
// view. Uses leak_tracker.forceGC() for a real GC when checking collection.
import 'dart:async';
import 'dart:io' show ProcessInfo;

import 'package:flutter/material.dart';
import 'package:leak_tracker/leak_tracker.dart';
import 'package:nitro_type_coverage/nitro_type_coverage.dart' as plugin;

class LeakLabScreen extends StatefulWidget {
  const LeakLabScreen({super.key, this.autoRun = false});

  /// When true, all soaks run automatically shortly after the screen appears
  /// (used for headless capture on iOS/macOS via --dart-define=LEAKLAB_AUTORUN).
  final bool autoRun;

  @override
  State<LeakLabScreen> createState() => _LeakLabScreenState();
}

class _LeakLabScreenState extends State<LeakLabScreen> {
  final List<String> _log = [];
  final List<int> _rss = []; // rolling RSS samples (MB)
  int _peakMB = 0;
  int _baselineMB = 0;
  bool _running = false;
  String _current = 'idle';
  String _verdict = 'Run a soak, then check Memory in DevTools';
  Timer? _sampler;

  int get _rssMB => (ProcessInfo.currentRss / (1024 * 1024)).round();

  @override
  void initState() {
    super.initState();
    _baselineMB = _rssMB;
    _peakMB = _baselineMB;
    // Live RSS sampler so the chart moves during and between soaks.
    _sampler = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(_sample);
    });
    if (widget.autoRun) {
      Future<void>.delayed(const Duration(milliseconds: 800), () {
        if (mounted) _runAll();
      });
    }
  }

  @override
  void dispose() {
    _sampler?.cancel();
    super.dispose();
  }

  void _sample() {
    final mb = _rssMB;
    _rss.add(mb);
    if (mb > _peakMB) _peakMB = mb;
    if (_rss.length > 80) _rss.removeAt(0);
  }

  void _logLine(String s) {
    _log.insert(0, s);
    if (_log.length > 60) _log.removeLast();
  }

  Future<void> _guarded(String name, Future<(bool, String)> Function() body) async {
    if (_running) return;
    setState(() {
      _running = true;
      _current = name;
    });
    _sample();
    try {
      // Each soak decides its own pass criterion: multi-instance is judged by
      // GC collection (forceGC inflates RSS, so RSS isn't a fair bound there);
      // the others by bounded RSS growth. A real per-iteration leak would grow
      // RSS by hundreds of MB, far past any debug-mode overhead.
      final (pass, detail) = await body();
      _sample();
      _logLine('${pass ? "PASS " : "CHECK"} $name — $detail');
      setState(() => _verdict = '${pass ? 'PASS' : 'CHECK'} · $name · $detail');
    } catch (e, st) {
      _logLine('ERROR $name: $e');
      setState(() => _verdict = 'ERROR · $name · $e');
      debugPrint('$st');
    } finally {
      setState(() {
        _running = false;
        _current = 'idle';
      });
    }
  }

  // ── Soaks ────────────────────────────────────────────────────────────────

  // Bounded RSS growth — a per-iteration leak over these iteration counts would
  // grow RSS by hundreds of MB, far past debug-mode/JIT overhead.
  static const _rssBoundMB = 60;
  String _dsign(int g) => 'RSS Δ${g >= 0 ? '+' : ''}${g}MB';

  Future<(bool, String)> _singleInstance() async {
    final api = plugin.NitroTypeCoverage.instance;
    final rss0 = _rssMB;
    const n = 50000;
    for (var i = 0; i < n; i++) {
      api.echoInt(i);
      api.echoString('s$i');
      if (i % 5000 == 0) {
        _sample();
        if (mounted) setState(() {});
        await Future<void>.delayed(Duration.zero);
      }
    }
    final g = _rssMB - rss0;
    return (g <= _rssBoundMB, 'singleton × $n · ${_dsign(g)}');
  }

  Future<(bool, String)> _multiInstance() async {
    const n = 500;
    final weaks = <WeakReference<Object>>[];
    for (var i = 0; i < n; i++) {
      final inst = plugin.NitroTypeCoverage.getInstance('leaklab-$i');
      inst.echoInt(i); // fully init (native instance created)
      weaks.add(WeakReference<Object>(inst));
      if (i % 100 == 0) {
        _sample();
        if (mounted) setState(() {});
        await Future<void>.delayed(Duration.zero);
      }
    }
    // Every `inst` is now out of scope; a strong cache would pin them.
    await forceGC(fullGcCycles: 4, timeout: const Duration(seconds: 20));
    _sample();
    final live = weaks.where((w) => w.target != null).length;
    final collected = n - live;
    // Judged by COLLECTION (not RSS — forceGC inflates RSS): the weak cache +
    // non-capturing finalizer must let dropped instances go.
    return (collected >= (n * 0.9).round(), '$n keyed instances · $collected GC-collected · $live live');
  }

  Future<(bool, String)> _streams() async {
    final api = plugin.NitroTypeCoverage.instance;
    final rss0 = _rssMB;
    const rounds = 200;
    var events = 0;
    final seed = plugin.TcConfig(name: 'x' * 100, count: 0, enabled: true, threshold: 0.5);
    for (var r = 0; r < rounds; r++) {
      final done = Completer<void>();
      var got = 0;
      final sub = api.configStream().listen((_) {
        events++;
        if (++got >= 20 && !done.isCompleted) done.complete();
      });
      await Future<void>.delayed(const Duration(milliseconds: 2));
      api.configureConfigStream(seed, 20);
      await done.future.timeout(const Duration(seconds: 3), onTimeout: () {});
      await sub.cancel();
      if (r % 20 == 0) {
        _sample();
        if (mounted) setState(() {});
      }
    }
    final g = _rssMB - rss0;
    return (g <= _rssBoundMB, '$rounds × subscribe→emit(20)→cancel · $events events · ${_dsign(g)}');
  }

  Future<(bool, String)> _batchStreams() async {
    final api = plugin.NitroTypeCoverage.instance;
    final rss0 = _rssMB;
    const rounds = 200;
    var events = 0;
    final doubles = List<double>.generate(16, (i) => i * 1.5);
    final bools = List<bool>.generate(16, (i) => i.isEven);
    for (var r = 0; r < rounds; r++) {
      final done = Completer<void>();
      var got = 0;
      void tick() {
        events++;
        if (++got >= 48 && !done.isCompleted) done.complete(); // 16 × 3 streams
      }

      final subs = <StreamSubscription<dynamic>>[
        api.batchIntStream().listen((_) => tick()),
        api.batchDoubleStream().listen((_) => tick()),
        api.batchBoolStream().listen((_) => tick()),
      ];
      await Future<void>.delayed(const Duration(milliseconds: 2));
      api.configureBatchStream(0, 16);
      api.configureBatchDoubleStream(doubles);
      api.configureBatchBoolStream(bools);
      await done.future.timeout(const Duration(seconds: 3), onTimeout: () {});
      for (final s in subs) {
        await s.cancel();
      }
      if (r % 20 == 0) {
        _sample();
        if (mounted) setState(() {});
      }
    }
    final g = _rssMB - rss0;
    return (g <= _rssBoundMB, '$rounds rounds × 3 batch streams (16) · $events items · ${_dsign(g)}');
  }

  Future<void> _runAll() async {
    await _guarded('Single-instance', _singleInstance);
    await _guarded('Multi-instance', _multiInstance);
    await _guarded('Streams', _streams);
    await _guarded('Batch streams', _batchStreams);
  }

  // ── UI ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final growth = _rssMB - _baselineMB;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leak Lab'),
        backgroundColor: cs.surfaceContainerHighest,
        actions: [
          if (_running)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
            ),
        ],
      ),
      body: Column(
        children: [
          _metricsCard(cs, growth),
          _sparkline(cs),
          _buttons(cs),
          const Divider(height: 1),
          Expanded(child: _logView(cs)),
        ],
      ),
    );
  }

  Widget _metricsCard(ColorScheme cs, int growth) {
    final ok = _verdict.startsWith('PASS');
    final err = _verdict.startsWith('ERROR');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: cs.surfaceContainerHigh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _metric('RSS', '$_rssMB MB', cs),
              _metric('peak', '$_peakMB MB', cs),
              _metric('Δ baseline', '${growth >= 0 ? '+' : ''}$growth MB', cs),
              _metric('state', _current, cs),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: err
                  ? cs.errorContainer
                  : ok
                      ? Colors.green.withValues(alpha: 0.18)
                      : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_verdict, style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value, ColorScheme cs) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      );

  Widget _sparkline(ColorScheme cs) => Container(
        height: 56,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        color: cs.surface,
        child: CustomPaint(painter: _RssPainter(List.of(_rss), cs.primary)),
      );

  Widget _buttons(ColorScheme cs) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _running ? null : _runAll,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Run all'),
            ),
            OutlinedButton(onPressed: _running ? null : () => _guarded('Single-instance', _singleInstance), child: const Text('Single ×50k')),
            OutlinedButton(onPressed: _running ? null : () => _guarded('Multi-instance', _multiInstance), child: const Text('Multi ×500 (+GC)')),
            OutlinedButton(onPressed: _running ? null : () => _guarded('Streams', _streams), child: const Text('Streams ×200')),
            OutlinedButton(onPressed: _running ? null : () => _guarded('Batch streams', _batchStreams), child: const Text('Batch ×200')),
            TextButton.icon(
              onPressed: _running
                  ? null
                  : () async {
                      await forceGC(fullGcCycles: 3, timeout: const Duration(seconds: 8));
                      _sample();
                      _logLine('forceGC · RSS now $_rssMB MB');
                      setState(() {});
                    },
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text('Force GC'),
            ),
          ],
        ),
      );

  Widget _logView(ColorScheme cs) => ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _log.length,
        itemBuilder: (_, i) {
          final line = _log[i];
          final color = line.startsWith('PASS')
              ? Colors.green
              : line.startsWith('CHECK') || line.startsWith('ERROR')
                  ? cs.error
                  : cs.onSurfaceVariant;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Text(line, style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: color)),
          );
        },
      );
}

class _RssPainter extends CustomPainter {
  _RssPainter(this.samples, this.color);
  final List<int> samples;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.length < 2) return;
    final maxV = samples.reduce((a, b) => a > b ? a : b).toDouble();
    final minV = samples.reduce((a, b) => a < b ? a : b).toDouble();
    final range = (maxV - minV).clamp(1, double.infinity);
    final dx = size.width / (samples.length - 1);
    final path = Path();
    for (var i = 0; i < samples.length; i++) {
      final x = i * dx;
      final y = size.height - ((samples[i] - minV) / range) * size.height;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(path, Paint()..color = color..strokeWidth = 2..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(_RssPainter old) => old.samples.length != samples.length || old.samples.lastOrNull != samples.lastOrNull;
}
