import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nitro/nitro.dart';
import 'package:nitro_type_coverage/nitro_type_coverage.dart' as plugin;
import 'package:signals_flutter/signals_flutter.dart';

import 'models.dart';
import 'sections/primitives_sync.dart';
import 'sections/multi_param_sync.dart';
import 'sections/nullable_primitives_sync.dart';
import 'sections/enums_structs.dart';
import 'sections/hybrid_records.dart';
import 'sections/typed_data.dart';
import 'sections/collections.dart';
import 'sections/async_execution.dart';
import 'sections/streams_backpressure.dart';
import 'sections/callbacks.dart';
import 'sections/properties.dart';
import 'sections/special_features.dart';
import 'sections/error_handling.dart';

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
      title: 'Nitro Type Coverage',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
      ),
      home: const DemoDashboard(),
    );
  }
}

class DemoDashboard extends StatefulWidget {
  const DemoDashboard({super.key});

  @override
  State<DemoDashboard> createState() => _DemoDashboardState();
}

class _DemoDashboardState extends State<DemoDashboard> {
  // Pinned terminal state
  final _lastMethod = signal<String>('—');
  final _lastResult = signal<String>('No executions yet');
  final _lastExecTime = signal<String>('—');
  final _lastStatus = signal<String>('idle'); // idle, loading, success, error

  // Interactive console logs
  final _logs = signal<List<String>>([]);
  final _searchQuery = signal<String>('');

  // Active stream subscriptions
  final Map<String, StreamSubscription> _activeSubs = {};
  final _activeStreamsCount = signal<int>(0);

  plugin.NitroTypeCoverage get _api => plugin.NitroTypeCoverage.instance;

  void _log(String message) {
    final timestamp = DateTime.now().toLocal().toString().split(' ')[1].substring(0, 12);
    _logs.value = [
      ..._logs.value,
      '[$timestamp] $message',
    ];
    // Keep last 150 logs
    if (_logs.value.length > 150) {
      _logs.value = _logs.value.sublist(_logs.value.length - 150);
    }
  }

  void _clearLogs() {
    _logs.value = [];
    _log('Logs cleared');
  }

  // Helper to format values for display
  String _format(dynamic val) {
    if (val == null) return 'null';
    if (val is String) return '"$val"';
    if (val is plugin.TcStatus) return 'TcStatus.${val.name}';
    if (val is plugin.TcPoint) return 'TcPoint(x: ${val.x}, y: ${val.y}, z: ${val.z})';
    if (val is plugin.TcConfig) {
      return 'TcConfig(name: "${val.name}", count: ${val.count}, enabled: ${val.enabled}, threshold: ${val.threshold})';
    }
    if (val is plugin.TcMeta) {
      return 'TcMeta(version: ${val.version}, weight: ${val.weight}, active: ${val.active}, label: "${val.label}")';
    }
    if (val is plugin.TcPacket) {
      return 'TcPacket(name: "${val.name}", sequence: ${val.sequence}, status: TcStatus.${val.status.name}, valid: ${val.valid})';
    }
    if (val is plugin.TcNested) {
      return 'TcNested(label: "${val.label}", config: ${_format(val.config)}, version: ${val.version})';
    }
    if (val is plugin.TcNullableWrapper) {
      return 'TcNullableWrapper(count: ${val.count.nullable}, rate: ${val.rate.nullable}, name: "${val.name}")';
    }
    if (val is plugin.TcStructHolder) {
      return 'TcStructHolder(label: "${val.label}", origin: ${_format(val.origin)}, radius: ${val.radius})';
    }
    if (val is plugin.TcDataRecord) {
      return 'TcDataRecord(bytes: [${val.bytes.take(5).join(', ')}...], values: [${val.values.take(5).join(', ')}...], scores: [${val.scores.take(5).join(', ')}...], label: "${val.label}")';
    }
    if (val is NitroNullableInt) return 'NitroNullableInt(${val.nullable})';
    if (val is NitroNullableDouble) return 'NitroNullableDouble(${val.nullable})';
    if (val is NitroNullableBool) return 'NitroNullableBool(${val.nullable})';
    if (val is NitroResultValue) {
      if (val is NitroOk) {
        return 'NitroOk(value: ${val.value})';
      } else if (val is NitroErr) {
        return 'NitroErr(message: "${val.message}")';
      }
    }
    if (val is plugin.TcEvent) {
      if (val is plugin.TcEventTap) return 'TcEventTap(x: ${val.x}, y: ${val.y})';
      if (val is plugin.TcEventScroll) return 'TcEventScroll(delta: ${val.delta})';
      if (val is plugin.TcEventResize) return 'TcEventResize(width: ${val.width}, height: ${val.height})';
      if (val is plugin.TcEventNullable) {
        return 'TcEventNullable(count: ${val.count}, status: ${val.status?.name}, config: ${_format(val.config)}, samples: ${val.samples})';
      }
    }
    if (val is NativeHandle) {
      return 'NativeHandle(address: 0x${val.address.toRadixString(16)})';
    }
    if (val is List) {
      return '[${val.take(8).join(', ')}${val.length > 8 ? '...' : ''}]';
    }
    if (val is Map) {
      final entries = val.entries.map((e) => '"${e.key}": ${_format(e.value)}').join(', ');
      return '{$entries}';
    }
    return val.toString();
  }

  // High-level runner wrapper for sync/async calls
  Future<void> _runApi(String name, String code, FutureOr<dynamic> Function() action) async {
    _lastMethod.value = name;
    _lastStatus.value = 'loading';
    _log('Executing: $code');
    final sw = Stopwatch()..start();
    try {
      final result = await action();
      sw.stop();
      final timeStr = sw.elapsedMicroseconds < 1000
          ? '${sw.elapsedMicroseconds} μs'
          : '${sw.elapsed.inMilliseconds} ms';
      _lastResult.value = _format(result);
      _lastExecTime.value = timeStr;
      _lastStatus.value = 'success';
      _log('Success: $name -> ${_format(result)} ($timeStr)');
    } catch (e, s) {
      sw.stop();
      final timeStr = sw.elapsedMicroseconds < 1000
          ? '${sw.elapsedMicroseconds} μs'
          : '${sw.elapsed.inMilliseconds} ms';
      _lastResult.value = e.toString();
      _lastExecTime.value = timeStr;
      _lastStatus.value = 'error';
      _log('Error: $name failed: $e\n$s');
    }
  }

  @override
  void dispose() {
    for (final sub in _activeSubs.values) {
      sub.cancel();
    }
    super.dispose();
  }

  // ─── API Sections List ───
  List<ApiSection> get _apiSections => [
        getPrimitivesSyncSection(_api, _runApi),
        getMultiParamSyncSection(_api, _runApi),
        getNullablePrimitivesSyncSection(_api, _runApi),
        getEnumsStructsSection(_api, _runApi),
        getHybridRecordsSection(_api, _runApi),
        getTypedDataSection(_api, _runApi),
        getCollectionsSection(_api, _runApi),
        getAsyncExecutionSection(_api, _runApi),
        getStreamsBackpressureSection(_api, _runApi, _toggleStream),
        getCallbacksSection(_api, _runApi, _log),
        getPropertiesSection(_api, _runApi),
        getSpecialFeaturesSection(_api, _runApi),
        getErrorHandlingSection(_api, _runApi),
      ];

  void _toggleStream(String name, Stream<dynamic> Function() getStream) {
    if (_activeSubs.containsKey(name)) {
      _activeSubs[name]!.cancel();
      _activeSubs.remove(name);
      _activeStreamsCount.value = _activeSubs.length;
      _log('Stopped listening to $name');
      _lastResult.value = 'Cancelled stream: $name';
      _lastMethod.value = name;
      _lastStatus.value = 'idle';
    } else {
      _log('Subscribing to $name...');
      final sub = getStream().listen(
        (val) {
          _log('[Stream: $name] Emitted: ${_format(val)}');
          _lastResult.value = _format(val);
          _lastMethod.value = name;
          _lastStatus.value = 'success';
        },
        onError: (e) {
          _log('[Stream: $name] Error: $e');
          _lastResult.value = 'Error: $e';
          _lastMethod.value = name;
          _lastStatus.value = 'error';
        },
        onDone: () {
          _log('[Stream: $name] Closed');
          _activeSubs.remove(name);
          _activeStreamsCount.value = _activeSubs.length;
        },
      );
      _activeSubs[name] = sub;
      _activeStreamsCount.value = _activeSubs.length;
      _log('Started listening to $name');
      _lastResult.value = 'Listening to stream...';
      _lastMethod.value = name;
      _lastStatus.value = 'success';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Nitro Type Coverage',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          SignalBuilder(
            builder: (context) {
              final activeCount = _activeStreamsCount.value;
              if (activeCount == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Chip(
                  avatar: const Icon(Icons.waves, size: 14, color: Colors.blue),
                  label: Text('$activeCount Active Streams'),
                  backgroundColor: Colors.blue.withAlpha(25),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear Console Logs',
            onPressed: _clearLogs,
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Pinned Results Dashboard ───
          _buildTerminal(colorScheme),

          // ─── Pinned Search Bar ───
          _buildSearchBar(colorScheme),

          // ─── Categories Lists ───
          Expanded(
            child: SignalBuilder(
              builder: (context) {
                final query = _searchQuery.value.trim().toLowerCase();
                final sectionsToDisplay = <Widget>[];

                for (final section in _apiSections) {
                  final filteredItems = section.items.where((item) {
                    return item.name.toLowerCase().contains(query) ||
                        item.description.toLowerCase().contains(query) ||
                        item.code.toLowerCase().contains(query) ||
                        section.title.toLowerCase().contains(query);
                  }).toList();

                  if (filteredItems.isNotEmpty) {
                    sectionsToDisplay.add(
                      Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        clipBehavior: Clip.antiAlias,
                        child: ExpansionTile(
                          leading: Icon(section.icon, color: colorScheme.primary),
                          title: Text(
                            section.title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${filteredItems.length} APIs',
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          initiallyExpanded: query.isNotEmpty,
                          children: filteredItems.map((item) => _buildApiListItem(item, colorScheme)).toList(),
                        ),
                      ),
                    );
                  }
                }

                if (sectionsToDisplay.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text(
                        'No matching APIs found.\nTry searching with different terms.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.only(top: 6, bottom: 24),
                  children: sectionsToDisplay,
                );
              },
            ),
          ),

          // ─── Expandable Developer Console Logs ───
          _buildConsoleLogsPanel(colorScheme),
        ],
      ),
    );
  }

  Widget _buildTerminal(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(128)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(76),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(102),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'TERMINAL OUT',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SignalBuilder(
                  builder: (context) {
                    final status = _lastStatus.value;
                    Color color = Colors.grey;
                    IconData icon = Icons.circle_outlined;
                    if (status == 'loading') {
                      color = Colors.amber;
                      icon = Icons.hourglass_empty;
                    } else if (status == 'success') {
                      color = Colors.green;
                      icon = Icons.check_circle_outline;
                    } else if (status == 'error') {
                      color = Colors.red;
                      icon = Icons.error_outline;
                    }
                    return Row(
                      children: [
                        Icon(icon, size: 12, color: color),
                        const SizedBox(width: 4),
                        Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            color: color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Method: ',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: Colors.indigoAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Expanded(
                      child: SignalBuilder(
                        builder: (context) => Text(
                          _lastMethod.value,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const Text(
                      'Elapsed: ',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: Colors.grey,
                        fontSize: 11,
                      ),
                    ),
                    SignalBuilder(
                      builder: (context) => Text(
                        _lastExecTime.value,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          color: Colors.amberAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(height: 1, color: Colors.grey),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 120),
                  child: SingleChildScrollView(
                    child: SignalBuilder(
                      builder: (context) => Text(
                        _lastResult.value,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: _lastStatus.value == 'error'
                              ? Colors.redAccent
                              : Colors.greenAccent,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: SearchBar(
        hintText: 'Search API methods or descriptions...',
        leading: const Icon(Icons.search),
        trailing: [
          SignalBuilder(
            builder: (context) {
              if (_searchQuery.value.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => _searchQuery.value = '',
              );
            },
          )
        ],
        onChanged: (val) => _searchQuery.value = val,
        elevation: WidgetStateProperty.all(1.0),
        backgroundColor: WidgetStateProperty.all(colorScheme.surfaceContainer),
      ),
    );
  }

  Widget _buildApiListItem(ApiItem item, ColorScheme colorScheme) {
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Text(
            item.name,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              fontFamily: 'monospace',
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                item.description,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colorScheme.brightness == Brightness.dark
                      ? Colors.grey.shade900
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  item.code,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          trailing: SignalBuilder(
            builder: (context) {
              final isSelfLoading = _lastMethod.value == item.name && _lastStatus.value == 'loading';
              final isStream = item.name.startsWith('Listen:');
              final isStreamActive = isStream && _activeSubs.containsKey(item.name.substring(8).trim());

              return SizedBox(
                height: 38,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isStreamActive
                        ? Colors.red.withAlpha(38)
                        : colorScheme.primaryContainer,
                    foregroundColor: isStreamActive
                        ? Colors.red
                        : colorScheme.onPrimaryContainer,
                  ),
                  icon: isSelfLoading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          isStreamActive ? Icons.stop_circle_outlined : Icons.play_arrow,
                          size: 16,
                        ),
                  label: Text(
                    isStream ? (isStreamActive ? 'STOP' : 'LISTEN') : 'RUN',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                  onPressed: isSelfLoading ? null : item.run,
                ),
              );
            },
          ),
        ),
        const Divider(height: 1, indent: 16, endIndent: 16),
      ],
    );
  }

  Widget _buildConsoleLogsPanel(ColorScheme colorScheme) {
    return Card(
      margin: const EdgeInsets.all(12),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Icon(Icons.terminal, color: colorScheme.secondary),
        title: const Text(
          'Developer Console Logs',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        subtitle: SignalBuilder(
          builder: (context) => Text(
            '${_logs.value.length} events logged',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ),
        initiallyExpanded: false,
        children: [
          Container(
            height: 200,
            width: double.infinity,
            color: colorScheme.brightness == Brightness.dark
                ? const Color(0xFF0F0F0F)
                : Colors.grey.shade50,
            child: SignalBuilder(
              builder: (context) {
                final logLines = _logs.value;
                if (logLines.isEmpty) {
                  return const Center(
                    child: Text(
                      'No events logged yet. Execute an API to see output logs.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: logLines.length,
                  itemBuilder: (context, idx) {
                    final line = logLines[logLines.length - 1 - idx];
                    final isError = line.contains('Error:') || line.contains('failed:');
                    final isCallback = line.contains('[Callback]');
                    final isStream = line.contains('[Stream:');
                    Color textColor = colorScheme.onSurface;
                    if (isError) {
                      textColor = Colors.redAccent;
                    } else if (isCallback) {
                      textColor = Colors.teal;
                    } else if (isStream) {
                      textColor = Colors.blue;
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Text(
                        line,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: textColor,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
