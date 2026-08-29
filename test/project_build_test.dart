/// 内置项目编辑器：打包 .atak / 持久化 / 运行 的单元测试（纯 Dart）。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:atakonitena/core/atak/atak_package.dart';
import 'package:atakonitena/core/ata_language/lexer.dart';
import 'package:atakonitena/core/ata_language/parser.dart';
import 'package:atakonitena/core/ata_language/interpreter.dart';
import 'package:atakonitena/core/ata_language/host.dart';
import 'package:atakonitena/data/atak_store.dart';
import 'package:atakonitena/features/editor/project_service.dart';

/// 内存版 AtakStore（不依赖 dart:html，可在 VM 测试中使用）。
class _MemoryStore implements AtakStore {
  final Map<String, String> _data = {}; // path -> base64

  String _norm(String path) => path.replaceAll('\\', '/');

  @override
  bool get ready => true;

  @override
  Future<void> init() async {}

  @override
  List<String> listChildren(String dir) {
    final prefix = _norm(dir).isEmpty ? '' : '${_norm(dir)}/';
    final names = <String>{};
    for (final k in _data.keys.where((k) =>
        prefix.isEmpty ? true : k.startsWith(prefix))) {
      final rest = prefix.isEmpty ? k : k.substring(prefix.length);
      if (rest.isEmpty) continue;
      names.add(rest.contains('/') ? rest.split('/').first : rest);
    }
    return names.toList();
  }

  @override
  bool exists(String path) => _data.containsKey(_norm(path));

  @override
  String? readText(String path) {
    final b = readBytes(path);
    return b == null ? null : utf8.decode(b, allowMalformed: true);
  }

  @override
  Uint8List? readBytes(String path) {
    final b64 = _data[_norm(path)];
    return b64 == null ? null : base64Decode(b64);
  }

  @override
  void writeText(String path, String content) =>
      _data[_norm(path)] = base64Encode(utf8.encode(content));

  @override
  void writeBytes(String path, Uint8List bytes) =>
      _data[_norm(path)] = base64Encode(bytes);

  @override
  void deleteRecursive(String path) {
    final p = _norm(path);
    _data.removeWhere((k, _) => k == p || k.startsWith('$p/'));
  }
}

void main() {
  group('AtaProject / ProjectService', () {
    late _MemoryStore store;
    late ProjectService svc;

    setUp(() {
      store = _MemoryStore();
      svc = ProjectService(store);
    });

    test('默认项目可打包为可解码的 .atak', () {
      final proj = svc.createDefault(name: '测试应用');
      final bytes = svc.build(proj);
      final archive = AtakArchive.decode(bytes);
      expect(archive.manifest.name, '测试应用');
      expect(archive.manifest.entry, 'app.ata');
      expect(archive.entrySource, contains('ata.heading'));
    });

    test('多文件项目打包后保留其余文本文件', () {
      final base = svc.createDefault(name: '多文件');
      final proj = base.copyWith(files: {
        ...base.files,
        'lib/helper.ata': '// helper\n',
        'README.md': '# readme\n'
      });
      final archive = AtakArchive.decode(svc.build(proj));
      expect(archive.readText('lib/helper.ata'), contains('helper'));
      expect(archive.readText('README.md'), contains('readme'));
    });

    test('入口脚本缺失时 build 抛 StateError', () {
      final base = svc.createDefault();
      final broken = base.copyWith(files: {});
      expect(() => svc.build(broken), throwsStateError);
    });

    test('项目可保存并重新加载', () {
      final proj = svc.createDefault(name: '保存测试');
      svc.save(proj);
      final loaded = svc.load(proj.manifest.id);
      expect(loaded, isNotNull);
      expect(loaded!.manifest.name, '保存测试');
      expect(loaded.files.containsKey('app.ata'), isTrue);
    });

    test('listProjects 列出已保存项目', () {
      svc.save(svc.createDefault(name: '项目A'));
      svc.save(svc.createDefault(id: 'com.example.b', name: '项目B'));
      expect(svc.listProjects().length, 2);
    });

    test('打包后的入口源码可被解释器执行', () {
      final proj = svc.createDefault(name: '运行测试');
      final archive = AtakArchive.decode(svc.build(proj));
      final source = archive.entrySource!;
      // 仅校验可被词法/语法/解释器正确解析执行（不依赖 UI）。
      final interp = Interpreter(host: _NoopHost(), granted: {'atak:display'});
      expect(
        () async {
          final parser = Parser(Lexer(source).tokenize());
          await interp.interpret(parser.parse());
        },
        returnsNormally,
      );
    });
  });
}

/// 仅用于“能否执行”校验的空宿主。
class _NoopHost implements AtaHost {
  @override
  String get appId => 'test.build';
  @override
  Map<String, dynamic> get manifest => {'id': 'test.build', 'name': 'B'};
  @override
  Future<void> log(String message) async {}
  @override
  Future<void> renderChunk(AtaUiChunk chunk) async {}
  @override
  Future<void> clearUi() async {}
  @override
  Future<String?> input(String prompt) async => null;
  @override
  Future<bool> confirm(String message) async => false;
  @override
  Future<void> alert(String message) async {}
  @override
  Future<void> notify(String title, String body) async {}
  @override
  Future<AtaHttpResult> http(String method, String url,
          {Map<String, String>? headers, Object? body}) async =>
      AtaHttpResult(0, '', {});
  @override
  Future<void> openUrl(String url) async {}
  @override
  Object? storeGet(String key) => null;
  @override
  Future<void> storeSet(String key, Object? value) async {}
  @override
  Future<void> storeRemove(String key) async {}
  @override
  Future<void> exit(Object? value) async {}
}
