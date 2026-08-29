/// AtaKonitena 主框架：响应式导航。
library;

import 'package:flutter/material.dart';
import '../features/installed/installed_screen.dart';
import '../features/store/store_screen.dart';
import '../features/editor/projects_screen.dart';
import '../features/console/console_screen.dart';
import '../features/docs/docs_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _titles = ['应用', '应用市场', '编辑器', '控制台', '文档'];

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const InstalledScreen(),
      const StoreScreen(),
      const ProjectsScreen(),
      const ConsoleScreen(),
      const DocsScreen(),
    ];

    final rail = NavigationRail(
      selectedIndex: _index,
      onDestinationSelected: (i) => setState(() => _index = i),
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.inventory_2_outlined, color: Colors.black),
            ),
            const SizedBox(height: 6),
            const Text('Ata',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            const Text('Konitena',
                style: TextStyle(fontSize: 8, color: Color(0xFF8B93A1))),
          ],
        ),
      ),
      destinations: const [
        NavigationRailDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: Text('应用')),
        NavigationRailDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: Text('市场')),
        NavigationRailDestination(
            icon: Icon(Icons.code_outlined),
            selectedIcon: Icon(Icons.code),
            label: Text('编辑器')),
        NavigationRailDestination(
            icon: Icon(Icons.terminal_outlined),
            selectedIcon: Icon(Icons.terminal),
            label: Text('控制台')),
        NavigationRailDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: Text('文档')),
      ],
    );

    final layout = Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            if (MediaQuery.sizeOf(context).width >= 720)
              rail
            else
              NavigationRail(
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                labelType: NavigationRailLabelType.all,
                destinations: const [
                  NavigationRailDestination(
                      icon: Icon(Icons.grid_view_outlined), label: Text('应用')),
                  NavigationRailDestination(
                      icon: Icon(Icons.storefront_outlined), label: Text('市场')),
                  NavigationRailDestination(
                      icon: Icon(Icons.code_outlined), label: Text('编辑器')),
                  NavigationRailDestination(
                      icon: Icon(Icons.terminal_outlined), label: Text('控制台')),
                  NavigationRailDestination(
                      icon: Icon(Icons.menu_book_outlined), label: Text('文档')),
                ],
              ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(_titles[_index],
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  Expanded(
                    child: IndexedStack(index: _index, children: pages),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return layout;
  }
}