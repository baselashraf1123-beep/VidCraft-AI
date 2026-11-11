import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/state.dart';
import '../widgets/common.dart';
import 'player.dart';

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Column(children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Align(alignment: AlignmentDirectional.centerStart, child: Text('مشاريعي', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
      ),
      Expanded(
        child: s.projects.isEmpty
            ? const Center(child: Text('لا توجد مشاريع محفوظة', style: TextStyle(color: Colors.black54)))
            : GridView.builder(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.62),
                itemCount: s.projects.length,
                itemBuilder: (_, i) {
                  final p = s.projects[i];
                  return ProjectCard(
                    p: p,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlayerScreen(project: p))),
                    onDelete: () => s.removeProject(p.id),
                  );
                },
              ),
      ),
    ]);
  }
}
