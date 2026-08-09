// §39 — validates NitroCoalescer end-to-end on a real device: a burst of
// concurrent @nitroNativeAsync-style calls is batched natively into one kArray
// post over a single shared port, and NitroCoalescer demuxes each result by
// callId. Runs on macOS / iOS / Android — a native Dart_PostCObject of a kArray
// must round-trip correctly on each platform.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nitro/nitro.dart';
import 'package:nitro_type_coverage/nitro_type_coverage.dart' as plugin;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('§39 coalesced completions (NitroCoalescer)', () {
    testWidgets('a 64-in-flight burst all resolves via one shared port', (t) async {
      final api = plugin.NitroTypeCoverage.instance;
      final coalescer = NitroCoalescer();
      addTearDown(coalescer.dispose);

      const burst = 64;
      final results = await Future.wait([
        for (var i = 0; i < burst; i++)
          coalescer.submit(
            (callId, nativePort) => api.submitCoalesced(callId, i * 3, nativePort),
          ),
      ]);

      for (var i = 0; i < burst; i++) {
        expect(results[i], i * 3, reason: 'call $i');
      }
      expect(coalescer.pendingCount, 0);
    });

    testWidgets('repeated bursts of varied sizes stay correct', (t) async {
      final api = plugin.NitroTypeCoverage.instance;
      final coalescer = NitroCoalescer();
      addTearDown(coalescer.dispose);

      for (final size in [1, 7, 33, 128]) {
        final r = await Future.wait([
          for (var i = 0; i < size; i++)
            coalescer.submit(
              (callId, port) => api.submitCoalesced(callId, i + 1000, port),
            ),
        ]);
        for (var i = 0; i < size; i++) {
          expect(r[i], i + 1000, reason: 'size $size call $i');
        }
      }
    });

    testWidgets('back-to-back bursts do not cross-talk', (t) async {
      final api = plugin.NitroTypeCoverage.instance;
      final coalescer = NitroCoalescer();
      addTearDown(coalescer.dispose);

      for (var round = 0; round < 20; round++) {
        final base = round * 100;
        final r = await Future.wait([
          for (var i = 0; i < 16; i++)
            coalescer.submit(
              (callId, port) => api.submitCoalesced(callId, base + i, port),
            ),
        ]);
        for (var i = 0; i < 16; i++) {
          expect(r[i], base + i);
        }
      }
    });
  });
}
