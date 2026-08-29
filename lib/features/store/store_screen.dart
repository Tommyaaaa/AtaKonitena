/// 应用市场：内置示例安装 + 从 .atak 文件导入。
library;

import 'package:flutter/material.dart';
import '../../app_services.dart';
import '../../core/examples.dart';
import '../import/importer.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  Set<String> _installed = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    try {
      final installer = AppServices.instance.installer;
      setState(() {
        _installed = installer.listInstalled().map((m) => m.id).toSet();
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
      });
    }
  }

  Future<void> _installExample(ExampleApp ex) async {
    try {
      final bytes = await ex.build();
      AppServices.instance.installer.install(bytes);
      final manifest = AppServices.instance.installer
          .listInstalled()
          .firstWhere((m) => m.id == ex.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已安装：${manifest.name} v${manifest.version}')));
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('安装失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // 错误状态：存储读取异常时显示提示而非灰屏
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
            Text('错误：$_error',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                try {
                  AppServices.instance.storage.repairIndex();
                } catch (_) {}
                _reload();
              },
              icon: const Icon(Icons.build_outlined),
              label: const Text('修复并重试'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('内置示例',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            FilledButton.icon(
              onPressed: () async {
                await importAtakFile(context, onInstalled: (_) => _reload());
              },
              icon: const Icon(Icons.file_open_outlined, size: 18),
              label: const Text('导入 .atak'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('以下示例以 AtaLanguage 编写（.ata），安装时实时打包为 .atak 应用。',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 16),
        for (final ex in exampleApps) _exampleCard(ex),
      ],
    );
  }

  Widget _exampleCard(ExampleApp ex) {
    final scheme = Theme.of(context).colorScheme;
    final isInstalled = _installed.contains(ex.id);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.apps, color: scheme.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ex.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('v${ex.version}  ·  ${ex.author}',
                          style: TextStyle(
                              fontSize: 12, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                if (isInstalled)
                  Chip(
                    label: const Text('已安装'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(ex.description),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: [
                for (final p in ex.permissions)
                  Chip(
                    label: Text(_permissionLabel(p), style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _installExample(ex),
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: Text(isInstalled ? '重新安装' : '安装'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _permissionLabel(String p) => switch (p) {
        'atak:display' => '显示',
        'atak:input' => '输入',
        'atak:http' => '网络',
        'atak:open' => '外部链接',
        'atak:storage' => '沙盒存储',
        'atak:notify' => '通知',
        _ => p.split(':').last,
      };
}
