/// `.atak` 包（Zip 容器）的内存读写与构建。
/// `.atak` 本质是一个 Zip 归档，标准结构：
///   manifest.json   —— 应用清单
///   app.ata         —— 入口脚本（AtaLanguage）
///   resources/...   —— 图标及资源
///   vendor/...      —— 可选：随包内置的 AtaLanguage 模块
library;

import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'atak_manifest.dart';

/// 在内存中代表一个 .atak 归档。
class AtakArchive {
  final Uint8List bytes;
  final Archive archive;
  final AtaManifest manifest;

  AtakArchive._(this.bytes, this.archive, this.manifest);

  static AtakArchive decode(Uint8List bytes) {
    final ZipDecoder decoder = ZipDecoder();
    final Archive archive = decoder.decodeBytes(bytes);
    final manifestBytes = _readBytes(archive, 'manifest.json');
    if (manifestBytes == null) {
      throw const FormatException('.atak 缺少 manifest.json');
    }
    Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(manifestBytes)) as Map<String, dynamic>;
    } catch (e) {
      throw FormatException('manifest.json 无法解析：$e');
    }
    final manifest = AtaManifest.fromJson(json);
    final errors = manifest.validate();
    if (errors.isNotEmpty) {
      throw FormatException('清单校验失败：${errors.join('；')}');
    }
    return AtakArchive._(bytes, archive, manifest);
  }

  /// 读取包内文本文件。
  String? readText(String path) {
    final b = _readBytes(archive, path);
    return b == null ? null : utf8.decode(b, allowMalformed: true);
  }

  /// 读取包内原始文件。
  Uint8List? readBytes(String path) => _readBytes(archive, path);

  String? get entrySource => readText(manifest.entry);

  /// 图标字节（若无则返回 null）。
  Uint8List? get iconBytes {
    if (manifest.iconPath.isEmpty) return null;
    return readBytes(manifest.iconPath);
  }

  /// 列出所有文件路径。
  List<String> listFiles() =>
      archive.files.map((f) => f.name).where((n) => n.isNotEmpty).toList();

  static Uint8List? _readBytes(Archive archive, String path) {
    for (final f in archive.files) {
      final n = f.name;
      if (n == path || n == './$path' ||
          (n.startsWith('./') && n.substring(2) == path)) {
        return f.content as Uint8List?;
      }
    }
    return null;
  }
}

/// 从字符串构建 .atak（供工具/测试/示例安装用，避免依赖文件系统）。
Uint8List buildAtakFromStrings({
  required String manifestJson,
  String entry = 'app.ata',
  String? entrySource,
  Map<String, String> extraTexts = const {},
  Map<String, Uint8List> extraBytes = const {},
}) {
  final archive = Archive();
  archive.addFile(ArchiveFile.string('manifest.json', manifestJson));
  if (entrySource != null) {
    archive.addFile(ArchiveFile.string(entry, entrySource));
  }
  extraTexts.forEach((path, content) {
    archive.addFile(ArchiveFile.string(path, content));
  });
  extraBytes.forEach((path, content) {
    archive.addFile(ArchiveFile(path, content.length, content));
  });
  final encoder = ZipEncoder();
  final encoded = encoder.encode(archive);
  if (encoded == null) throw StateError('打包失败');
  return Uint8List.fromList(encoded);
}