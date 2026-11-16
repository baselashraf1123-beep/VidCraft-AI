import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Finds a VidCraft server on the local Wi-Fi by probing every address of the
/// phone's /24 subnet(s) on [port]. Returns base URLs like http://192.168.1.20:8000.
class Discovery {
  static Future<bool> _probe(String base) async {
    try {
      final r = await http.get(Uri.parse('$base/api/health')).timeout(const Duration(milliseconds: 900));
      if (r.statusCode != 200) return false;
      return (jsonDecode(r.body) as Map)['service'] == 'vidcraft-ai';
    } catch (_) {
      return false;
    }
  }

  static Future<List<String>> localPrefixes() async {
    final out = <String>{};
    try {
      for (final ni in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
        for (final a in ni.addresses) {
          final p = a.address.split('.');
          if (p.length == 4 && !a.isLoopback && !a.address.startsWith('169.254')) {
            out.add('${p[0]}.${p[1]}.${p[2]}');
          }
        }
      }
    } catch (_) {}
    return out.toList();
  }

  static Future<List<String>> scan({int port = 8000, List<String>? prefixes, bool quickProbes = true, void Function(double)? onProgress}) async {
    if (kIsWeb) return [];
    final found = <String>[];
    // Emulator host + common cases first.
    final quick = ['http://10.0.2.2:$port', 'http://localhost:$port', 'http://127.0.0.1:$port'];
    if (quickProbes) {
      for (final q in quick) {
        if (await _probe(q)) found.add(q);
      }
      if (found.isNotEmpty) return found;
    }
    prefixes ??= await localPrefixes();
    final total = prefixes.length * 254;
    var done = 0;
    for (final pre in prefixes) {
      final hosts = List.generate(254, (i) => 'http://$pre.${i + 1}:$port');
      // 48 concurrent probes keep the radio happy and finish a /24 in ~5 s.
      for (var i = 0; i < hosts.length; i += 48) {
        final chunk = hosts.sublist(i, (i + 48).clamp(0, hosts.length));
        final res = await Future.wait(chunk.map((h) async => await _probe(h) ? h : null));
        found.addAll(res.whereType<String>());
        done += chunk.length;
        onProgress?.call(total == 0 ? 1 : done / total);
        if (found.isNotEmpty) return found.toSet().toList();
      }
    }
    return found.toSet().toList();
  }
}
