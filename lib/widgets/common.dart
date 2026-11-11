import 'package:flutter/material.dart';
import '../core/state.dart';
import '../core/theme.dart';

class ProjectCard extends StatelessWidget {
  final Project p;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  const ProjectCard({super.key, required this.p, required this.onTap, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Stack(fit: StackFit.expand, children: [
          Image.network(
            p.thumbUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: kPurpleLight,
              child: const Icon(Icons.movie_creation_outlined, color: kPurple, size: 40),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.75)],
                  stops: const [0.5, 1],
                ),
              ),
            ),
          ),
          Positioned(
            right: 12, left: 12, bottom: 10,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(p.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 2),
              Text('${p.duration.round()} ث', style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ]),
          ),
          const Positioned(
            top: 10, right: 10,
            child: CircleAvatar(radius: 14, backgroundColor: Colors.white70,
                child: Icon(Icons.play_arrow_rounded, color: kPurple, size: 20)),
          ),
          if (onDelete != null)
            Positioned(
              top: 6, left: 6,
              child: IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, color: Colors.white),
              ),
            ),
        ]),
      ),
    );
  }
}

class ServerBanner extends StatelessWidget {
  final bool? ok;
  final VoidCallback onTap;
  const ServerBanner({super.key, required this.ok, required this.onTap});
  @override
  Widget build(BuildContext context) {
    if (ok == true) return const SizedBox.shrink();
    final checking = ok == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: checking ? kPurpleLight : const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Icon(checking ? Icons.sync : Icons.cloud_off, size: 20, color: checking ? kPurple : Colors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              checking ? 'جاري فحص الاتصال بالخادم...' : 'الخادم غير متصل. اضغط لإعادة المحاولة أو اضبط العنوان من الإعدادات.',
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
        ]),
      ),
    );
  }
}
