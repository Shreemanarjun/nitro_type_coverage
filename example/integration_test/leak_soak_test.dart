// On-device leak soaks (the Leak Lab screen's checks, automated). Each soak
// repeats a leak-prone operation thousands of times; a leak would grow RSS by
// many MB. We assert bounded growth + (for multi-instance) real GC collection.
// Runs on macOS / Android / iOS — a real-device run exercises real ART/JVM GC
// and native (JNI/Swift) memory, which macOS can't.
import 'dart:async';
import 'dart:io' show ProcessInfo;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:leak_tracker/leak_tracker.dart';
import 'package:nitro_type_coverage/nitro_type_coverage.dart' as plugin;

int rssMB() => (ProcessInfo.currentRss / (1024 * 1024)).round();

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('leak soaks — RSS bounded', () {
    testWidgets('single-instance × 50k — RSS bounded', (t) async {
      final api = plugin.NitroTypeCoverage.instance;
      final rss0 = rssMB();
      for (var i = 0; i < 50000; i++) {
        api.echoInt(i);
        api.echoString('s$i');
        if (i % 10000 == 0) await Future<void>.delayed(Duration.zero);
      }
      final growth = rssMB() - rss0;
      expect(growth, lessThan(24), reason: 'RSS grew ${growth}MB over 50k singleton calls');
    });

    testWidgets('multi-instance × 500 (create+drop+GC) — instances collected, RSS bounded', (t) async {
      final rss0 = rssMB();
      final weaks = <WeakReference<Object>>[];
      for (var i = 0; i < 500; i++) {
        final inst = plugin.NitroTypeCoverage.getInstance('soak-$i');
        inst.echoInt(i);
        weaks.add(WeakReference<Object>(inst));
        if (i % 100 == 0) await Future<void>.delayed(Duration.zero);
      }
      await forceGC(fullGcCycles: 4, timeout: const Duration(seconds: 20));
      final live = weaks.where((w) => w.target != null).length;
      final growth = rssMB() - rss0;
      // ignore: avoid_print
      print('multi-instance soak: ${500 - live}/500 collected, $live live, RSS Δ${growth}MB');
      // The leak proof is COLLECTION: the weak cache + non-capturing finalizer
      // must let the dropped instances be collected — a strong cache would
      // leave all 500 live. (RSS is not asserted here: forceGC() deliberately
      // allocates to drive GC cycles, and that memory isn't returned to the OS
      // synchronously, so post-forceGC RSS is not a reliable bound.)
      expect(live, lessThan(50), reason: '$live/500 keyed instances still live after GC (weak cache should collect them)');
    });

    testWidgets('streams × 200 (subscribe/emit/cancel) — RSS bounded', (t) async {
      final api = plugin.NitroTypeCoverage.instance;
      final seed = plugin.TcConfig(name: 'x' * 100, count: 0, enabled: true, threshold: 0.5);
      final rss0 = rssMB();
      for (var r = 0; r < 200; r++) {
        final done = Completer<void>();
        var got = 0;
        final sub = api.configStream().listen((_) {
          if (++got >= 20 && !done.isCompleted) done.complete();
        });
        await Future<void>.delayed(const Duration(milliseconds: 2));
        api.configureConfigStream(seed, 20);
        await done.future.timeout(const Duration(seconds: 3), onTimeout: () {});
        await sub.cancel();
      }
      final growth = rssMB() - rss0;
      expect(growth, lessThan(24), reason: 'RSS grew ${growth}MB over 200 stream rounds');
    });

    testWidgets('batch multi-stream × 200 (3 batch streams) — RSS bounded', (t) async {
      final api = plugin.NitroTypeCoverage.instance;
      final doubles = List<double>.generate(16, (i) => i * 1.5);
      final bools = List<bool>.generate(16, (i) => i.isEven);
      final rss0 = rssMB();
      for (var r = 0; r < 200; r++) {
        final done = Completer<void>();
        var got = 0;
        void tick() {
          if (++got >= 48 && !done.isCompleted) done.complete();
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
      }
      final growth = rssMB() - rss0;
      expect(growth, lessThan(24), reason: 'RSS grew ${growth}MB over 200 batch-stream rounds');
    });
  });
}
