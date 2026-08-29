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

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(() {
        _apps = AppServices.instance.installer.listInstalled();
      });

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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          if (wide) {
            final columns =
                ((constraints.maxWidth - 48) / 280).floor().clamp(2, 6);
            return GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.5,
              ),
              itemCount: _apps.length,
              itemBuilder: (context, i) => _card(_apps[i], grid: true),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _apps.length,
            itemBuilder: (context, i) => _card(_apps[i]),
          );
        },
      ),
    );
  }

  Widget _card(AtaManifest m, {bool grid = false}) {
    final scheme = Theme.of(context).colorScheme;
    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment:
            grid ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          AppIcon(id: m.id, iconPath: m.iconPath, size: grid ? 56 : 44),
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
      child: InkWell(onTap: () => _launch(m), child: content),
    );
  }
}