/// AtakStorage：基于 [AtakStore] 的安装/沙盒目录布局。
/// <pre>
/// {root}/
///   ├── installed.json          # 已安装应用索引 {id: manifest}
///   ├── installed/{id}/         # 解压后的应用包内容
///   └── containers/{id}/        # 每个应用的沙盒隔离数据目录
/// </pre>
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../data/atak_store.dart';

class AtakStorage {
  final AtakStore store;

  AtakStorage(this.store);

  bool get ready => store.ready;
  Future<void> init() => store.init();

  String appDir(String id) => 'installed/$id';
  String containerDir(String id) => 'containers/$id';
  String containerStoreFile(String id) => 'containers/$id/store.json';

  List<String> listAppIds() => store.listChildren('installed');

  Map<String, Map<String, dynamic>> readIndex() {
    String? raw;
    try {
      raw = store.readText('installed.json');
    } catch (_) {
      return {};
    }
    if (raw == null) return {};
    try {
      final m = jsonDecode(raw);
      if (m is! Map) return {};
      return m.map((k, v) => MapEntry('$k', (v as Map).map(
          (kk, vv) => MapEntry('$kk', vv))));
    } catch (_) {
      return {};
    }
  }

  void writeIndex(Map<String, Map<String, dynamic>> index) {
    if (!store.ready) return;
    store.writeText('installed.json',
        const JsonEncoder.withIndent('  ').convert(index));
  }

  // ---------- 容器沙盒键值存储 ----------

  Map<String, dynamic> _readContainerStore(String id) {
    String? raw;
    try {
      raw = store.readText(containerStoreFile(id));
    } catch (_) {
      return {};
    }
    if (raw == null) return {};
    try {
      final m = jsonDecode(raw);
      if (m is Map) {
        return m.map((k, v) => MapEntry('$k', v));
      }
    } catch (_) {}
    return {};
  }

  Object? containerGet(String id, String key) => _readContainerStore(id)[key];

  void containerSet(String id, String key, Object? value) {
    final map = _readContainerStore(id);
    map[key] = value;
    if (!store.ready) return;
    store.writeText(containerStoreFile(id), jsonEncode(map));
  }

  void containerRemove(String id, String key) {
    final map = _readContainerStore(id);
    map.remove(key);
    if (!store.ready) return;
    store.writeText(containerStoreFile(id), jsonEncode(map));
  }

  @visibleForTesting
  Map<String, dynamic> debugContainerStore(String id) =>
      _readContainerStore(id);

  /// 修复索引：扫描 installed/ 目录，从每个应用包的 manifest.json 重建索引。
  /// 当 installed.json 丢失或损坏时调用。
  void repairIndex() {
    final ids = listAppIds();
    final index = <String, Map<String, dynamic>>{};
    for (final id in ids) {
      final raw = store.readText('${appDir(id)}/manifest.json');
      if (raw == null) continue;
      try {
        final m = jsonDecode(raw);
        if (m is Map) {
          index[id] = m.map((k, v) => MapEntry('$k', v));
        }
      } catch (_) {
        // 跳过无法解析的清单
      }
    }
    writeIndex(index);
  }

  /// 重置全部存储（用于极端损坏场景）。
  void resetAll() {
    store.deleteRecursive('installed');
    store.deleteRecursive('containers');
    store.deleteRecursive('installed.json');
  }
}
