// Patrol checks for @NitroEntryPoint background invocation that need the
// native side: the app is sent to the background and the job is started from
// the OS (a `nitrobg://run?text=…` link handled by NitroBgJobActivity on
// Android and the scene delegate on iOS), then the app is brought back and the
// card is checked. Run with:
//   patrol test -t integration_test/bg_patrol_test.dart -d <device>
// The "process not running at all" path cannot be driven from an in-app test
// (Patrol's Dart side lives in the app); see the adb / simctl recipes in the
// plugin README for that one.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nitro_type_coverage/nitro_type_coverage.dart' as plugin;
import 'package:nitro_type_coverage_example/main.dart' as app;
import 'package:patrol/patrol.dart';

const _resultKey = Key('bg-result');
const _runKey = Key('bg-run');
const _refreshKey = Key('bg-refresh');

String _cardText(PatrolIntegrationTester $) =>
    $.tester.widget<SelectableText>(find.byKey(_resultKey)).data ?? '';

/// Polls the persisted result until it contains [marker]; proves the Dart
/// entry ran regardless of what the UI shows.
Future<String> _waitForPersisted(String marker) async {
  final deadline = DateTime.now().add(const Duration(seconds: 20));
  while (DateTime.now().isBefore(deadline)) {
    final line = await plugin.readBgResult();
    if (line != null && line.contains(marker)) return line;
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  throw TestFailure('no background result containing "$marker" within 20s');
}

/// Simulators ask "Open in `<app>`?" the first time a custom scheme is opened
/// from outside the app; accept it when it shows up.
Future<void> _acceptOpenPromptIfShown(PatrolIntegrationTester $) async {
  if (!Platform.isIOS) return;
  await Future<void>.delayed(const Duration(seconds: 1));
  const open = IOSSelector(label: 'Open');
  const springboard = 'com.apple.springboard';
  final buttons = await $.platform.ios.getNativeViews(
    open,
    appId: springboard,
  );
  if (buttons.roots.isNotEmpty) {
    await $.platform.ios.tap(open, appId: springboard);
  }
}

/// Polls the appended lines until at least [count] are present.
Future<List<String>> _waitForLines(int count, Duration timeout) async {
  final deadline = DateTime.now().add(timeout);
  var lines = <String>[];
  while (DateTime.now().isBefore(deadline)) {
    lines = await plugin.readBgLines();
    if (lines.length >= count) return lines;
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  throw TestFailure('expected $count background lines within $timeout, got $lines');
}

/// Every job of this process has left the table — engines were torn down.
Future<void> _waitForIdle() async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (plugin.activeNitroTypeCoverageBackgroundJobs() != 0 && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  expect(plugin.activeNitroTypeCoverageBackgroundJobs(), 0, reason: 'all background jobs finished');
}

Future<void> _launch(PatrolIntegrationTester $) async {
  await plugin.clearBgResult();
  await app.main();
  await $.pumpAndSettle();
  await $(_refreshKey).tap();
  expect(_cardText($), '(no background result yet)');
}

void main() {
  patrolTest('background entry started from the app updates the card', (
    $,
  ) async {
    await _launch($);
    await $(_runKey).tap();
    final line = await _waitForPersisted('from app @');
    await $(_refreshKey).tap();
    expect(_cardText($), line);
  });

  patrolTest('OS-started job runs while the app is in the background', (
    $,
  ) async {
    await _launch($);
    await $.platform.mobile.pressHome();
    await $.platform.mobile.openUrl('nitrobg://run?text=from-patrol-bg');
    await _acceptOpenPromptIfShown($);
    // Android: NitroBgJobActivity (no window) ran the headless engine in this
    // process. iOS: the link foregrounds the app and the scene delegate ran it.
    final line = await _waitForPersisted('from-patrol-bg @');
    await $.platform.mobile.openApp();
    await $.pumpAndSettle();
    await $(_refreshKey).tap();
    expect(_cardText($), line);
  });

  patrolTest('OS-started job while the app is in the foreground', ($) async {
    await _launch($);
    await $.platform.mobile.openUrl('nitrobg://run?text=from-patrol-fg');
    await _acceptOpenPromptIfShown($);
    final line = await _waitForPersisted('from-patrol-fg @');
    await $.platform.mobile.openApp();
    await $.pumpAndSettle();
    await $(_refreshKey).tap();
    expect(_cardText($), line);
    expect(line, isNot(contains('from-patrol-bg')));
  });

  patrolTest('burst of 5 OS-started jobs while backgrounded all land', ($) async {
    await _launch($);
    await plugin.clearBgLines();
    await $.platform.mobile.pressHome();
    for (var i = 0; i < 5; i++) {
      await $.platform.mobile.openUrl('nitrobg://run?entry=bgAppend&text=burst-$i');
      await _acceptOpenPromptIfShown($);
    }
    final lines = await _waitForLines(5, const Duration(seconds: 30));
    for (var i = 0; i < 5; i++) {
      expect(lines.where((l) => l.startsWith('burst-$i @')).length, 1, reason: 'job $i ran exactly once');
    }
    await _waitForIdle();
  });

  patrolTest('a failing OS-started job is reported and does not block the next', ($) async {
    await _launch($);
    await plugin.clearBgLines();
    await $.platform.mobile.openUrl('nitrobg://run?entry=bgFailAppend&text=boom');
    await _acceptOpenPromptIfShown($);
    await _waitForLines(1, const Duration(seconds: 20)); // "boom failing" written before the throw
    await $.platform.mobile.openUrl('nitrobg://run?entry=bgAppend&text=after-failure');
    final lines = await _waitForLines(2, const Duration(seconds: 20));
    expect(lines.last, startsWith('after-failure @'));
    await _waitForIdle();
  });

  patrolTest('slow OS-started job overlaps a fast one and both finish', ($) async {
    await _launch($);
    await plugin.clearBgLines();
    await $.platform.mobile.pressHome();
    await $.platform.mobile.openUrl('nitrobg://run?entry=bgSlowAppend&text=slow');
    await _acceptOpenPromptIfShown($);
    await $.platform.mobile.openUrl('nitrobg://run?entry=bgAppend&text=fast');
    final lines = await _waitForLines(2, const Duration(seconds: 30));
    expect(lines.first, startsWith('fast @'), reason: 'the fast job must not queue behind the slow one');
    expect(lines.last, startsWith('slow @'));
    await _waitForIdle();
  });

  patrolTest('Dart-started job keeps running after the app is backgrounded', ($) async {
    await _launch($);
    await plugin.clearBgLines();
    final pending = plugin.runBgSlowAppendInBackground('from-dart-bg');
    await $.platform.mobile.pressHome();
    final line = await pending;
    expect(line, startsWith('from-dart-bg @'));
    await $.platform.mobile.openApp();
    await $.pumpAndSettle();
    expect(await plugin.readBgLines(), [line]);
    await _waitForIdle();
  });

  patrolTest('two OS-started jobs back to back both complete', ($) async {
    await _launch($);
    await $.platform.mobile.pressHome();
    await $.platform.mobile.openUrl('nitrobg://run?text=first');
    await _acceptOpenPromptIfShown($);
    await _waitForPersisted('first @');
    await $.platform.mobile.openUrl('nitrobg://run?text=second');
    final line = await _waitForPersisted('second @');
    await $.platform.mobile.openApp();
    await $.pumpAndSettle();
    await $(_refreshKey).tap();
    expect(_cardText($), line);
  });
}
