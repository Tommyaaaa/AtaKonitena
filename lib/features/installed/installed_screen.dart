/// 已安装应用列表：查看 / 启动 / 卸载 / 导入。
library;

import 'package:flutter/material.dart';
import '../../app_services.dart';
import '../../core/atak/atak_manifest.dart';
import '../import/importer.dart';
import '../run/run_app_screen.dart';
import '../widgets/app_icon.dart';

class InstalledScreen extends StatefulWidget {
  const InstalledScreen({super.key});

  @override
  State<InstalledScreen> createState() => _InstalledScreenState();
}

class _InstalledScreenState extends State<InstalledScreen> {
  List<AtaManifest> _apps = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    try {
      final apps = AppServices.instance.installer.listInstalled();
      setState(() {
        _apps = apps;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
      });
    }
  }

  Future<void> _repair() async {
    try {
      AppServices.instance.storage.repairIndex();
      _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('存储索引已修复')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('修复失败：$e')),
      );
    }
  }

  Future<void> _launch(AtaManifest manifest) async {
    final installer = AppServices.instance.installer;
    final source = installer.readEntrySource(manifest.id, manifest.entry);
    if (source == null) {
      _toast('找不到入口脚本 ${manifest.entry}');
      return;
    }
    final session = AppServices.instance.containerManager
        .createSession(manifest, source);
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RunAppScreen(session: session),
    ));
    _reload();
  }

  Future<void> _uninstall(AtaManifest manifest) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('卸载 ${manifest.name}'),
        content: const Text('应用与其沙盒数据将被一并删除。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('卸载')),
        ],
      ),
    );
    if (ok == true) {
      AppServices.instance.installer.uninstall(manifest.id);
      _reload();
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    // 错误状态：存储读取异常时显示修复入口，而非灰屏
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                size: 64, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            const Text('存储读取异常'),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                '应用数据可能已损坏。尝试修复索引或重置存储。',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _repair,
              icon: const Icon(Icons.build_outlined),
              label: const Text('修复索引'),
            ),
          ],
        ),
      );
    }

    if (_apps.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            const Text('还没有安装任何应用'),
            const SizedBox(height: 8),
            Text('到「应用市场」安装示例，或导入 .atak 文件',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                await importAtakFile(context, onInstalled: (_) => _reload());
              },
              icon: const Icon(Icons.add),
              label: const Text('导入 .atak'),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _apps.length,
        itemBuilder: (context, i) => _card(_apps[i]),
      ),
    );
  }

  Widget _card(AtaManifest m) {
    final scheme = Theme.of(context).colorScheme;
    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AppIcon(id: m.id, iconPath: m.iconPath, size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(m.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text('v${m.version}  ·  ${m.author}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          IconButton(
            tooltip: '卸载',
            onPressed: () => _uninstall(m),
            icon: Icon(Icons.delete_outline,
                size: 20, color: scheme.onSurfaceVariant),
          ),
          FilledButton.tonalIcon(
            onPressed: () => _launch(m),
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('启动'),
          ),
        ],
      ),
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(onTap: () => _launch(m), child: content),
    );
  }
}
