/// 应用图标组件：从安装目录读取图标字节，加载失败显示默认图形。
library;

import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../../app_services.dart';

class AppIcon extends StatelessWidget {
  final String id;
  final String? iconPath;
  final double size;
  final Color? tint;

  const AppIcon({
    super.key,
    required this.id,
    this.iconPath,
    this.size = 48,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint ?? scheme.primaryContainer,
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      child: Icon(Icons.widgets_outlined, size: size * 0.55, color: scheme.onPrimaryContainer),
    );
    if (iconPath == null || iconPath!.isEmpty) return fallback;
    return FutureBuilder<Uint8List?>(
      future: _load(),
      builder: (context, snap) {
        final bytes = snap.data;
        if (bytes == null || bytes.isEmpty) return fallback;
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.25),
            image: DecorationImage(
              image: MemoryImage(bytes),
              fit: BoxFit.cover,
            ),
          ),
        );
      },
    );
  }

  Future<Uint8List?> _load() => Future.value(
      AppServices.instance.installer.readResource(id, iconPath!));
}