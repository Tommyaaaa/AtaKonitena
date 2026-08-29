/// 应用运行界面：显示沙盒会话的 UI 画布与日志，并桥接对话框能力。
library;

import 'package:flutter/material.dart';
import '../../core/ata_language/host.dart';
import '../../core/atak/atak_manifest.dart';
import '../../core/container/container_manager.dart';

class RunAppScreen extends StatefulWidget {
  final AppSession session;
  const RunAppScreen({super.key, required this.session});

  @override
  State<RunAppScreen> createState() => _RunAppScreenState();
}

class _RunAppScreenState extends State<RunAppScreen>
    with SingleTickerProviderStateMixin, LiveHostBridge {
  late TabController _tab;
  int _pendingInput = 0;

  @override
  void initState() {
    super.initState();
    widget.session.bridge = this;
    _tab = TabController(length: 2, vsync: this);
    _start();
  }

  Future<void> _start() async {
    await widget.session.start();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tab.dispose();
    if (widget.session.bridge == this) {
      widget.session.bridge = null;
    }
    super.dispose();
  }

  AtaManifest get _m => widget.session.manifest;

  @override
  Future<String?> showInput(String prompt) async {
    final controller = TextEditingController();
    _pendingInput++;
    if (mounted) setState(() {});
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ata 输入'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: prompt),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('确定')),
        ],
      ),
    );
    controller.dispose();
    _pendingInput--;
    if (mounted) setState(() {});
    return result;
  }

  @override
  Future<bool> showConfirm(String message) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ata 确认'),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确定')),
        ],
      ),
    );
    return r ?? false;
  }

  @override
  Future<void> showAlert(String message) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ata 提示'),
        content: Text(message),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('好')),
        ],
      ),
    );
  }

  @override
  Future<void> showNotify(String title, String body) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title\n$body'), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appBar = AppBar(
      title: Text(_m.name,
          style: const TextStyle(fontWeight: FontWeight.bold)),
    );
    return Scaffold(
      appBar: appBar,
      body: ListenableBuilder(
        listenable: widget.session,
        builder: (context, _) {
          final s = widget.session;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Icon(_statusIcon(s),
                        size: 16,
                        color: s.running
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      s.running ? '运行中…' : '已结束',
                      style:
                          TextStyle(color: s.running ? null : Colors.grey),
                    ),
                    const Spacer(),
                    if (_pendingInput > 0)
                      const Chip(
                          label: Text('等待输入'),
                          visualDensity: VisualDensity.compact),
                  ],
                ),
              ),
              TabBar(
                controller: _tab,
                tabs: const [
                  Tab(text: '界面'),
                  Tab(text: '日志'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [_buildUi(s), _buildLog(s)],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  IconData _statusIcon(AppSession s) =>
      s.running ? Icons.directions_run : Icons.check_circle_outline;

  Widget _buildUi(AppSession s) {
    if (s.chunks.isEmpty) {
      return Center(
        child: Text(
          s.errors.isNotEmpty ? '发生错误，请看日志。' : '（应用尚未输出内容）',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        for (final c in s.chunks) _chunkWidget(c),
      ],
    );
  }

  Widget _chunkWidget(AtaUiChunk c) {
    final scheme = Theme.of(context).colorScheme;
    return switch (c.kind) {
      'heading' => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(c.content,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ),
      'error' => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(c.content,
              style: TextStyle(color: scheme.error, fontFamily: 'monospace')),
        ),
      _ => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: SelectableText(c.content,
              style: Theme.of(context).textTheme.bodyLarge),
        ),
    };
  }

  Widget _buildLog(AppSession s) {
    final items = <Widget>[];
    for (final l in s.logs) {
      items.add(Text(l,
          style: const TextStyle(
              fontFamily: 'monospace', fontSize: 12.5, height: 1.4)));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: items.isEmpty
          ? [
              Text('（无日志）',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ]
          : items,
    );
  }
}