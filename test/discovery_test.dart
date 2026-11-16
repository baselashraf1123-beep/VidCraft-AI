import 'package:flutter_test/flutter_test.dart';
import 'package:vidcraft_ai/core/discovery.dart';

void main() {
  // Needs a VidCraft server on localhost:8000 (run_server.sh). Skipped otherwise.
  test('scan finds the server inside a /24 range (real network probes)', () async {
    final sw = Stopwatch()..start();
    final found = await Discovery.scan(prefixes: ['127.0.0'], quickProbes: false);
    // ignore: avoid_print
    print('found=$found in ${sw.elapsedMilliseconds} ms');
    expect(found, contains('http://127.0.0.1:8000'));
  });

  test('scan returns empty on a range with no server', () async {
    final found = await Discovery.scan(prefixes: ['10.254.254'], quickProbes: false, port: 8000);
    expect(found, isEmpty);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('probe ignores non-VidCraft services', () async {
    final found = await Discovery.scan(prefixes: ['127.0.0'], quickProbes: false, port: 5060);
    expect(found, isEmpty); // 5060 serves the Flutter web preview, not the API
  });
}
