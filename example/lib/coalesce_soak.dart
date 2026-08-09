import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nitro/nitro.dart';
import 'package:nitro_type_coverage/nitro_type_coverage.dart' as plugin;

/// Profiling soak: hammers coalesced @nitroNativeAsync bursts continuously so a
/// native profiler has a sustained workload. Enable with
/// `--dart-define=COALESCE_PROFILE=true`. Logging/tracing are turned off so the
/// trace reflects the coalescer's native work, not the log path.
class CoalesceSoakScreen extends StatefulWidget {
  const CoalesceSoakScreen({super.key});

  @override
  State<CoalesceSoakScreen> createState() => _CoalesceSoakScreenState();
}

class _CoalesceSoakScreenState extends State<CoalesceSoakScreen> {
  final _api = plugin.NitroTypeCoverage.instance;
  final _coalescer = NitroCoalescer();
  int _bursts = 0;
  int _calls = 0;
  bool _running = true;

  @override
  void initState() {
    super.initState();
    NitroConfig.instance
      ..logLevel = NitroLogLevel.error
      ..timelineTracingEnabled = false;
    _soak();
  }

  Future<void> _soak() async {
    const burst = 64;
    while (_running && mounted) {
      await Future.wait([
        for (var i = 0; i < burst; i++)
          _coalescer.submit((id, port) => _api.submitCoalesced(id, i, port)),
      ]);
      _bursts++;
      _calls += burst;
      if (_bursts % 50 == 0 && mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _running = false;
    _coalescer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Coalesce Soak (profiling)')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Hammering coalesced bursts…'),
              const SizedBox(height: 12),
              Text('$_bursts bursts · $_calls calls',
                  style: Theme.of(context).textTheme.headlineSmall),
            ],
          ),
        ),
      );
}
