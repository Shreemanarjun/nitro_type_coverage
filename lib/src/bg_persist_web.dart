Future<void> persistBgResult(String line) async => throw UnsupportedError('no background jobs on web');

Future<String?> readBgResult() async => null;

Future<void> clearBgResult() async {}

Future<void> appendBgLine(String line) async {}
Future<List<String>> readBgLines() async => const [];
Future<void> clearBgLines() async {}
