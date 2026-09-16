import 'dart:io';
import 'dart:isolate';

File get _bgResultFile => File('${Directory.systemTemp.path}/nitro_bg_result.txt');

Future<void> persistBgResult(String line) => _bgResultFile.writeAsString(line);

Future<String?> readBgResult() async => _bgResultFile.existsSync() ? _bgResultFile.readAsString() : null;

Future<void> clearBgResult() async {
  if (_bgResultFile.existsSync()) await _bgResultFile.delete();
}

// One file per line: Dart's FileMode.append seeks to the end instead of using
// O_APPEND, so concurrent appenders (isolates or engines in one process, or
// several processes) would overwrite each other. File names sort by write time.
Directory get _bgLinesDir => Directory('${Directory.systemTemp.path}/nitro_bg_lines');

int _bgLineSeq = 0;

/// Records one line — used by burst scenarios where every job must land.
Future<void> appendBgLine(String line) async {
  await _bgLinesDir.create(recursive: true);
  final stamp = DateTime.now().microsecondsSinceEpoch.toString().padLeft(20, '0');
  await File('${_bgLinesDir.path}/$stamp-$pid-${Isolate.current.hashCode}-${_bgLineSeq++}.txt').writeAsString(line, flush: true);
}

/// All recorded lines in write order.
Future<List<String>> readBgLines() async {
  if (!_bgLinesDir.existsSync()) return const [];
  final files = _bgLinesDir.listSync().whereType<File>().toList()..sort((a, b) => a.path.compareTo(b.path));
  return [for (final f in files) await f.readAsString()];
}

Future<void> clearBgLines() async {
  if (_bgLinesDir.existsSync()) await _bgLinesDir.delete(recursive: true);
}
