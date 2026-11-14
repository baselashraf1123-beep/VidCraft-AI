import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/state.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _c = TextEditingController(text: context.read<AppState>().baseUrl);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final ok = s.serverOk;
    return ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 100), children: [
      const Text('الإعدادات', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 18),
      const Text('عنوان الخادم', style: TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      TextField(controller: _c, textDirection: TextDirection.ltr, decoration: const InputDecoration(hintText: 'https://your-server.example.com')),
      const SizedBox(height: 10),
      Row(children: [
        Icon(ok == null ? Icons.sync : ok ? Icons.check_circle : Icons.cancel, color: ok == null ? Colors.grey : ok ? Colors.green : Colors.red, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(ok == null ? 'جاري الفحص...' : ok ? 'الخادم متصل' : 'الخادم غير متصل', style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
      const SizedBox(height: 12),
      FilledButton(onPressed: () => s.setBase(_c.text), child: const Text('حفظ وفحص الاتصال')),
      const SizedBox(height: 24),
      Card(
        child: SwitchListTile(
          value: s.watermark,
          onChanged: s.setWatermark,
          title: const Text('علامة VidCraft AI المائية', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: const Text('تظهر أعلى الفيديو. تساعد على نشر التطبيق.'),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: SwitchListTile(
          value: s.music,
          onChanged: s.setMusic,
          title: const Text('موسيقى خلفية هادئة', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: const Text('تُولَّد محلياً وتخفت تلقائياً أثناء الكلام.'),
        ),
      ),
      const SizedBox(height: 16),
      const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('عن التطبيق', style: TextStyle(fontWeight: FontWeight.w800)),
            SizedBox(height: 6),
            Text('VidCraft AI v1.0.0\nالسكربت: نموذج لغوي مجاني • الصوت: Edge-TTS • الصور: مصادر مفتوحة • المونتاج: FFmpeg',
                style: TextStyle(fontSize: 12.5, color: Colors.black54, height: 1.6)),
          ]),
        ),
      ),
    ]);
  }
}
