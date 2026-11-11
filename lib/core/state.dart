import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';

const _defaultBase = String.fromEnvironment('API_BASE', defaultValue: 'http://10.0.2.2:8000');

class Project {
  final String id, title, idea, base;
  final int createdAt;
  final double duration;
  Project({
    required this.id,
    required this.title,
    required this.idea,
    required this.base,
    required this.createdAt,
    required this.duration,
  });
  Map<String, dynamic> toJson() => {
        'id': id, 'title': title, 'idea': idea, 'base': base,
        'createdAt': createdAt, 'duration': duration,
      };
  factory Project.fromJson(Map<String, dynamic> j) => Project(
        id: j['id'], title: j['title'], idea: j['idea'], base: j['base'],
        createdAt: j['createdAt'], duration: (j['duration'] as num).toDouble(),
      );
  String get videoUrl => '$base/api/jobs/$id/video';
  String get thumbUrl => '$base/api/jobs/$id/thumb';
}

class AppState extends ChangeNotifier {
  late SharedPreferences _p;
  String baseUrl = _defaultBase;
  List<Project> projects = [];
  List<VoiceOpt> voices = fallbackVoices;
  List<StyleOpt> styles = fallbackStyles;
  bool? serverOk;
  bool watermark = true;

  Api get api => Api(baseUrl);

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    baseUrl = _p.getString('baseUrl') ?? _defaultBase;
    watermark = _p.getBool('watermark') ?? true;
    final raw = _p.getString('projects');
    if (raw != null) {
      try {
        projects = (jsonDecode(raw) as List).map((e) => Project.fromJson(e)).toList();
      } catch (_) {
        projects = [];
      }
    }
    notifyListeners();
    refreshServer();
  }

  Future<void> refreshServer() async {
    serverOk = null;
    notifyListeners();
    serverOk = await api.health();
    if (serverOk == true) {
      try {
        final o = await api.options();
        voices = o.voices;
        styles = o.styles;
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> setBase(String v) async {
    baseUrl = v.trim();
    await _p.setString('baseUrl', baseUrl);
    await refreshServer();
  }

  Future<void> setWatermark(bool v) async {
    watermark = v;
    await _p.setBool('watermark', v);
    notifyListeners();
  }

  Future<void> addProject(Project pr) async {
    projects.removeWhere((e) => e.id == pr.id);
    projects.insert(0, pr);
    await _save();
  }

  Future<void> removeProject(String id) async {
    projects.removeWhere((e) => e.id == id);
    await _save();
  }

  Future<void> _save() async {
    await _p.setString('projects', jsonEncode(projects.map((e) => e.toJson()).toList()));
    notifyListeners();
  }
}
