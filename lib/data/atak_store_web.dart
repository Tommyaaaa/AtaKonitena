// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

/// AtakStore 基于 LocalStorage 的 Web 实现。
/// 数据以单个 JSON 键保存在 localStorage 中，字节以 base64 编码。
library;

import 'dart:convert';
import 'dart:typed_data';
import 'dart:html' as html;
import 'atak_store.dart';

class AtakStoreWeb implements AtakStore {
  static const _key = 'atakonitena.store';
  final Map<String, String> _memory = {}; // path -> base64

  AtakStoreWeb() {
    final raw = html.window.localStorage[_key];
    if (raw != null) {
      try {
        final m = jsonDecode(raw) as Map;
        m.forEach((k, v) => _memory['$k'] = '$v');
      } catch (_) {}
    }
  }

  @override
  bool get ready => true;

  @override
  Future<void> init() async {}

  void _persist() {
    html.window.localStorage[_key] = jsonEncode(_memory);
  }

  String _norm(String path) =>
      path.replaceAll('\\', '/').split('/').join('/');

  @override
  List<String> listChildren(String dir) {
    final prefix = _norm(dir).isEmpty ? '' : '${_norm(dir)}/';
    final names = <String>{};
    for (final p in _memory.keys.where((k) =>
        prefix.isEmpty ? true : k.startsWith(prefix))) {
      final rest = prefix.isEmpty ? p : p.substring(prefix.length);
      if (rest.isEmpty || !rest.contains('/')) {
        if (rest.isNotEmpty) names.add(rest);
      } else {
        names.add(rest.split('/').first);
      }
    }
    return names.toList();
  }

  @override
  bool exists(String path) => _memory.containsKey(_norm(path));

  @override
  String? readText(String path) {
    final b = readBytes(path);
    return b == null ? null : utf8.decode(b, allowMalformed: true);
  }

  @override
  Uint8List? readBytes(String path) {
    final b64 = _memory[_norm(path)];
    if (b64 == null) return null;
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  @override
  void writeText(String path, String content) {
    _memory[_norm(path)] = base64Encode(utf8.encode(content));
    _persist();
  }

  @override
  void writeBytes(String path, Uint8List bytes) {
    _memory[_norm(path)] = base64Encode(bytes);
    _persist();
  }

  @override
  void deleteRecursive(String path) {
    final p = _norm(path);
    _memory.removeWhere((k, _) => k == p || k.startsWith('$p/'));
    _persist();
  }
}

Future<AtakStore> createDefault() async {
  return AtakStoreWeb();
}