/// AtakStore 基于 dart:io 文件系统的实现（Android/iOS/桌面端）。
library;

import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'atak_store.dart';

class AtakStoreIO implements AtakStore {
  Directory? _root;
  AtakStoreIO();

  @override
  bool get ready => _root != null;

  @override
  Future<void> init() async {
    if (_root != null) return;
    final support = await getApplicationSupportDirectory();
    _root = Directory('${support.path}/atak');
    _root!.createSync(recursive: true);
  }

  String? _resolve(String path) {
    if (_root == null) return null;
    final root = _root!.path;
    // 防目录穿越
    final clean = path.replaceAll('\\', '/').split('/').where((e) => e.isNotEmpty && e != '.').join('/');
    return '$root/$clean';
  }

  String? _clean(String path) => _resolve(path);

  @override
  List<String> listChildren(String dir) {
    final p = _clean(dir);
    if (p == null) return const [];
    final d = Directory(p);
    if (!d.existsSync()) return const [];
    return d.listSync(recursive: false).map((e) => e.path.split('/').last).toList();
  }

  @override
  bool exists(String path) {
    final p = _clean(path);
    return p != null && File(p).existsSync();
  }

  @override
  String? readText(String path) {
    final p = _clean(path);
    if (p == null || !File(p).existsSync()) return null;
    return File(p).readAsStringSync();
  }

  @override
  Uint8List? readBytes(String path) {
    final p = _clean(path);
    if (p == null || !File(p).existsSync()) return null;
    return File(p).readAsBytesSync();
  }

  @override
  void writeText(String path, String content) {
    writeBytes(path, Uint8List.fromList(content.codeUnits));
  }

  @override
  void writeBytes(String path, Uint8List bytes) {
    final p = _clean(path);
    if (p == null) return;
    File(p).parent.createSync(recursive: true);
    File(p).writeAsBytesSync(bytes);
  }

  @override
  void deleteRecursive(String path) {
    final p = _clean(path);
    if (p == null) return;
    final d = Directory(p);
    if (d.existsSync()) {
      d.deleteSync(recursive: true);
      return;
    }
    final f = File(p);
    if (f.existsSync()) f.deleteSync();
  }
}

Future<AtakStore> createDefault() async {
  final s = AtakStoreIO();
  await s.init();
  return s;
}