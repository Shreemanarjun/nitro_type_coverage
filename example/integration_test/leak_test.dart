// Leak-audit #1 — GC-safe instance cleanup, verified on a real device.
//
// A keyed multi-instance that all callers drop must become GC-collectable: the
// weak `_instances` cache must not pin it, the NitroInstanceRegistry entry is a
// WeakReference, and the GC finalizer's token captures only id/key/err/destroy
// (never `this`). If any of those held a strong reference, the instance would
// be pinned for the process lifetime — the pre-fix leak.
//
// leak_tracker's forceGC() drives a real GC cycle (reachability barrier), so
// this is deterministic even on-device (real ART GC on Android).
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:leak_tracker/leak_tracker.dart';
import 'package:nitro_type_coverage/nitro_type_coverage.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('leak-audit #1 — instance GC', () {
    testWidgets('a dropped keyed instance is GC-collectable (weak cache does not pin it)',
        (tester) async {
      var tc = NitroTypeCoverage.getInstance('leak-gc-key-1');
      expect(tc.echoInt(7), 7); // touch → native instance is created + registered
      final weak = WeakReference<Object>(tc);

      // Drop the only strong reference to the keyed instance.
      // ignore: unused_local_variable
      tc = NitroTypeCoverage.instance;

      await forceGC(fullGcCycles: 3, timeout: const Duration(seconds: 5));

      if (weak.target != null) {
        // Diagnostic: what is still retaining the dropped instance?
        final path = await formattedRetainingPath(weak);
        // ignore: avoid_print
        print('RETAINING PATH for leak-gc-key-1:\n$path');
      }
      expect(
        weak.target,
        isNull,
        reason: 'weak _instances cache + non-capturing finalizer token must let a '
            'dropped instance be collected; a strong cache would pin it forever',
      );
    });

    testWidgets('control: a still-referenced instance is NOT collected', (tester) async {
      // Guards the test above from being vacuous — if forceGC() collected
      // everything regardless, this would fail.
      final tc = NitroTypeCoverage.getInstance('leak-gc-key-2');
      expect(tc.echoInt(9), 9);
      final weak = WeakReference<Object>(tc);

      await forceGC(fullGcCycles: 3, timeout: const Duration(seconds: 5));

      expect(weak.target, isNotNull, reason: 'a live (referenced) instance must survive GC');
      // Keep `tc` reachable past the GC above.
      expect(tc.echoInt(10), 10);
    });

    testWidgets('after the dropped instance is collected, getInstance(key) rebuilds a working one',
        (tester) async {
      var tc = NitroTypeCoverage.getInstance('leak-gc-key-3');
      expect(tc.echoString('a'), 'a');
      // ignore: unused_local_variable
      tc = NitroTypeCoverage.instance;

      await forceGC(fullGcCycles: 3, timeout: const Duration(seconds: 5));

      // The weak entry's target is now null; the factory must rebuild a fresh,
      // fully-functional native instance rather than hand back a dangling ref.
      final rebuilt = NitroTypeCoverage.getInstance('leak-gc-key-3');
      expect(rebuilt.echoString('b'), 'b');
    });
  });
}
