/// AtaLanguage 交互式控制台（REPL）：实时解析执行，变量跨行保留。
library;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as athttp;

import '../../core/ata_language/host.dart';
import '../../core/ata_language/interpreter.dart';
import '../../core/ata_language/lexer.dart';
import '../../core/ata_language/parser.dart';
import '../../core/ata_language/errors.dart';
import '../../core/ata_language/values.dart';
import '../../core/ata_language/json_util.dart';

class ConsoleState {
  List<ConsoleLine> lines = [];
  void add(ConsoleLine l) => lines.add(l);
  void clear() => lines.clear();
}

class ConsoleLine {
  final String text;
  final bool isError;
  final bool isInput;
  final String? chunkKind;
  ConsoleLine(this.text, {this.isError = false, this.isInput = false, this.chunkKind});
}

mixin ConsoleBridge {
  Future<Object?> input(String prompt, String kind); // kind: input/confirm/alert
}

class ConsoleAtaHost implements AtaHost {
  final ConsoleState state;
  final AtakStorageRef storage;
  ConsoleBridge? bridge;

  ConsoleAtaHost(this.state, this.storage);

  @override
  String get appId => '_repl';
  @override
  Map<String, dynamic> get manifest => {
        'name': '控制台',
        'version': '1.0',
        'id': appId,
      };

  @override
  Future<void> log(String message) async {
    state.add(ConsoleLine(message));
  }

  @override
  Future<void> renderChunk(AtaUiChunk chunk) async {
    state.add(ConsoleLine(chunk.content, chunkKind: chunk.kind));
  }

  @override
  Future<void> clearUi() async => state.clear();

  @override
  Future<String?> input(String prompt) async {
    final b = bridge;
    if (b == null) return null;
    return (await b.input(prompt, 'input')) as String?;
  }

  @override
  Future<bool> confirm(String message) async {
    final b = bridge;
    if (b == null) return false;
    return (await b.input(message, 'confirm')) == true;
  }

  @override
  Future<void> alert(String message) async {
    await bridge?.input(message, 'alert');
  }

  @override
  Future<void> notify(String title, String body) async {
    state.add(ConsoleLine('$title：$body', chunkKind: 'heading'));
  }

  @override
  Future<AtaHttpResult> http(String method, String url,
      {Map<String, String>? headers, Object? body}) async {
    final uri = Uri.parse(url);
    final athttp.Client client = athttp.Client();
    try {
      final resp = method.toUpperCase() == 'POST'
          ? await client.post(uri, headers: headers,
              body: body is String ? body : encodeAny(body))
          : await client.get(uri, headers: headers);
      return AtaHttpResult(resp.statusCode, resp.body, resp.headers);
    } finally {
      client.close();
    }
  }

  @override
  Future<void> openUrl(String url) async {
    state.add(ConsoleLine('[open] $url', chunkKind: 'heading'));
  }

  @override
  Object? storeGet(String key) => storage.get(appId, key);

  @override
  Future<void> storeSet(String key, Object? value) async {
    storage.set(appId, key, value);
  }

  @override
  Future<void> storeRemove(String key) async {
    storage.remove(appId, key);
  }

  @override
  Future<void> exit(Object? value) async {
    state.add(ConsoleLine('[exit] ${AtaType.toDisplay(value)}'));
  }
}

/// 简化存储引用，兼容沙盒键值。
class AtakStorageRef {
  Object? get(String id, String key) => null;
  void set(String id, String key, Object? value) {}
  void remove(String id, String key) {}
}

class ConsoleScreen extends StatefulWidget {
  const ConsoleScreen({super.key});

  @override
  State<ConsoleScreen> createState() => _ConsoleScreenState();
}

class _ConsoleScreenState extends State<ConsoleScreen>
    with ConsoleBridge {
  final ConsoleState _state = ConsoleState();
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  Interpreter? _interp;
  ConsoleAtaHost? _host;

  @override
  void initState() {
    super.initState();
    _state.add(ConsoleLine(
        'AtaLanguage 控制台 —— 输入 Ata 代码，回车执行。输入 "help" 查看提示。',
        chunkKind: 'heading'));
    _host = ConsoleAtaHost(_state, AtakStorageRef())..bridge = this;
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Future<Object?> input(String prompt, String kind) async {
    switch (kind) {
      case 'confirm':
        final r = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Ata 确认'),
            content: Text(prompt),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定')),
            ],
          ),
        );
        return r;
      case 'alert':
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Ata 提示'),
            content: Text(prompt),
            actions: [
              FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('好')),
            ],
          ),
        );
        return null;
      default:
        final c = TextEditingController();
        final r = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Ata 输入'),
            content: TextField(controller: c, autofocus: true, decoration: InputDecoration(hintText: prompt)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
              FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('确定')),
            ],
          ),
        );
        c.dispose();
        return r;
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 80), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 160), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _submit(String raw) async {
    final line = raw.trim();
    if (line.isEmpty) return;
    setState(() {
      _state.add(ConsoleLine('❯ $line', isInput: true));
      _input.clear();
    });
    if (line == 'help' || line == '?') {
      _showHelp();
      _scrollToBottom();
      return;
    }
    if (line == 'clear') {
      setState(() => _state.clear());
      return;
    }
    if (line == 'reset') {
      _interp = null;
      setState(() {
        _state.add(ConsoleLine('(解释器已重置)', chunkKind: 'heading'));
      });
      _scrollToBottom();
      return;
    }
    try {
      final interp = _interp ??= Interpreter(host: _host!, granted: _allCapabilities, stepBudget: 200000);
      final lexer = Lexer(line);
      final parser = Parser(lexer.tokenize());
      final program = parser.parse();
      final result = await interp.runStatements(program.statements);
      if (result != null && _isPrintable(result)) {
        setState(() {
          _state.add(ConsoleLine(AtaType.toDisplay(result)));
        });
      }
    } on AtaError catch (e) {
      setState(() => _state.add(ConsoleLine(e.toString(), isError: true)));
    } catch (e) {
      setState(() => _state.add(ConsoleLine('错误：$e', isError: true)));
    }
    _scrollToBottom();
  }

  bool _isPrintable(Object? v) =>
      v is AtaList && v.items.isNotEmpty;

  static final Set<String> _allCapabilities = {
    'atak:display', 'atak:input', 'atak:http', 'atak:open', 'atak:storage', 'atak:notify',
  };

  void _showHelp() {
    setState(() {
      _state.add(ConsoleLine('基础：let x = 1    func f(a){ return a*2 }    if/while/for'));
      _state.add(ConsoleLine('全局函数：print() len() range() type() str() num()'));
      _state.add(ConsoleLine('命名空间：ata.show() ata.input() ata.http.get() ata.store() ata.json ata.math ata.time'));
      _state.add(ConsoleLine('命令：help   clear   reset   (reset 重置解释器状态)'));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            itemCount: _state.lines.length,
            itemBuilder: (context, i) => _renderLine(_state.lines[i]),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Row(
            children: [
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Text('❯', style: TextStyle(color: Colors.grey)),
              ),
              Expanded(
                child: TextField(
                  controller: _input,
                  autofocus: false,
                  onSubmitted: _submit,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: '输入 AtaLanguage 表达式…',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _renderLine(ConsoleLine l) {
    final scheme = Theme.of(context).colorScheme;
    if (l.chunkKind == 'heading') {
      return Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 4),
        child: Text(l.text,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: SelectableText(
        l.text,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          height: 1.4,
          color: l.isError
              ? scheme.error
              : l.isInput
                  ? scheme.primary
                  : null,
          fontWeight: l.isInput ? FontWeight.w600 : null,
        ),
      ),
    );
  }
}