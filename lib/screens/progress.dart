import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api.dart';
import '../core/state.dart';
import '../core/theme.dart';
import 'player.dart';

class ProgressScreen extends StatefulWidget {
  final String jobId, idea;
  const ProgressScreen({super.key, required this.jobId, required this.idea});
  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  Timer? _t;
  int _p = 0;
  String _msg = 'في الطابور';
  String? _error;
  int _fails = 0;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
    _poll();
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    final s = context.read<AppState>();
    try {
      final j = await s.api.job(widget.jobId);
      _fails = 0;
      if (!mounted) return;
      if (j.done) {
        _t?.cancel();
        final r = j.result!;
        final pr = Project(
          id: widget.jobId,
          title: (r['title'] ?? widget.idea) as String,
          idea: widget.idea,
          base: s.baseUrl,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          duration: (r['duration'] as num).toDouble(),
        );
        await s.addProject(pr);
        if (!mounted) return;
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => PlayerScreen(project: pr, credits: List<String>.from(r['credits'] ?? []))));
      } else if (j.failed) {
        _t?.cancel();
        setState(() => _error = j.message);
      } else {
        setState(() {
          _p = j.progress;
          _msg = j.message;
        });
      }
    } on ApiException catch (e) {
      _t?.cancel();
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (++_fails >= 5) {
        _t?.cancel();
        if (mounted) setState(() => _error = 'انقطع الاتصال بالخادم');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _error != null,
      child: Scaffold(
        appBar: AppBar(title: const Text('جاري صناعة الفيديو'), automaticallyImplyLeading: _error != null),
        body: Padding(
          padding: const EdgeInsets.all(28),
          child: Center(
            child: _error != null
                ? Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 14),
                    const Text('حدث خطأ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
                    const SizedBox(height: 24),
                    FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('رجوع')),
                  ])
                : Column(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(
                      width: 150, height: 150,
                      child: Stack(alignment: Alignment.center, children: [
                        SizedBox.expand(
                          child: CircularProgressIndicator(
                            value: _p == 0 ? null : _p / 100,
                            strokeWidth: 10,
                            backgroundColor: kPurpleLight,
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Text('$_p%', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: kPurple)),
                      ]),
                    ),
                    const SizedBox(height: 30),
                    Text(_msg, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    Text('"${widget.idea}"', maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.black54, fontSize: 13)),
                    const SizedBox(height: 24),
                    const Text('قد يستغرق الأمر دقيقة أو أكثر، لا تغلق الشاشة.', style: TextStyle(fontSize: 12, color: Colors.black45)),
                  ]),
          ),
        ),
      ),
    );
  }
}
