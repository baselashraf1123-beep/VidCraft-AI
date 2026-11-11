import 'package:flutter/material.dart';
import 'create.dart';
import 'home.dart';
import 'projects.dart';
import 'settings.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _i = 0;

  void _create([String? idea]) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => CreateScreen(initialIdea: idea)));
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(onCreate: _create, onSeeAll: () => setState(() => _i = 1)),
      const ProjectsScreen(),
      const SettingsScreen(),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _i, children: pages)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(),
        icon: const Icon(Icons.auto_awesome),
        label: const Text('فيديو جديد', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (v) => setState(() => _i = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.video_library_outlined), selectedIcon: Icon(Icons.video_library), label: 'مشاريعي'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'الإعدادات'),
        ],
      ),
    );
  }
}
