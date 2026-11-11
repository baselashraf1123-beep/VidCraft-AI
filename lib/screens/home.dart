import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/state.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'player.dart';

const _templates = [
  ('حقائق مدهشة', 'خمس حقائق مدهشة لا تعرفها عن الفضاء', Icons.lightbulb_outline),
  ('نصائح صحية', 'فوائد شرب الماء في الصباح', Icons.favorite_border),
  ('تحفيز', 'رسالة تحفيزية لبداية أسبوع جديد', Icons.bolt),
  ('تقنية', 'كيف يغيّر الذكاء الاصطناعي حياتنا اليومية', Icons.memory),
  ('سفر', 'أجمل الأماكن السياحية في مصر', Icons.flight_takeoff),
  ('طبخ', 'طريقة عمل القهوة العربية الأصيلة', Icons.restaurant),
];

class HomeScreen extends StatefulWidget {
  final void Function([String?]) onCreate;
  final VoidCallback onSeeAll;
  const HomeScreen({super.key, required this.onCreate, required this.onSeeAll});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _c = TextEditingController();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 100), children: [
      Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: kPurple, borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.movie_filter, color: Colors.white),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('VidCraft AI', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            Text('حوّل فكرتك إلى فيديو جاهز للنشر', style: TextStyle(fontSize: 12.5, color: Colors.black54)),
          ]),
        ),
      ]),
      const SizedBox(height: 16),
      ServerBanner(ok: s.serverOk, onTap: s.refreshServer),
      if (s.serverOk != true) const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [kPurple, Color(0xFF9B6BFF)], begin: Alignment.topRight, end: Alignment.bottomLeft),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('اكتب فكرة الفيديو', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(
            controller: _c,
            minLines: 2,
            maxLines: 3,
            maxLength: 300,
            decoration: const InputDecoration(hintText: 'مثال: 5 حقائق عن القهوة', counterText: ''),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: kPurple),
            onPressed: () => widget.onCreate(_c.text.trim().isEmpty ? null : _c.text.trim()),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('متابعة'),
          ),
        ]),
      ),
      const SizedBox(height: 22),
      const Text('قوالب جاهزة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _templates.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final t = _templates[i];
            return ActionChip(
              avatar: Icon(t.$3, size: 18, color: kPurple),
              label: Text(t.$1),
              backgroundColor: Colors.white,
              onPressed: () => widget.onCreate(t.$2),
            );
          },
        ),
      ),
      const SizedBox(height: 22),
      Row(children: [
        const Expanded(child: Text('آخر المشاريع', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
        if (s.projects.isNotEmpty) TextButton(onPressed: widget.onSeeAll, child: const Text('عرض الكل')),
      ]),
      const SizedBox(height: 8),
      if (s.projects.isEmpty)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 36),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: const Column(children: [
            Icon(Icons.video_library_outlined, size: 44, color: kPurple),
            SizedBox(height: 8),
            Text('لا توجد مشاريع بعد', style: TextStyle(fontWeight: FontWeight.w700)),
            Text('أنشئ أول فيديو لك الآن', style: TextStyle(color: Colors.black54, fontSize: 12.5)),
          ]),
        )
      else
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.62,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final p in s.projects.take(4))
              ProjectCard(p: p, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlayerScreen(project: p)))),
          ],
        ),
    ]);
  }
}
