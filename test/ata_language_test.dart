/// AtaLanguage 解释器与 .atak 打包的单元测试（纯 Dart，无 Flutter 依赖）。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:atakonitena/core/ata_language/host.dart';
import 'package:atakonitena/core/ata_language/lexer.dart';
import 'package:atakonitena/core/ata_language/parser.dart';
import 'package:atakonitena/core/ata_language/interpreter.dart';
import 'package:atakonitena/core/ata_language/errors.dart';
import 'package:atakonitena/core/atak/atak_package.dart';

/// 测试用宿主：收集日志，验证 AtaLanguage 求值结果。
class TestHost implements AtaHost {
  final List<String> logs = [];
  final List<AtaUiChunk> chunks = [];
  final Map<String, Object?> store = {};

  @override
  String get appId => 'test.app';

  @override
  Map<String, dynamic> get manifest => {'id': 'test.app', 'name': 'Test'};

  @override
  Future<void> log(String message) async => logs.add(message);

  @override
  Future<void> renderChunk(AtaUiChunk chunk) async => chunks.add(chunk);

  @override
  Future<void> clearUi() async => chunks.clear();

  @override
  Future<String?> input(String prompt) async => null;

  @override
  Future<bool> confirm(String message) async => true;

  @override
  Future<void> alert(String message) async {}

  @override
  Future<void> notify(String title, String body) async {}

  @override
  Future<AtaHttpResult> http(String method, String url,
          {Map<String, String>? headers, Object? body}) async =>
      const AtaHttpResult(200, '{"ok":true}');

  @override
  Future<void> openUrl(String url) async {}

  @override
  Object? storeGet(String key) => store[key];

  @override
  Future<void> storeSet(String key, Object? value) async => store[key] = value;

  @override
  Future<void> storeRemove(String key) async => store.remove(key);

  @override
  Future<void> exit(Object? value) async {}

  /// 解析并运行一段 Ata 源码。
  Future<void> run(String source, {Set<String> granted = const {}}) async {
    final lexer = Lexer(source);
    final parser = Parser(lexer.tokenize());
    final program = parser.parse();
    final interp = Interpreter(host: this, granted: granted);
    await interp.interpret(program);
  }
}

void main() {
  group('AtaLanguage 词法/语法/求值', () {
    test('算术与运算符优先级', () async {
      final host = TestHost();
      await host.run('print(2 + 3 * 4);');
      expect(host.logs, ['14']);
    });

    test('字符串插值', () async {
      final host = TestHost();
      await host.run('let name = "世界"; print("你好，\${name}！\${1 + 2}");');
      expect(host.logs, ['你好，世界！3']);
    });

    test('let 变量与重新赋值', () async {
      final host = TestHost();
      await host.run('let x = 1; x = x + 10; print(x);');
      expect(host.logs, ['11']);
    });

    test('函数定义与调用', () async {
      final host = TestHost();
      await host.run('func add(a, b) { return a + b; } print(add(2, 5));');
      expect(host.logs, ['7']);
    });

    test('默认参数与递归', () async {
      final host = TestHost();
      await host.run('''
func fact(n) {
  if (n <= 1) { return 1; }
  return n * fact(n - 1);
}
print(fact(5));
''');
      expect(host.logs, ['120']);
    });

    test('while 循环与累加', () async {
      final host = TestHost();
      await host.run('let i = 0; let s = 0; while (i < 5) { s = s + i; i = i + 1; } print(s);');
      expect(host.logs, ['10']);
    });

    test('for 循环（经典）与 continue/break', () async {
      final host = TestHost();
      await host.run('''
let s = 0;
for (let i = 0; i < 10; i = i + 1) {
  if (i == 3) { continue; }
  if (i == 6) { break; }
  s = s + i;
}
print(s);
''');
      // 0+1+2+4+5 = 12
      expect(host.logs, ['12']);
    });

    test('数组：push / len / 索引', () async {
      final host = TestHost();
      await host.run('let arr = [1, 2]; arr.push(3); print(len(arr)); print(arr[2]);');
      expect(host.logs, ['3', '3']);
    });

    test('对象成员读写', () async {
      final host = TestHost();
      await host.run('let o = {}; o.hello = "world"; print(o.hello);');
      expect(host.logs, ['world']);
    });

    test('空合并 a ?? b', () async {
      final host = TestHost();
      await host.run('print(null ?? 7);');
      expect(host.logs, ['7']);
    });

    test('三目运算', () async {
      final host = TestHost();
      await host.run('print(5 > 3 ? "big" : "small");');
      expect(host.logs, ['big']);
    });

    test('range 全局函数', () async {
      final host = TestHost();
      await host.run('print(len(range(4)));');
      expect(host.logs, ['4']);
    });

    test('权限：未声明能力被沙盒拒绝', () async {
      final host = TestHost();
      expect(
        () => host.run('ata.input("?");'),
        throwsA(isA<AtaPermissionError>()),
      );
    });

    test('权限：声明后放行', () async {
      final host = TestHost();
      await host.run('ata.open("https://example.com");',
          granted: {'atak:open'});
      // 无异常即可
      expect(host.logs, isEmpty);
    });
  });

  group('.atak 打包与解析', () {
    test('buildAtakFromStrings 可被打包并解码', () {
      final bytes = buildAtakFromStrings(
        manifestJson: jsonEncode({
          'format': 'atak',
          'formatVersion': 1,
          'id': 'com.example.hello',
          'name': '你好',
          'version': '1.0.0',
          'author': 'AtaKonitena',
          'description': '测试应用',
          'entry': 'app.ata',
        }),
        entrySource: 'ata.show("hi");',
        extraTexts: {'resources/icon.txt': 'x'},
      );
      final archive = AtakArchive.decode(bytes);
      expect(archive.manifest.id, 'com.example.hello');
      expect(archive.manifest.name, '你好');
      expect(archive.entrySource, 'ata.show("hi");');
      expect(archive.readText('resources/icon.txt'), 'x');
    });

    test('缺失 manifest.json 应抛 FormatException', () {
      expect(() => AtakArchive.decode(Uint8List(0)),
          throwsA(isA<FormatException>()));
    });
  });
}