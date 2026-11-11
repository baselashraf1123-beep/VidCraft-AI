import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import '../core/state.dart';
import '../core/theme.dart';

class PlayerScreen extends StatefulWidget {
  final Project project;
  final List<String> credits;
  const PlayerScreen({super.key, required this.project, this.credits = const []});
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final VideoPlayerController _c;
  bool _ready = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    _c = VideoPlayerController.networkUrl(Uri.parse(widget.project.videoUrl));
    _c.initialize().then((_) {
      if (!mounted) return;
      setState(() => _ready = true);
      _c.setLooping(true);
      _c.play();
    }).catchError((e) {
      if (mounted) setState(() => _err = 'تعذر تشغيل الفيديو. ربما انتهت صلاحيته على الخادم.');
    });
    _c.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _download() async {
    final ok = await launchUrl(Uri.parse(widget.project.videoUrl), mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح رابط التحميل')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.project;
    return Scaffold(
      appBar: AppBar(title: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: AspectRatio(
              aspectRatio: 9 / 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  color: Colors.black,
                  child: _err != null
                      ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(_err!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white))))
                      : !_ready
                          ? const Center(child: CircularProgressIndicator(color: Colors.white))
                          : GestureDetector(
                              onTap: () => _c.value.isPlaying ? _c.pause() : _c.play(),
                              child: Stack(fit: StackFit.expand, children: [
                                VideoPlayer(_c),
                                if (!_c.value.isPlaying)
                                  const Center(child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 72)),
                                Positioned(
                                  left: 0, right: 0, bottom: 0,
                                  child: VideoProgressIndicator(_c, allowScrubbing: true,
                                      colors: const VideoProgressColors(playedColor: kPurple, bufferedColor: Colors.white24)),
                                ),
                              ]),
                            ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(onPressed: _download, icon: const Icon(Icons.download_rounded), label: const Text('تحميل الفيديو')),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: p.videoUrl));
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ رابط الفيديو')));
          },
          icon: const Icon(Icons.link),
          label: const Text('نسخ الرابط'),
        ),
        if (widget.credits.isNotEmpty) ...[
          const SizedBox(height: 22),
          const Text('حقوق الصور (للنشر)', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          for (final c in widget.credits) Padding(padding: const EdgeInsets.only(top: 4), child: Text('• $c', style: const TextStyle(fontSize: 12, color: Colors.black54))),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: widget.credits.join('\n')));
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ الحقوق، ضعها في وصف الفيديو')));
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('نسخ الحقوق'),
          ),
        ],
      ]),
    );
  }
}
