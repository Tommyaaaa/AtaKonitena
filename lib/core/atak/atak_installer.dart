/// `.atak` 应用安装器：安装 / 升级 / 卸载 / 查询。
library;

import 'dart:typed_data';
import 'atak_manifest.dart';
import 'atak_package.dart';
import 'atak_storage.dart';

enum InstallResult { installed, upgraded, downgraded }

class AtakInstaller {
  final AtakStorage storage;

  AtakInstaller(this.storage);

  /// 从 .atak 字节流安装，覆盖同 id 已有版本。
  InstallResult install(Uint8List bytes) {
    final archive = AtakArchive.decode(bytes);
    final manifest = archive.manifest;

    final index = storage.readIndex();
    final existed = index.containsKey(manifest.id);
    final existedVersion = existed ? (index[manifest.id]?['version'] as String?) : null;

    for (final f in archive.archive.files) {
      final rel = f.name.replaceFirst(RegExp(r'^\./'), '');
      if (rel.isEmpty) continue;
      storage.store.writeBytes('${storage.appDir(manifest.id)}/$rel',
          f.content as Uint8List);
    }

    index[manifest.id] = manifest.toJson();
    storage.writeIndex(index);

    if (!existed) return InstallResult.installed;
    return _compare(existedVersion, manifest.version);
  }

  InstallResult _compare(String? existed, String newVer) {
    if (existed == null) return InstallResult.installed;
    try {
      final cmp = _cmpVersion(existed, newVer);
      return cmp < 0
          ? InstallResult.upgraded
          : cmp > 0
              ? InstallResult.downgraded
              : InstallResult.installed;
    } catch (_) {
      return existed == newVer ? InstallResult.installed : InstallResult.upgraded;
    }
  }

  int _cmpVersion(String a, String b) {
    final pa = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final pb = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final n = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < n; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x < y ? -1 : 1;
    }
    return 0;
  }

  /// 卸载应用（删除包与沙盒数据）。
  void uninstall(String id) {
    storage.store.deleteRecursive(storage.appDir(id));
    storage.store.deleteRecursive(storage.containerDir(id));
    final index = storage.readIndex();
    index.remove(id);
    storage.writeIndex(index);
  }

  /// 列出已安装应用清单（按名称排序）。
  List<AtaManifest> listInstalled() {
    final index = storage.readIndex();
    final result = <AtaManifest>[];
    index.forEach((id, json) {
      try {
        result.add(AtaManifest.fromJson(json));
      } catch (_) {}
    });
    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

  bool isInstalled(String id) => storage.readIndex().containsKey(id);

  /// 读取应用的入口脚本源码。
  String? readEntrySource(String id, String entry) =>
      storage.store.readText('${storage.appDir(id)}/$entry');

  /// 读取应用资源（如图标）。
  Uint8List? readResource(String id, String relPath) =>
      storage.store.readBytes('${storage.appDir(id)}/$relPath');
}