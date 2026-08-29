/// AtakStore 抽象：屏蔽桌面/移动（文件系统）与 Web（localStorage）差异，
/// 令整个安装/沙盒体系全端可用。
library;

import 'dart:typed_data';

export 'atak_store_factory.dart' show createAtakStore;

abstract class AtakStore {
  bool get ready;

  /// 初始化根目录（幂等）。
  Future<void> init();

  /// 列出 dir 下的条目名（仅一层）。
  List<String> listChildren(String dir);

  /// 判断路径（文件）是否存在。
  bool exists(String path);

  /// 读文本（不存在返回 null）。
  String? readText(String path);

  /// 读字节。
  Uint8List? readBytes(String path);

  /// 写文本（自动建目录）。
  void writeText(String path, String content);

  /// 写字节。
  void writeBytes(String path, Uint8List bytes);

  /// 递归删除路径。
  void deleteRecursive(String path);
}