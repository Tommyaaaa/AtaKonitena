/// 内置代码编辑器：文件树 + 源码编辑 + 构建 .atak + 运行。
library;

import 'package:flutter/material.dart';
import '../../app_services.dart';
import '../../core/atak/atak_manifest.dart';
import '../run/run_app_screen.dart';
import 'project_model.dart';

class EditorScreen extends StatefulWidget {
  final AtaProject initial;
  final bool isNew;
  const EditorScreen({super.key, required this.initial, this.isNew = false});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late AtaProject _project;
  String? _selected;
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _project = widget.initial;
    _selected = _project.manifest.entry;
    if (!_project.files.containsKey(_selected)) {
      _selected = _project.files.keys.firstOrNull;
    }
    _ensureController(_selected);
  }

  TextEditingController _ensureController(String? path) {
    if (path == null) return TextEditingController();
    return _controllers.putIfAbsent(
        path, () => TextEditingController(text: _project.files[path] ?? ''));
  }

  void _select(String? path) {
    if (path == null) return;
    _syncCurrent();
    setState(() {
      _selected = path;
      _ensureController(path);
    });
  }

  void _syncCurrent() {
    if (_selected == null) return;
    final c = _controllers[_selected];
    if (c != null) {
      _project = _project.copyWith(
          files: {..._project.files, _selected!: c.text});
    }
  }

  void _save() {
    _syncCurrent();
    AppServices.instance.projects.save(_project);
    _toast('已保存项目');
  }

  Future<void> _newFile() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建文件'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '例如 lib/helper.ata'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('创建')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    if (name == 'manifest.json') {
      _toast('manifest.json 由「项目设置」自动生成，不可手动创建');
      return;
    }
    if (_project.files.containsKey(name)) {
      _toast('文件已存在');
      return;
    }
    _syncCurrent();
    _project =
        _project.copyWith(files: {..._project.files, name: '// $name\n'});
    _ensureController(name);
    setState(() => _selected = name);
  }

  Future<void> _deleteFile() async {
    if (_selected == null) return;
    final path = _selected!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除文件 $path？'),
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
      final files = Map<String, String>.from(_project.files)..remove(path);
      _controllers.remove(path);
      _project = _project.copyWith(files: files);
      final next = _project.files.keys.firstOrNull;
      setState(() {
        _selected = next;
        if (next != null) _ensureController(next);
      });
    }
  }

  Future<void> _editSettings() async {
    _syncCurrent();
    final updated = await showDialog<AtaManifest>(
      context: context,
      builder: (_) => _ManifestDialog(manifest: _project.manifest),
    );
    if (updated != null) {
      _project = _project.copyWith(manifest: updated);
      if (_project.files.containsKey(updated.entry)) {
        _selected = updated.entry;
        _ensureController(_selected);
      }
      setState(() {});
    }
  }

  Future<void> _buildAndInstall() async {
    _syncCurrent();
    try {
      final m = AppServices.instance.projects.install(_project);
      if (!mounted) return;
      _toast('已构建并安装：${m.name} v${m.version}');
    } catch (e) {
      if (!mounted) return;
      _toast('构建失败：$e');
    }
  }

  Future<void> _run() async {
    _syncCurrent();
    try {
      final m = AppServices.instance.projects.install(_project);
      final source =
          AppServices.instance.installer.readEntrySource(m.id, m.entry);
      if (source == null) {
        _toast('找不到入口脚本 ${m.entry}');
        return;
      }
      final session =
          AppServices.instance.containerManager.createSession(m, source);
      if (!mounted) return;
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => RunAppScreen(session: session)));
    } catch (e) {
      if (!mounted) return;
      _toast('运行失败：$e');
    }
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  void dispose() {
    for (final c in _controllers.values) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final leftPanel = _buildFileList();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(_project),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(_project.manifest.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
              onPressed: _editSettings,
              icon: const Icon(Icons.settings_outlined),
              tooltip: '项目设置'),
          IconButton(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              tooltip: '保存'),
          IconButton(
              onPressed: _buildAndInstall,
              icon: const Icon(Icons.install_desktop_outlined),
              tooltip: '构建并安装'),
          FilledButton.icon(
              onPressed: _run,
              icon: const Icon(Icons.play_arrow),
              label: const Text('运行')),
          const SizedBox(width: 8),
        ],
      ),
      drawer: wide ? null : Drawer(child: leftPanel),
      body: Row(
        children: [
          if (wide) SizedBox(width: 248, child: leftPanel),
          if (wide) const VerticalDivider(width: 1),
          Expanded(child: _buildEditor()),
        ],
      ),
      floatingActionButton: wide
          ? null
          : Builder(
              builder: (ctx) => FloatingActionButton(
                onPressed: () => Scaffold.of(ctx).openDrawer(),
                child: const Icon(Icons.folder_outlined),
              ),
            ),
    );
  }

  Widget _buildFileList() {
    final scheme = Theme.of(context).colorScheme;
    final entries = <Widget>[];
    entries.add(ListTile(
      leading: const Icon(Icons.settings_outlined),
      title: const Text('项目设置', style: TextStyle(fontSize: 13)),
      onTap: _editSettings,
    ));
    entries.add(const Divider(height: 1));
    _project.files.forEach((path, _) {
      final selected = path == _selected;
      entries.add(ListTile(
        selected: selected,
        leading: Icon(
          selected ? Icons.description : Icons.description_outlined,
          size: 18,
        ),
        title: Text(path,
            style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
        selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.25),
        onTap: () => _select(path),
      ));
    });
    return Column(
      children: [
        Expanded(child: ListView(children: entries)),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.note_add_outlined),
          title: const Text('新建文件', style: TextStyle(fontSize: 13)),
          onTap: _newFile,
        ),
        if (_selected != null)
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('删除当前文件', style: TextStyle(fontSize: 13)),
            onTap: _deleteFile,
          ),
      ],
    );
  }

  Widget _buildEditor() {
    if (_selected == null) {
      return Center(
        child: Text('没有文件',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
    }
    final controller = _ensureController(_selected);
    return Container(
      color: const Color(0xFF0B0E13),
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: controller,
        expands: true,
        maxLines: null,
        minLines: null,
        textAlignVertical: TextAlignVertical.top,
        style: const TextStyle(
            fontFamily: 'monospace', fontSize: 13.5, height: 1.5),
        decoration: InputDecoration.collapsed(
          hintText: '在此编写 ${_selected!}',
          border: InputBorder.none,
        ),
        onChanged: (_) {},
      ),
    );
  }
}

class _ManifestDialog extends StatefulWidget {
  final AtaManifest manifest;
  const _ManifestDialog({required this.manifest});

  @override
  State<_ManifestDialog> createState() => _ManifestDialogState();
}

class _ManifestDialogState extends State<_ManifestDialog> {
  late final TextEditingController _id;
  late final TextEditingController _name;
  late final TextEditingController _version;
  late final TextEditingController _author;
  late final TextEditingController _desc;
  late final TextEditingController _entry;
  late final TextEditingController _type;
  late final Set<String> _perms;

  static const _known = [
    'atak:display',
    'atak:input',
    'atak:http',
    'atak:open',
    'atak:storage',
    'atak:notify',
  ];

  @override
  void initState() {
    super.initState();
    final m = widget.manifest;
    _id = TextEditingController(text: m.id);
    _name = TextEditingController(text: m.name);
    _version = TextEditingController(text: m.version);
    _author = TextEditingController(text: m.author);
    _desc = TextEditingController(text: m.description);
    _entry = TextEditingController(text: m.entry);
    _type = TextEditingController(text: m.type);
    _perms = {...m.permissions};
  }

  @override
  void dispose() {
    for (final c in [_id, _name, _version, _author, _desc, _entry, _type]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('项目设置'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: _id,
                decoration: const InputDecoration(labelText: 'id（反向域名）')),
            TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: '名称')),
            TextField(
                controller: _version,
                decoration: const InputDecoration(labelText: '版本')),
            TextField(
                controller: _author,
                decoration: const InputDecoration(labelText: '作者')),
            TextField(
                controller: _desc,
                decoration: const InputDecoration(labelText: '描述')),
            TextField(
                controller: _entry,
                decoration:
                    const InputDecoration(labelText: '入口脚本（如 app.ata）')),
            TextField(
                controller: _type,
                decoration:
                    const InputDecoration(labelText: '类型（app/widget/cli）')),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('权限', style: TextStyle(fontSize: 13, color: Colors.grey)),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final p in _known)
                  FilterChip(
                    label: Text(p.split(':').last),
                    selected: _perms.contains(p),
                    onSelected: (v) =>
                        setState(() => v ? _perms.add(p) : _perms.remove(p)),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消')),
        FilledButton(
          onPressed: () {
            final m = widget.manifest.copyWith(
              id: _id.text.trim(),
              name: _name.text.trim(),
              version: _version.text.trim(),
              author: _author.text.trim(),
              description: _desc.text.trim(),
              entry: _entry.text.trim().isEmpty ? 'app.ata' : _entry.text.trim(),
              type: _type.text.trim().isEmpty ? 'app' : _type.text.trim(),
              permissions: _perms.toList(),
            );
            Navigator.pop(context, m);
          },
          child: const Text('确定'),
        ),
      ],
    );
  }
}
