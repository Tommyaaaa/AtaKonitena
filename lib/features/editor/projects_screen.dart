/// 项目列表：新建 / 打开 / 删除 Ata 项目（内置代码编辑器入口）。
library;

import 'package:flutter/material.dart';
import '../../app_services.dart';
import 'editor_screen.dart';
import 'project_model.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  List<AtaProject> _projects = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    try {
      setState(() {
        _projects = AppServices.instance.projects.listProjects();
        _error = null;
      });
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  Future<void> _newProject() async {
    final proj = AppServices.instance.projects.createDefault();
    await _openEditor(proj);
  }

  Future<void> _openEditor(AtaProject project) async {
    await Navigator.of(context).push<AtaProject?>(
      MaterialPageRoute(
        builder: (_) => EditorScreen(initial: project),
      ),
    );
    _reload();
  }

  Future<void> _delete(AtaProject p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除项目 ${p.manifest.name}？'),
        content: const Text('该项目将从编辑器中移除（不影响已安装的应用）。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('删除')),
        ],
      ),
    );
    if (ok == true) {
      AppServices.instance.projects.delete(p.manifest.id);
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                size: 64, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            const Text('读取项目失败'),
            const SizedBox(height: 8),
            Text(_error!,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    if (_projects.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            const Text('还没有项目'),
            const SizedBox(height: 8),
            Text('点击右下角按钮新建一个 Ata 项目，编写代码并打包成 .atak。',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            FilledButton.icon(
                onPressed: _newProject,
                icon: const Icon(Icons.add),
                label: const Text('新建项目')),
          ],
        ),
      );
    }

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [for (final p in _projects) _row(p)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newProject,
        icon: const Icon(Icons.add),
        label: const Text('新建项目'),
      ),
    );
  }

  Widget _row(AtaProject p) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.code, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.manifest.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(
                      '${p.manifest.id}  ·  v${p.manifest.version}  ·  ${p.files.length} 个文件',
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            OutlinedButton(
                onPressed: () => _delete(p), child: const Text('删除')),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
                onPressed: () => _openEditor(p),
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('编辑')),
          ],
        ),
      ),
    );
  }
}
