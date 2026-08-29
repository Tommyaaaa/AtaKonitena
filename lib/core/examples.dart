/// 内置示例应用（以源码形式提供，安装时现场打包成 .atak）。
library;

import 'dart:typed_data';
import 'atak/atak_package.dart';

abstract class ExampleApp {
  final String id;
  final String name;
  final String version;
  final String description;
  final String author;
  final List<String> permissions;
  final String entry;

  ExampleApp({
    required this.id,
    required this.name,
    required this.description,
    this.version = '1.0.0',
    this.author = 'AtaKonitena 团队',
    this.permissions = const ['atak:display'],
    this.entry = 'app.ata',
  });

  Future<Uint8List> build() async {
    return buildAtakFromStrings(
      manifestJson: _manifest,
      entry: entry,
      entrySource: source,
    );
  }

  String get _manifest =>
      '''{\n  "format": "atak",\n  "formatVersion": 1,\n  "id": "$id",\n  "name": "$name",\n  "version": "$version",\n  "author": "$author",\n  "description": "$description",\n  "entry": "$entry",\n  "permissions": [${permissions.map((p) => '"$p"').join(', ')}]\n}''';

  String get source;
}

/// 示例应用目录。
final List<ExampleApp> exampleApps = [
  HelloExample(),
  CounterExample(),
  GuessExample(),
];

class HelloExample extends ExampleApp {
  HelloExample()
      : super(
          id: 'com.atakonitena.hello',
          name: '你好世界',
          description: '演示 text / input / confirm / open 等基础能力。',
          permissions: ['atak:display', 'atak:input', 'atak:open'],
        );
  @override
  String get source => r'''
// 你好世界 —— AtaLanguage 入门示例
ata.heading("你好，AtaKonitena！");
ata.show("这是用 AtaLanguage 编写的第一个容器应用。");

let name = ata.input("你的名字？");
if (name != null && name != "") {
  ata.show("欢迎你，${name}！");
} else {
  ata.show("好吧，匿名者。");
}

let ok = ata.confirm("想看看项目主页吗？");
if (ok) {
  ata.open("https://github.com/Tommyaaaa/AtaKonitena");
}

ata.print("运行结束。");
''';
}

class CounterExample extends ExampleApp {
  CounterExample()
      : super(
          id: 'com.atakonitena.counter',
          name: '计数器',
          description: '利用沙盒容器存储（ata.store）持久化计数。',
          permissions: ['atak:display', 'atak:input', 'atak:storage'],
        );
  @override
  String get source => r'''
// 计数器 —— 演示沙盒内持久化存储
let count = ata.store.get("count");
count = (count == null) ? 0 : num(count);
count = count + 1;
ata.store.set("count", count);

ata.heading("计数器 #${count}");
ata.show("这是你第 ${count} 次运行本应用。点击确认计数再加一。");

let go = ata.confirm("继续计数？");
if (go) {
  count = num(ata.store.get("count")) + 1;
  ata.store.set("count", count);
  ata.show("现在是 #${count}。");
} else {
  ata.print("好的，本次结束。");
}
''';
}

class GuessExample extends ExampleApp {
  GuessExample()
      : super(
          id: 'com.atakonitena.guess',
          name: '猜数字',
          description: '一个使用循环与输入框实现的猜数字小游戏。',
          permissions: ['atak:display', 'atak:input'],
        );
  @override
  String get source => r'''
// 猜数字 —— 循环、条件、输入
func play() {
  let target = ata.math.floor(ata.math.random() * 100) + 1;
  let tries = 0;
  let done = false;
  while (!done) {
    tries = tries + 1;
    let guess = ata.input("猜一个 1~100 的数字（第 ${tries} 次）");
    if (guess == null) {
      ata.show("放弃了？答案其实是 ${target}。");
      return;
    }
    let g = num(guess);
    if (g == target) {
      ata.show("恭喜！你用 ${tries} 次猜中了 ${target}。");
      let again = ata.confirm("再来一局？");
      if (again) play();
      done = true;
    } else if (g < target) {
      ata.show("太小了，再猜大一点。");
    } else {
      ata.show("太大了，再猜小一点。");
    }
  }
}
ata.heading("猜数字游戏");
ata.show("我随机想了一个 1~100 的数字，你来猜。");
play();
''';
}