import 'dart:convert';
import 'package:http/http.dart' as http;

class VoiceOpt {
  final String id, name, lang, gender;
  const VoiceOpt(this.id, this.name, this.lang, this.gender);
  factory VoiceOpt.fromJson(Map<String, dynamic> j) =>
      VoiceOpt(j['id'], j['name'], j['lang'], j['gender']);
}

class StyleOpt {
  final String id, name;
  const StyleOpt(this.id, this.name);
  factory StyleOpt.fromJson(Map<String, dynamic> j) => StyleOpt(j['id'], j['name']);
}

const fallbackVoices = [
  VoiceOpt('ar-EG-SalmaNeural', 'سلمى (مصر)', 'ar', 'female'),
  VoiceOpt('ar-EG-ShakirNeural', 'شاكر (مصر)', 'ar', 'male'),
  VoiceOpt('ar-SA-ZariyahNeural', 'زارية (السعودية)', 'ar', 'female'),
  VoiceOpt('ar-SA-HamedNeural', 'حامد (السعودية)', 'ar', 'male'),
  VoiceOpt('en-US-AriaNeural', 'Aria (US)', 'en', 'female'),
  VoiceOpt('en-US-GuyNeural', 'Guy (US)', 'en', 'male'),
];
const fallbackStyles = [
  StyleOpt('cinematic', 'سينمائي'),
  StyleOpt('realistic', 'واقعي'),
  StyleOpt('anime', 'أنمي'),
  StyleOpt('3d', 'ثلاثي الأبعاد'),
  StyleOpt('illustration', 'رسم رقمي'),
  StyleOpt('dark', 'داكن / نيون'),
];

class JobStatus {
  final String id, status, message;
  final int progress;
  final Map<String, dynamic>? result;
  JobStatus(this.id, this.status, this.progress, this.message, this.result);
  bool get done => status == 'done';
  bool get failed => status == 'error';
  factory JobStatus.fromJson(Map<String, dynamic> j) => JobStatus(
        j['id'],
        j['status'],
        (j['progress'] ?? 0) as int,
        (j['message'] ?? '') as String,
        j['result'] as Map<String, dynamic>?,
      );
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class Api {
  final String base;
  Api(String b) : base = b.endsWith('/') ? b.substring(0, b.length - 1) : b;

  Uri _u(String p) => Uri.parse('$base$p');
  static const _t = Duration(seconds: 20);

  Future<bool> health() async {
    try {
      final r = await http.get(_u('/api/health')).timeout(const Duration(seconds: 8));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<({List<VoiceOpt> voices, List<StyleOpt> styles})> options() async {
    final r = await http.get(_u('/api/options')).timeout(_t);
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    return (
      voices: (j['voices'] as List).map((e) => VoiceOpt.fromJson(e)).toList(),
      styles: (j['styles'] as List).map((e) => StyleOpt.fromJson(e)).toList(),
    );
  }

  Future<String> createJob(Map<String, dynamic> body) async {
    try {
      final r = await http
          .post(_u('/api/jobs'),
              headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
          .timeout(_t);
      if (r.statusCode != 200) {
        throw ApiException('تعذر بدء المهمة (${r.statusCode})');
      }
      return jsonDecode(r.body)['id'] as String;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('تعذر الاتصال بالخادم. تأكد من عنوان الخادم في الإعدادات.');
    }
  }

  Future<JobStatus> job(String id) async {
    final r = await http.get(_u('/api/jobs/$id')).timeout(_t);
    if (r.statusCode == 404) throw ApiException('انتهت صلاحية المهمة على الخادم');
    if (r.statusCode != 200) throw ApiException('خطأ من الخادم (${r.statusCode})');
    return JobStatus.fromJson(jsonDecode(utf8.decode(r.bodyBytes)));
  }

  String videoUrl(String id) => '$base/api/jobs/$id/video';
  String thumbUrl(String id) => '$base/api/jobs/$id/thumb';
}
