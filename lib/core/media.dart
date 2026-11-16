import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class MediaActions {
  /// Downloads the video to the app cache, returns the local path.
  static Future<File> _fetch(String url, String name) async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/$name.mp4');
    final req = http.Request('GET', Uri.parse(url));
    final res = await http.Client().send(req).timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    final sink = f.openWrite();
    await res.stream.pipe(sink);
    if (await f.length() < 10000) throw Exception('empty file');
    return f;
  }

  /// Saves to the phone gallery (Movies/VidCraft). On web opens the download link.
  static Future<String> saveToGallery(String url, String name) async {
    if (kIsWeb) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      return 'تم فتح رابط التحميل';
    }
    if (!await Gal.hasAccess(toAlbum: true)) {
      if (!await Gal.requestAccess(toAlbum: true)) return 'لم يتم منح إذن الحفظ في المعرض';
    }
    final f = await _fetch(url, name);
    await Gal.putVideo(f.path, album: 'VidCraft');
    return 'تم حفظ الفيديو في المعرض (ألبوم VidCraft)';
  }

  static Future<void> share(String url, String name, String text) async {
    if (kIsWeb) {
      await SharePlus.instance.share(ShareParams(text: '$text\n$url'));
      return;
    }
    final f = await _fetch(url, name);
    await SharePlus.instance.share(ShareParams(files: [XFile(f.path, mimeType: 'video/mp4')], text: text));
  }
}
