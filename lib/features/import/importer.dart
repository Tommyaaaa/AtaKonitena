/// 从外部文件导入并安装 .atak。
library;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../app_services.dart';
import '../../core/atak/atak_manifest.dart';
import '../../core/atak/atak_package.dart';
import '../../data/path_reader.dart';

/// 选择 .atak 文件并安装，返回清单；出错返回 null 并提示。
Future<AtaManifest?> importAtakFile(BuildContext context,
    {ValueChanged<AtaManifest>? onInstalled}) async {
  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['atak'],
      withData: true,
    );
    if (result == null) return null;
    final file = result.files.single;
    final bytes = file.bytes ??
        (file.path != null ? readPathBytes(file.path!) : null);
    if (bytes == null) {
      if (!context.mounted) return null;
      _toast(context, '无法读取所选文件');
      return null;
    }
    final installer = AppServices.instance.installer;
    final AtaManifest manifest;
    try {
      manifest = AtakArchive.decode(bytes).manifest;
      installer.install(bytes);
    } on FormatException catch (e) {
      if (!context.mounted) return null;
      _toast(context, '安装失败：${e.message}');
      return null;
    } catch (e) {
      if (!context.mounted) return null;
      _toast(context, '安装失败：$e');
      return null;
    }
    if (!context.mounted) return null;
    _toast(context, '已安装：${manifest.name} v${manifest.version}');
    onInstalled?.call(manifest);
    return manifest;
  } catch (e) {
    if (!context.mounted) return null;
    _toast(context, '导入错误：$e');
    return null;
  }
}

void _toast(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));
}