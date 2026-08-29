/// 内置文档 / AtaLanguage 手册：用轻量 Markdown 渲染展示。
library;

import 'package:flutter/material.dart';
import 'markdown_view.dart';

/// 一份文档。
class AtaDoc {
  final String id;
  final String title;
  final String markdown;
  const AtaDoc(this.id, this.title, this.markdown);
}

const List<AtaDoc> kDocs = [
  AtaDoc('start', '开始使用', _mdStart),
  AtaDoc('lang', '语言参考', _mdLang),
  AtaDoc('api', '宿主 API', _mdApi),
  AtaDoc('globals', '全局函数', _mdGlobals),
  AtaDoc('atak', '.atak 包格式', _mdAtak),
  AtaDoc('permissions', '权限系统', _mdPermissions),
  AtaDoc('examples', '示例代码', _mdExamples),
];

class DocsScreen extends StatefulWidget {
  const DocsScreen({super.key});

  @override
  State<DocsScreen> createState() => _DocsScreenState();
}

class _DocsScreenState extends State<DocsScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final doc = kDocs[_index];
        final body = MarkdownView(text: doc.markdown);
        if (!wide) {
          return Column(
            children: [
              SizedBox(
                height: 48,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  scrollDirection: Axis.horizontal,
                  itemCount: kDocs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, i) {
                    final selected = i == _index;
                    return ChoiceChip(
                      label: Text(kDocs[i].title),
                      selected: selected,
                      onSelected: (_) => setState(() => _index = i),
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              Expanded(child: body),
            ],
          );
        }
        return Row(
          children: [
            SizedBox(
              width: 220,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (var i = 0; i < kDocs.length; i++)
                    ListTile(
                      dense: true,
                      selected: i == _index,
                      leading: Icon(
                        i == 0
                            ? Icons.rocket_launch_outlined
                            : i == _index
                                ? Icons.article_outlined
                                : Icons.menu_book_outlined,
                        size: 18,
                      ),
                      title: Text(kDocs[i].title),
                      onTap: () => setState(() => _index = i),
                    ),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        );
      },
    );
  }
}

const String _mdStart = r'''
# AtaKonitena 开始使用

**AtaKonitena**（塔希提语，意为“容器”）是一个跨平台、轻量级的应用沙盒容器。它内置独立编程语言 **AtaLanguage**，并以 `.atak` 为应用安装包格式。

## 一句话理解

```
AtaKonitena = 沙盒容器 + AtaLanguage 语言 + .atak 安装体系
```

正如 LiveContainer 用容器化的方式运行第三方应用，AtaKonitena 在「应用的同时，把数据与权限隔离在各自的沙盒里」——每个应用只能访问自己的存储，只能使用清单声明的能力。

## 快速上手

1. 打开 AtaKonitena，进入「应用市场」页。
2. 安装任意内置示例（它们用 AtaLanguage 编写而成）。
3. 回到「应用」页，点击「启动」运行。
4. 也可以在「控制台」页直接输入 AtaLanguage 代码实时求值。

## 你能做什么

- 在市场安装 / 重新安装应用，或导入外部 `.atak` 文件。
- 用 **AtaLanguage** 编写自己的应用（见「语言参考」）。
- 在容器内使用 `ata.store` 持久化数据、`ata.http` 联网、`ata.open` 打开外部链接。
- 查看本手册，学习完整语法、API 与权限模型。
''';

const String _mdLang = r'''
# AtaLanguage 语言参考

AtaLanguage 是容器内置的轻量脚本语言：结构化、无类型标注、JavaScript 风格。**所有数值统一为 Number（双精度）**，支持字符串、布尔、Null、数组与对象。

## 注释

```
// 单行注释
/* 多行
   注释 */
```

## 变量

```
let x = 1;          // 可变变量
const pi = 3.14;    // 常量，不可再次赋值
x = x + 1;          // 重新赋值
let s = "你好";      // 字符串
let ok = true;      // 布尔：true / false
let n = null;       // 空
let arr = [1, 2, 3];
let obj = { name: "Ata", age: 1 };
```

字符串支持反引号/双引号/单引号及 **插值** `${expr}`：

```
let name = "世界";
ata.show("你好，${name}！");   // 你好，世界！
```

## 运算符

- 算术：`+ - * / %`
- 比较：`== != < <= > >=`，以及 `===`/`!==`
- 逻辑：`&&`/`and`，`||`/`or`，`!`/`not`
- 三目：`cond ? a : b`
- 空合并：`a ?? b`（a 为 null 时取 b）

## 条件

```
if (score >= 60 && score < 90) {
  ata.show("良好");
} else if (score >= 90) {
  ata.show("优秀");
} else {
  ata.show("继续加油");
}
```

## 循环

```
let i = 0;
while (i < 5) { i = i + 1; }

for (let j = 0; j < 3; j = j + 1) { ata.print(j); }
for (let v of [10, 20, 30]) { ata.print(v); }     // 迭代数组
for (let k of obj) { ata.print(k); }              // 迭代对象键

break;    // 跳出循环
continue; // 进入下一次
```

## 函数

```
func add(a, b) { return a + b; }
let c = add(2, 3);          // 5

func greet(name = "朋友") {  // 默认参数
  ata.show("你好，${name}");
}
greet();
```

## 数组与对象

```
let arr = [1, 2, 3];
arr.push(4);
len(arr);           // 4
arr[0];             // 1
arr.reverse;        // 翻转

let o = {};
o.hello = "world";  // 或 o["hello"]="world"
o.hello;            // "world"
```

## 模块导入

```
import "mylib"       // 导入随包 vendor/ 或解释器内置模块
import "ata"         // 内置宿主模块（ata 命名空间为主，可省略）
```

内置值 `ata` 已自动可用，无需导入。
''';

const String _mdApi = r'''
# 宿主 API（ata 命名空间）

AtaLanguage 通过全局 **`ata`** 对象调用宿主能力。凡标注「需权限」的接口，应用清单必须声明对应能力，否则运行期报错。

## 界面渲染

```
ata.show("你好");         // 显示文本块
ata.text("...")          // show 的别名
ata.heading("标题");       // 大号标题块
ata.clear();             // 清空该应用界画布
ata.print("到日志");       // 打印到日志流（不产生界面块）
ata.log("...")           // print 的别名
```

## 交互对话框

```
let name = ata.input("你的名字？");   // 文本输入，取消返回 null（需 atak:input）
let ok = ata.confirm("继续吗？");    // 确认框，返回布尔（需 atak:input）
ata.alert("提示内容");              // 信息提示，带确定按钮
ata.notify("标题", "正文");          // 系统通知（需 atak:notify）
```

## 外部与系统

```
ata.open("https://example.com");   // 用系统浏览器打开（需 atak:open）
ata.exit(0);                       // 退出该应用
ata.sleep(100);                    // 暂停 100 毫秒
```

## 网络（需 atak:http）

```
let r = ata.http.get("https://api.example.com/ping");
ata.show(r.status);       // HTTP 状态码
ata.show(r.body);         // 响应体（字符串）
ata.http.post(url, data)  // POST，data 可为对象或字符串
```

## 沙盒存储（需 atak:storage）

```
ata.store.set("count", 1);       // 写入（自动序列化）
let c = ata.store.get("count");  // 读取
ata.store.remove("count");       // 删除
```
存储按应用 ID 隔离在各自沙盒目录，互不可见。

## JSON

```
let o = ata.json.parse("{"a":1}");   // 字符串 -> 对象
let s = ata.json.stringify(o);         // 对象 -> 字符串
```

## 数学

```
ata.math.pi;  ata.math.e;             // 常量
ata.math.sqrt(9);     // 3
ata.math.pow(2, 10);  // 1024
ata.math.floor(1.7);  // 1
ata.math.ceil(1.2);   // 2
ata.math.round(1.5);  // 2
ata.math.abs(-3);     // 3
ata.math.random();    // 0~1 随机数
ata.math.min(1,5,2);  // 1
ata.math.max(1,5,2);  // 5
```

## 字符串工具

```
ata.string.upper("abc");  // "ABC"
ata.string.lower("ABC");  // "abc"
ata.string.trim("  x ");  // "x"
ata.string.format("{} + {} = {}", 1, 2);  // "1 + 2 = 2"
ata.string.split("a,b,c", ",");           // ["a","b","c"]
```

## 时间

```
ata.time.now();   // 毫秒时间戳
ata.time.unix();  // 秒时间戳
ata.time.iso();   // ISO8601 字符串
```

## 应用元信息

```
ata.app.id;       // 应用 ID
ata.app.name;     // 应用名
ata.app.version;  // 版本
ata.version;      // AtaLanguage 版本
```
''';

const String _mdGlobals = r'''
# 全局函数

以下函数可在任何地方直接调用（无需 `ata.` 前缀）。

## print / 输出

```
print("hello");     // 打印到日志流
```

## len

```
len("abc");       // 3（字符串长度）
len([1,2,3]);     // 3（数组长度）
len(obj);         // 对象键数量
```

## range

```
range(5);         // [0,1,2,3,4]
range(2, 5);      // [2,3,4]
range(0, 10, 2);  // [0,2,4,6,8]
```

## type / str / num

```
type(1);         // "number"
type("x");       // "string"
type(true);      // "boolean"
type(null);      // "null"
type([1]);       // "array"
type({});        // "object"
type(print);     // "function"

str(12.5);       // "12.5"
num("42");       // 42         （转换失败返回 null）
num("3.14");     // 3.14
```
''';

const String _mdAtak = r'''
# .atak 应用包格式

**.atak** 本质是一个 **Zip 归档**，内部包含应用清单、入口脚本与资源。

## 目录结构

```
app.atak
├── manifest.json     # 应用清单（必填）
├── app.ata           # 入口脚本（由 manifest 的 entry 指定）
├── resources/        # 图标、图片等资源（可选）
└── vendor/           # 随包内置的 AtaLanguage 模块（可选）
```

## manifest.json

```json
{
  "format": "atak",
  "formatVersion": 1,
  "id": "com.example.hello",
  "name": "你好世界",
  "version": "1.0.0",
  "author": "AtaKonitena",
  "description": "示例应用",
  "entry": "app.ata",
  "icon": "resources/icon.png",
  "permissions": ["atak:display", "atak:input", "atak:open"]
}
```

字段说明：

- `format`、`formatVersion`：格式标识（固定 `atak` / `1`）。
- `id`：唯一标识（建议反向域名），用于沙盒数据隔离。
- `name`、`version`、`author`、`description`：展示信息。
- `entry`：入口脚本路径（默认 `app.ata`）。
- `icon`：可选图标路径。
- `permissions`：声明所需能力，见「权限系统」。

## 安装 / 卸载

- 安装：市场安装或导入文件，AtaKonitena 校验收录、解压并登记。
- 升级：同样 ID 且版本更高时执行升级（保留沙盒数据）。
- 卸载：移除安装目录与对应沙盒数据。
''';

const String _mdPermissions = r'''
# 权限系统

每个应用在 **manifest.json** 中通过 `permissions` 声明自己需要的能力。沙盒只放行已声明能力对应的 API，未声明即调用会运行期报错。

## 能力位一览

| 能力 | 声明串 | 对应 API |
| --- | --- | --- |
| 界面显示 | `atak:display` | `ata.show` / `ata.heading` |
| 交互输入 | `atak:input` | `ata.input` / `ata.confirm` |
| 网络请求 | `atak:http` | `ata.http.*` |
| 打开外部链接 | `atak:open` | `ata.open` |
| 系统通知 | `atak:notify` | `ata.notify` |
| 沙盒存储 | `atak:storage` | `ata.store.*` |

## 最小授权原则

建议只声明应用真正用到的能力：

```json
"permissions": ["atak:display", "atak:storage"]
```

- 只展示内容的应用：`["atak:display"]`
- 需要用户输入的应用：加 `"atak:input"`
- 需要联网的应用：加 `"atak:http"`

## 沙盒隔离

- 数据隔离：每个应用的 `ata.store` 数据存于其专属目录，互相不可见。
- 能力隔离：即便脚本出现恶意调用，只要清单未声明对应能力就会被沙盒拒绝。
''';

const String _mdExamples = r'''
# 示例代码

以下代码可直接粘贴到「控制台」运行。

## 你好世界

```
ata.heading("你好，AtaKonitena！");
let name = ata.input("你的名字？");
if (name != null && name != "") {
  ata.show("欢迎你，${name}！");
} else {
  ata.show("好吧，匿名者。");
}
```

## 计数器（沙盒存储）

```
let count = ata.store.get("count");
count = (count == null) ? 0 : num(count);
count = count + 1;
ata.store.set("count", count);
ata.heading("计数器 #${count}");
ata.show("这是你第 ${count} 次运行本应用。");
```

## 猜数字（循环 + 输入）

```
func play() {
  let target = ata.math.floor(ata.math.random() * 100) + 1;
  let tries = 0;
  let done = false;
  while (!done) {
    tries = tries + 1;
    let guess = ata.input("猜一个 1~100 的数字（第 ${tries} 次）");
    if (guess == null) { ata.show("放弃啦，答案是 ${target}。"); return; }
    let g = num(guess);
    if (g == target) {
      ata.show("恭喜！用了 ${tries} 次猜中 ${target}。");
      done = true;
    } else if (g < target) {
      ata.show("太小了，再大一点。");
    } else {
      ata.show("太大了，再小一点。");
    }
  }
}
play();
```

## 拉取数据 + 打开链接

```
let r = ata.http.get("https://api.github.com/repos/Tommyaaaa/AtaKonitena");
ata.show("HTTP ${r.status}");
if (ata.confirm("打开项目主页？")) {
  ata.open("https://github.com/Tommyaaaa/AtaKonitena");
}
```
''';