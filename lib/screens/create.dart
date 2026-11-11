import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/state.dart';
import '../core/theme.dart';
import 'progress.dart';

class CreateScreen extends StatefulWidget {
  final String? initialIdea;
  const CreateScreen({super.key, this.initialIdea});
  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  late final TextEditingController _idea = TextEditingController(text: widget.initialIdea ?? '');
  String _lang = 'ar';
  String? _voice;
  String _style = 'cinematic';
  String _visuals = 'stock';
  double _scenes = 5;
  double _rate = 0;
  bool _busy = false;

  @override
  void dispose() {
    _idea.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    final s = context.read<AppState>();
    if (_idea.text.trim().length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اكتب فكرة الفيديو أولاً (3 أحرف على الأقل)')));
      return;
    }
    final voices = s.voices.where((v) => v.lang == _lang).toList();
    final voice = _voice != null && voices.any((v) => v.id == _voice) ? _voice! : voices.first.id;
    setState(() => _busy = true);
    try {
      final body = {
        'idea': _idea.text.trim(),
        'language': _lang,
        'voice': voice,
        'style': _style,
        'visuals': _visuals,
        'scenes': _scenes.round(),
        'rate': '${_rate >= 0 ? '+' : ''}${_rate.round()}%',
        'watermark': s.watermark ? 'VidCraft AI' : null,
      };
      final id = await s.api.createJob(body);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => ProgressScreen(jobId: id, idea: _idea.text.trim()),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 10),
        child: Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
      );

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final voices = s.voices.where((v) => v.lang == _lang).toList();
    final selVoice = voices.any((v) => v.id == _voice) ? _voice! : voices.first.id;
    return Scaffold(
      appBar: AppBar(title: const Text('إنشاء فيديو')),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
        TextField(
          controller: _idea,
          minLines: 3,
          maxLines: 5,
          maxLength: 500,
          decoration: const InputDecoration(hintText: 'اكتب فكرة الفيديو...'),
        ),
        _label('لغة الفيديو'),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'ar', label: Text('العربية')),
            ButtonSegment(value: 'en', label: Text('English')),
          ],
          selected: {_lang},
          onSelectionChanged: (v) => setState(() {
            _lang = v.first;
            _voice = null;
          }),
        ),
        _label('الصوت'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final v in voices)
            ChoiceChip(
              avatar: Icon(v.gender == 'male' ? Icons.man : Icons.woman, size: 18),
              label: Text(v.name),
              selected: selVoice == v.id,
              selectedColor: kPurpleLight,
              backgroundColor: Colors.white,
              onSelected: (_) => setState(() => _voice = v.id),
            ),
        ]),
        _label('مصدر الصور'),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'stock', label: Text('صور حقيقية'), icon: Icon(Icons.photo_library_outlined)),
            ButtonSegment(value: 'ai', label: Text('ذكاء اصطناعي'), icon: Icon(Icons.auto_awesome)),
          ],
          selected: {_visuals},
          onSelectionChanged: (v) => setState(() => _visuals = v.first),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            _visuals == 'ai'
                ? 'توليد الصور بالذكاء الاصطناعي في الباقة المجانية أبطأ (صورة كل 45 ثانية) وقد يحمل شعار المزوّد.'
                : 'صور مرخّصة من مصادر مفتوحة، أسرع وبدون حدود تقريباً.',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ),
        if (_visuals == 'ai') ...[
          _label('ستايل الصورة'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final st in s.styles)
              ChoiceChip(
                label: Text(st.name),
                selected: _style == st.id,
                selectedColor: kPurpleLight,
                backgroundColor: Colors.white,
                onSelected: (_) => setState(() => _style = st.id),
              ),
          ]),
        ],
        _label('عدد المشاهد: ${_scenes.round()}  (≈ ${(_scenes * 7).round()} ثانية)'),
        Slider(value: _scenes, min: 2, max: 8, divisions: 6, onChanged: (v) => setState(() => _scenes = v)),
        _label('سرعة الصوت: ${_rate.round()}%'),
        Slider(value: _rate, min: -20, max: 30, divisions: 10, onChanged: (v) => setState(() => _rate = v)),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _busy ? null : _go,
          icon: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.auto_awesome),
          label: const Text('ابدأ التوليد'),
        ),
      ]),
    );
  }
}
