/// AtaLanguage 树遍历解释器（异步，兼容宿主 UI/网络交互）。
library;

import 'dart:async';
import 'dart:math' as math;
import 'token.dart';
import 'ast.dart';
import 'values.dart';
import 'environment.dart';
import 'errors.dart';
import 'host.dart';
import 'json_util.dart';
import 'lexer.dart';
import 'parser.dart';

/// 控制流信号。
class _ReturnSignal {
  final Object? value;
  _ReturnSignal(this.value);
}

class _BreakSignal {
  const _BreakSignal();
}

class _ContinueSignal {
  const _ContinueSignal();
}

/// 宿主原生函数调用上下文。
class NativeCallContext {
  final Interpreter interpreter;
  NativeCallContext(this.interpreter);
}

class Interpreter {
  final AtaHost host;
  final Environment globals;
  final Set<String> granted;

  /// 当前有效作用域（顶层为 globals，进入块/函数/循环后切换）。
  Environment _activeScope;

  /// 宿主额外注入的全局原生函数。
  final Map<String, Future<Object?> Function(List<Object?> args,
          NativeCallContext ctx)>
      extraGlobals;

  int _stepBudget = 0;
  int get remainingSteps => _stepBudget;

  Interpreter({
    required this.host,
    Set<String>? granted,
    this.extraGlobals = const {},
    int stepBudget = 1000000,
  }) : globals = Environment(null),
       granted = granted ?? const {},
       _activeScope = Environment(null) {
    _activeScope = globals;
    _stepBudget = stepBudget;
    _installBase();
    _installGlobals();
  }

  Environment get _current => _activeScope;

  // ---------------------------- 安装环境 ----------------------------

  void _installBase() {
    globals.define('print', AtaNativeFunction('print', (a, c) async {
      await host.log(AtaType.toDisplay(arg(a, 0)));
      return null;
    }));
    globals.define('len', AtaNativeFunction('len', (a, c) async {
      final v = arg(a, 0);
      if (v is AtaList) return v.items.length;
      if (v is AtaMapVal) return v.entries.length;
      if (v is String) return v.length;
      throw AtaRuntimeError('len() 需要数组 / map / 字符串');
    }));
    globals.define(
        'type', AtaNativeFunction('type', (a, c) async => AtaType.typeName(arg(a, 0))));
    globals.define(
        'str', AtaNativeFunction('str', (a, c) async => AtaType.toDisplay(arg(a, 0))));
    globals.define('num', AtaNativeFunction('num', (a, c) async {
      final v = arg(a, 0);
      if (v is num) return v;
      return double.tryParse('$v') ?? 0.0;
    }));
    globals.define('isNull', AtaNativeFunction('isNull', (a, c) async {
      return arg(a, 0) == null;
    }));
    globals.define('range', AtaNativeFunction('range', (a, c) async {
      final n = (arg(a, 0) as num).toInt();
      return AtaList(List<int>.generate(n < 0 ? 0 : n, (i) => i));
    }));
    // 宿主主命名空间 `ata`：默认可用（无需 import）。
    globals.define('ata', _ataModule);
  }

  void _installGlobals() {
    for (final e in extraGlobals.entries) {
      globals.define(
          e.key,
          AtaNativeFunction(e.key, (a, c) async => e.value(a, c)));
    }
  }

  static Object? arg(List<Object?> a, int i) => i < a.length ? a[i] : null;

  // ---------------------------- 权限 ----------------------------

  void _require(String capability, [Token? t]) {
    if (!granted.contains(capability)) {
      throw AtaPermissionError(
          '未被授权的能力：$capability（请在应用的 manifest.json 中声明）',
          line: t?.line,
          column: t?.column);
    }
  }

  // ---------------------------- 运行入口 ----------------------------

  Future<Object?> interpret(Program program) async {
    try {
      for (final stmt in program.statements) {
        await _execute(stmt);
      }
    } on AtaExitSignal catch (e) {
      return e.value;
    }
    return null;
  }

  /// 逐条执行多条语句（供 REPL），返回最后一条表达式的值。
  Future<Object?> runStatements(List<Stmt> statements) async {
    Object? last;
    for (final s in statements) {
      last = await _execute(s);
    }
    return last;
  }

  // ---------------------------- 语句执行 ----------------------------

  Future<Object?> _execute(Stmt stmt) async {
    _spend();
    switch (stmt) {
      case ExprStmt(:final expr):
        return await evaluate(expr);
      case BlockStmt(:final statements):
        final env = _current.child();
        final saved = _activeScope;
        _activeScope = env;
        Object? last;
        try {
          for (final s in statements) {
            last = await _execute(s);
          }
        } finally {
          _activeScope = saved;
        }
        return last;
      case LetStmt(:final name, :final isConst, :final initializer):
        final value = initializer == null ? null : await evaluate(initializer);
        _current.define(name, value, isConst: isConst);
        return value;
      case IfStmt(): {
          if (AtaType.isTruthy(await evaluate(stmt.condition))) {
            return await _execute(stmt.thenBranch);
          }
          final elseB = stmt.elseBranch;
          if (elseB != null) {
            return await _execute(elseB);
          }
          return null;
        }
      case WhileStmt():
        await _whileLoop(stmt);
        return null;
      case ForStmt():
        await _forLoop(stmt);
        return null;
      case ReturnStmt(:final value):
        final v = value == null ? null : await evaluate(value);
        throw _ReturnSignal(v);
      case BreakStmt():
        throw const _BreakSignal();
      case ContinueStmt():
        throw const _ContinueSignal();
      case ImportStmt():
        _applyImport(stmt);
        return null;
      case FunctionStmt(:final name, :final params, :final body):
        _current.define(name, AtaFunction(params, body, _current, name: name));
        return null;
    }
  }

  void _spend() {
    if (_stepBudget-- <= 0) {
      throw AtaTimeoutError('脚本运行步骤超出预算，已中止（可能存在死循环）');
    }
  }

  /// 字符串插值：支持 `${expr}` 求值拼接，`\$` 输出字面 `$`。
  Future<Object?> _interpolate(String s) async {
    if (!s.contains(r'${')) return s;
    final buf = StringBuffer();
    var i = 0;
    while (i < s.length) {
      final c = s[i];
      if (c == r'$' && i + 1 < s.length && s[i + 1] == '{') {
        final close = s.indexOf('}', i + 2);
        if (close == -1) {
          buf.write(s.substring(i));
          break;
        }
        final exprStr = s.substring(i + 2, close);
        final v = await _evalInterp(exprStr);
        buf.write(AtaType.toDisplay(v));
        i = close + 1;
      } else {
        buf.write(c);
        i++;
      }
    }
    return buf.toString();
  }

  Future<Object?> _evalInterp(String exprStr) async {
    try {
      final lexer = Lexer(exprStr);
      final parser = Parser(lexer.tokenize());
      return await evaluate(parser.parseExpression());
    } catch (e) {
      return '<err: $e>';
    }
  }

  Future<void> _whileLoop(WhileStmt stmt) async {
    while (AtaType.isTruthy(await evaluate(stmt.condition))) {
      try {
        await _execute(stmt.body);
      } on _BreakSignal {
        break;
      } on _ContinueSignal {
        continue;
      }
    }
  }

  Future<void> _forLoop(ForStmt stmt) async {
    final saved = _activeScope;
    _activeScope = _current.child();
    try {
      if (stmt.initializer != null) await _execute(stmt.initializer!);
      while (stmt.condition == null ||
          AtaType.isTruthy(await evaluate(stmt.condition!))) {
        try {
          await _execute(stmt.body);
        } on _BreakSignal {
          break;
        } on _ContinueSignal {
          if (stmt.increment != null) await evaluate(stmt.increment!);
          continue;
        }
        if (stmt.increment != null) await evaluate(stmt.increment!);
      }
    } finally {
      _activeScope = saved;
    }
  }

  void _applyImport(ImportStmt stmt) {
    final path = stmt.module.split('.');
    Object? mod = (path.first == 'ata') ? _ataModule : globals.get(path.first);
    for (var i = path.first == 'ata' ? 1 : 0; i < path.length; i++) {
      mod = _getMember(mod, path[i], null, guard: false);
    }
    final name = stmt.alias ?? path.last;
    if (mod == null) mod = AtaHostObject(name, {});
    _current.define(name, mod);
  }

  // ---------------------------- 表达式求值 ----------------------------

  Future<Object?> evaluate(Expr expr) async {
    _spend();
    switch (expr) {
      case LiteralExpr(:final value):
        if (value is String) return _interpolate(value);
        return value;
      case VarExpr(:final name):
        return _current.get(name);
      case ArrayExpr(:final elements):
        return AtaList(await Future.wait(elements.map(evaluate)));
      case MapExpr(:final keys, :final values):
        final vals = await Future.wait(values.map(evaluate));
        final map = AtaMapVal();
        for (var i = 0; i < keys.length; i++) {
          map.entries[keys[i]] = vals[i];
        }
        return map;
      case UnaryExpr(:final op, :final right):
        final v = await evaluate(right);
        return switch (op) {
          TokenType.bang => !AtaType.isTruthy(v),
          TokenType.minus => -(v as num),
          TokenType.plus => (v as num),
          _ => null,
        };
      case BinaryExpr():
        return await _binary(expr);
      case LogicalExpr(:final left, :final right, :final op):
        final l = await evaluate(left);
        if ((op == TokenType.andAnd && !AtaType.isTruthy(l)) ||
            (op == TokenType.orOr && AtaType.isTruthy(l))) {
          return l;
        }
        return await evaluate(right);
      case TernaryExpr(:final condition, :final thenBranch, :final elseBranch):
        return AtaType.isTruthy(await evaluate(condition))
            ? await evaluate(thenBranch)
            : await evaluate(elseBranch);
      case AssignExpr():
        return await _assign(expr);
      case PostfixExpr():
        return await _postfix(expr);
      case CallExpr(:final callee, :final args):
        final fn = await evaluate(callee);
        final argv = await Future.wait(args.map(evaluate));
        return await _call(fn, argv, expr.token?.line);
      case IndexExpr(:final object, :final index):
        final o = await evaluate(object);
        final i = await evaluate(index);
        return _indexRead(o, i);
      case MemberExpr(:final object, :final name):
        final o = await evaluate(object);
        return _getMember(o, name, expr.token);
      case FunctionExpr(:final params, :final body):
        return AtaFunction(params, body, _current);
    }
  }

  Future<Object?> _binary(BinaryExpr expr) async {
    final op = expr.op;
    final l = await evaluate(expr.left);
    final r = await evaluate(expr.right);
    switch (op) {
      case TokenType.plus:
        if (l is String || r is String) {
          return AtaType.toDisplay(l) + AtaType.toDisplay(r);
        }
        if (l is num && r is num) return l + r;
        throw AtaRuntimeError('运算符 + 操作数不兼容',
            line: expr.token?.line);
      case TokenType.minus:
        _needNum(l, r, expr);
        return (l as num) - (r as num);
      case TokenType.star:
        _needNum(l, r, expr);
        return (l as num) * (r as num);
      case TokenType.slash:
        _needNum(l, r, expr);
        if ((r as num) == 0) throw AtaRuntimeError('除数为 0', line: expr.token?.line);
        return (l as num) / r;
      case TokenType.percent:
        _needNum(l, r, expr);
        final rr = r as num;
        if (rr == 0) throw AtaRuntimeError('取模除数为 0', line: expr.token?.line);
        return (l as num) % rr;
      case TokenType.less:
        _needNum(l, r, expr);
        return (l as num) < (r as num);
      case TokenType.lessEqual:
        _needNum(l, r, expr);
        return (l as num) <= (r as num);
      case TokenType.greater:
        _needNum(l, r, expr);
        return (l as num) > (r as num);
      case TokenType.greaterEqual:
        _needNum(l, r, expr);
        return (l as num) >= (r as num);
      case TokenType.equalEqual:
        return _equals(l, r);
      case TokenType.bangEqual:
        return !_equals(l, r);
      case TokenType.questionQuestion:
        return l ?? r;
      default:
        throw AtaRuntimeError('未知二元运算符', line: expr.token?.line);
    }
  }

  void _needNum(Object? l, Object? r, BinaryExpr e) {
    if (l is! num || r is! num) {
      throw AtaRuntimeError(
          '运算符需要数字操作数，得到 ${AtaType.typeName(l)} 与 ${AtaType.typeName(r)}',
          line: e.token?.line);
    }
  }

  bool _equals(Object? a, Object? b) {
    if (a is AtaList && b is AtaList) {
      if (a.items.length != b.items.length) return false;
      for (var i = 0; i < a.items.length; i++) {
        if (!_equals(a.items[i], b.items[i])) return false;
      }
      return true;
    }
    if (a is AtaMapVal && b is AtaMapVal) {
      if (a.entries.length != b.entries.length) return false;
      for (final k in a.entries.keys) {
        if (!b.entries.containsKey(k)) return false;
        if (!_equals(a.entries[k], b.entries[k])) return false;
      }
      return true;
    }
    if (a == null || b == null) return a == b;
    if (a is num && b is num) return a == b;
    if (a is! AtaValue && b is! AtaValue) return a == b;
    return false;
  }

  Future<Object?> _assign(AssignExpr expr) async {
    final newVal = await evaluate(expr.value);
    final base = expr.op == TokenType.equal ? null : await evaluate(expr.target);
    final value = expr.op == TokenType.equal
        ? newVal
        : _compound(expr.op, base, newVal, expr);
    return _writeTarget(expr.target, value);
  }

  Object? _compound(TokenType op, Object? base, Object? nv, AssignExpr e) {
    if (base is! num || nv is! num) {
      throw AtaRuntimeError('复合赋值需要数字操作数', line: e.token?.line);
    }
    switch (op) {
      case TokenType.plusEqual:
        return base + nv;
      case TokenType.minusEqual:
        return base - nv;
      case TokenType.starEqual:
        return base * nv;
      case TokenType.slashEqual:
        return (nv == 0) ? double.nan : base / nv;
      case TokenType.percentEqual:
        return (nv == 0) ? double.nan : base % nv;
      default:
        return nv;
    }
  }

  Future<Object?> _writeTarget(Expr target, Object? value) async {
    switch (target) {
      case VarExpr(:final name):
        if (!_current.existsLocally(name) &&
            _current.parent?.enclosing(name) == null) {
          _current.define(name, value);
        } else {
          _current.assign(name, value);
        }
        return value;
      case MemberExpr(:final object, :final name):
        final o = await evaluate(object);
        _setMember(o, name, value);
        return value;
      case IndexExpr(:final object, :final index):
        final o = await evaluate(object);
        final i = await evaluate(index);
        _setIndex(o, i, value);
        return value;
      default:
        throw AtaRuntimeError('不能给该目标赋值');
    }
  }

  Future<Object?> _postfix(PostfixExpr expr) async {
    final base = await evaluate(expr.target);
    if (base is! num) {
      throw AtaRuntimeError('++/-- 需要数字', line: expr.token?.line);
    }
    final nv = expr.op == TokenType.plusPlus ? base + 1 : base - 1;
    await _writeTarget(expr.target, nv);
    return base;
  }

  Future<Object?> _call(Object? fn, List<Object?> args, int? line) async {
    if (fn is AtaFunction) {
      final env = fn.closure.child();
      for (var i = 0; i < fn.params.length; i++) {
        env.define(fn.params[i], i < args.length ? args[i] : null);
      }
      final saved = _activeScope;
      _activeScope = env;
      try {
        for (final s in fn.body.statements) {
          await _execute(s);
        }
      } on _ReturnSignal catch (r) {
        return r.value;
      } finally {
        _activeScope = saved;
      }
      return null;
    }
    if (fn is AtaNativeFunction) return fn.call(args, NativeCallContext(this));
    throw AtaRuntimeError(
        '${AtaType.typeName(fn)} 不是可调用函数', line: line);
  }

  // ---------------------------- 成员 / 下标 ----------------------------

  Object? _getMember(Object? o, String name, Token? t, {bool guard = true}) {
    if (o is AtaHostObject) {
      if (!o.members.containsKey(name)) {
        if (guard) throw AtaRuntimeError('${o.name} 没有成员 $name', line: t?.line);
        return null;
      }
      return o.members[name];
    }
    if (o is AtaList) return _listMember(o, name, t, guard);
    if (o is AtaMapVal) return o.entries[name];
    if (o is String) return _stringMember(o, name, t, guard);
    if (guard) {
      throw AtaRuntimeError('类型 ${AtaType.typeName(o)} 没有成员 $name', line: t?.line);
    }
    return null;
  }

  Object? _stringMember(String o, String name, Token? t, bool guard) {
    switch (name) {
      case 'length':
        return o.length;
      case 'toUpper':
        return AtaNativeFunction('toUpper', (a, c) async => o.toUpperCase());
      case 'toLower':
        return AtaNativeFunction('toLower', (a, c) async => o.toLowerCase());
      case 'trim':
        return AtaNativeFunction('trim', (a, c) async => o.trim());
      case 'contains':
        return AtaNativeFunction('contains',
            (a, c) async => o.contains(AtaType.toDisplay(arg(a, 0))));
      case 'split':
        return AtaNativeFunction('split', (a, c) async =>
            AtaList(o.split(AtaType.toDisplay(arg(a, 0))).toList()));
      case 'replace':
        return AtaNativeFunction('replace', (a, c) async => o.replaceAll(
            AtaType.toDisplay(arg(a, 0)), AtaType.toDisplay(arg(a, 1))));
      case 'startsWith':
        return AtaNativeFunction(
            'startsWith', (a, c) async => o.startsWith(AtaType.toDisplay(arg(a, 0))));
      case 'endsWith':
        return AtaNativeFunction(
            'endsWith', (a, c) async => o.endsWith(AtaType.toDisplay(arg(a, 0))));
      case 'indexOf':
        return AtaNativeFunction('indexOf', (a, c) async {
          final start = arg(a, 1) is num ? (arg(a, 1) as num).toInt() : 0;
          return o.indexOf(AtaType.toDisplay(arg(a, 0)), start);
        });
      case 'charAt':
        return AtaNativeFunction('charAt', (a, c) async {
          final i = arg(a, 0) is num ? (arg(a, 0) as num).toInt() : 0;
          return i >= 0 && i < o.length ? o[i] : '';
        });
      default:
        if (guard) throw AtaRuntimeError('字符串没有成员 $name', line: t?.line);
        return null;
    }
  }

  Object? _listMember(AtaList o, String name, Token? t, bool guard) {
    switch (name) {
      case 'length':
        return o.items.length;
      case 'push':
        return AtaNativeFunction('push', (a, c) async {
          o.items.add(arg(a, 0));
          return o;
        });
      case 'pop':
        return AtaNativeFunction('pop', (a, c) async =>
            o.items.isEmpty ? null : o.items.removeLast());
      case 'shift':
        return AtaNativeFunction('shift', (a, c) async =>
            o.items.isEmpty ? null : o.items.removeAt(0));
      case 'unshift':
        return AtaNativeFunction('unshift', (a, c) async {
          o.items.insert(0, arg(a, 0));
          return o;
        });
      case 'join':
        return AtaNativeFunction('join', (a, c) async =>
            o.items.map(AtaType.toDisplay).join(AtaType.toDisplay(arg(a, 0))));
      case 'contains':
        return AtaNativeFunction('contains', (a, c) async =>
            o.items.any((e) => _equals(e, arg(a, 0))));
      case 'indexOf':
        return AtaNativeFunction('indexOf', (a, c) async {
          for (var i = 0; i < o.items.length; i++) {
            if (_equals(o.items[i], arg(a, 0))) return i;
          }
          return -1;
        });
      case 'reverse':
        return AtaNativeFunction('reverse', (a, c) async {
          final rev = o.items.reversed.toList();
          o.items.clear();
          o.items.addAll(rev);
          return o;
        });
      case 'sort':
        return AtaNativeFunction('sort', (a, c) async {
          o.items.sort((x, y) {
            if (x is num && y is num) return x.compareTo(y);
            return AtaType.toDisplay(x).compareTo(AtaType.toDisplay(y));
          });
          return o;
        });
      case 'slice':
        return AtaNativeFunction('slice', (a, c) async {
          final len = o.items.length;
          final start = arg(a, 0) is num ? (arg(a, 0) as num).toInt() : 0;
          final end = arg(a, 1) is num ? (arg(a, 1) as num).toInt() : len;
          final from = (start < 0 ? len + start : start).clamp(0, len);
          final to = (end < 0 ? len + end : end).clamp(0, len);
          return AtaList(
              o.items.sublist(from < to ? from : to, to < from ? from : to));
        });
      case 'map':
      case 'filter':
      case 'forEach':
        return AtaNativeFunction(name, (a, c) async {
          final fn = arg(a, 0);
          final interp = c.interpreter;
          if (name == 'map') {
            final out = <Object?>[];
            for (var i = 0; i < o.items.length; i++) {
              out.add(
                  await interp._call(fn, [o.items[i], i], null));
            }
            return AtaList(out);
          } else if (name == 'filter') {
            final out = <Object?>[];
            for (var i = 0; i < o.items.length; i++) {
              final keep = await interp._call(fn, [o.items[i], i], null);
              if (AtaType.isTruthy(keep)) out.add(o.items[i]);
            }
            return AtaList(out);
          } else {
            for (var i = 0; i < o.items.length; i++) {
              await interp._call(fn, [o.items[i], i], null);
            }
            return null;
          }
        });
      default:
        if (guard) throw AtaRuntimeError('数组没有成员 $name', line: t?.line);
        return null;
    }
  }

  void _setMember(Object? o, String name, Object? value) {
    if (o is AtaMapVal) {
      o.entries[name] = value;
      return;
    }
    if (o is AtaList) {
      throw AtaRuntimeError('数组不支持命名成员赋值');
    }
    throw AtaRuntimeError('不能给 ${AtaType.typeName(o)} 设置成员 $name');
  }

  Object? _indexRead(Object? o, Object? idx) {
    if (o is AtaList) {
      if (idx is! num) throw AtaRuntimeError('数组下标需为数字');
      final i = idx.toInt();
      if (i < 0) return o.items[o.items.length + i];
      return i < o.items.length ? o.items[i] : null;
    }
    if (o is AtaMapVal) return o.entries[AtaType.toDisplay(idx)];
    if (o is String) {
      final i = (idx as num).toInt();
      return i >= 0 && i < o.length ? o[i] : '';
    }
    throw AtaRuntimeError('不能对 ${AtaType.typeName(o)} 做下标访问');
  }

  void _setIndex(Object? o, Object? idx, Object? value) {
    if (o is AtaList) {
      final i = (idx as num).toInt();
      if (i < 0) {
        o.items[o.items.length + i] = value;
      } else if (i < o.items.length) {
        o.items[i] = value;
      } else {
        while (o.items.length < i) {
          o.items.add(null);
        }
        o.items.add(value);
      }
      return;
    }
    if (o is AtaMapVal) {
      o.entries[AtaType.toDisplay(idx)] = value;
      return;
    }
    throw AtaRuntimeError('不能对 ${AtaType.typeName(o)} 设置下标');
  }

  // ---------------------------- ata 模块 ----------------------------

  late final AtaHostObject _ataModule = _buildAtaModule();

  AtaHostObject _buildAtaModule() {
    final m = <String, Object?>{};
    m['version'] = '1.0';
    m['appId'] = host.appId;
    m['app'] = AtaHostObject('app', {
      'id': host.appId,
      'name': (host.manifest['name'] ?? '') as Object?,
      'version': (host.manifest['version'] ?? '') as Object?,
      'author': (host.manifest['author'] ?? '') as Object?,
    });
    m['print'] = AtaNativeFunction('ata.print', (a, c) async {
      await host.log(AtaType.toDisplay(arg(a, 0)));
      return null;
    });
    m['log'] = m['print'];
    m['show'] = AtaNativeFunction('ata.show', (a, c) async {
      _require(AtaCapability.display);
      await host.renderChunk(AtaUiChunk('text', AtaType.toDisplay(arg(a, 0))));
      return null;
    });
    m['text'] = m['show'];
    m['heading'] = AtaNativeFunction('ata.heading', (a, c) async {
      _require(AtaCapability.display);
      await host
          .renderChunk(AtaUiChunk('heading', AtaType.toDisplay(arg(a, 0))));
      return null;
    });
    m['clear'] = AtaNativeFunction('ata.clear', (a, c) async {
      await host.clearUi();
      return null;
    });
    m['input'] = AtaNativeFunction('ata.input', (a, c) async {
      _require(AtaCapability.input);
      return await host.input(AtaType.toDisplay(arg(a, 0)));
    });
    m['confirm'] = AtaNativeFunction('ata.confirm', (a, c) async {
      _require(AtaCapability.input);
      return await host.confirm(AtaType.toDisplay(arg(a, 0)));
    });
    m['alert'] = AtaNativeFunction('ata.alert', (a, c) async {
      await host.alert(AtaType.toDisplay(arg(a, 0)));
      return null;
    });
    m['notify'] = AtaNativeFunction('ata.notify', (a, c) async {
      _require(AtaCapability.notify);
      await host.notify(
          AtaType.toDisplay(arg(a, 0)), AtaType.toDisplay(arg(a, 1)));
      return null;
    });
    m['open'] = AtaNativeFunction('ata.open', (a, c) async {
      _require(AtaCapability.openUrl);
      await host.openUrl(AtaType.toDisplay(arg(a, 0)));
      return null;
    });
    m['exit'] = AtaNativeFunction('ata.exit', (a, c) async {
      await host.exit(arg(a, 0));
      throw AtaExitSignal(arg(a, 0));
    });
    m['sleep'] = AtaNativeFunction('ata.sleep', (a, c) async {
      final ms = arg(a, 0) is num ? (arg(a, 0) as num).toInt() : 0;
      await osDelay(ms);
      return null;
    });

    m['http'] = AtaHostObject('http', {
      'get': AtaNativeFunction('http.get', (a, c) async {
        _require(AtaCapability.http);
        return _httpToMap(await host.http('GET', AtaType.toDisplay(arg(a, 0))));
      }),
      'post': AtaNativeFunction('http.post', (a, c) async {
        _require(AtaCapability.http);
        return _httpToMap(await host.http('POST', AtaType.toDisplay(arg(a, 0)),
            body: arg(a, 1)));
      }),
    });

    m['json'] = AtaHostObject('json', {
      'parse': AtaNativeFunction(
          'json.parse', (a, c) async => toAtaValue(decodeAny(AtaType.toDisplay(arg(a, 0))))),
      'stringify': AtaNativeFunction(
          'json.stringify', (a, c) async => encodeAny(arg(a, 0))),
    });

    m['store'] = AtaHostObject('store', {
      'get': AtaNativeFunction(
          'store.get', (a, c) async => toAtaValue(host.storeGet(AtaType.toDisplay(arg(a, 0))))),
      'set': AtaNativeFunction('store.set', (a, c) async {
        _require(AtaCapability.storage);
        await host.storeSet(
            AtaType.toDisplay(arg(a, 0)), toPlain(arg(a, 1)));
        return null;
      }),
      'remove': AtaNativeFunction('store.remove', (a, c) async {
        _require(AtaCapability.storage);
        await host.storeRemove(AtaType.toDisplay(arg(a, 0)));
        return null;
      }),
    });

    m['math'] = AtaHostObject('math', {
      'pi': 3.141592653589793,
      'e': 2.718281828459045,
      'sqrt': AtaNativeFunction('sqrt', (a, c) async {
        final v = arg(a, 0);
        return v is num ? math.sqrt(v.toDouble()) : 0.0;
      }),
      'pow': AtaNativeFunction('pow', (a, c) async {
        if (a.length < 2 || a[0] is! num || a[1] is! num) return 0.0;
        return math.pow((a[0] as num).toDouble(), (a[1] as num).toDouble());
      }),
      'floor': AtaNativeFunction('floor', (a, c) async {
        final v = arg(a, 0);
        return v is num ? v.toDouble().floorToDouble() : 0.0;
      }),
      'ceil': AtaNativeFunction('ceil', (a, c) async {
        final v = arg(a, 0);
        return v is num ? v.toDouble().ceilToDouble() : 0.0;
      }),
      'round': AtaNativeFunction('round', (a, c) async {
        final v = arg(a, 0);
        return v is num ? v.toDouble().roundToDouble() : 0.0;
      }),
      'abs': AtaNativeFunction('abs', (a, c) async {
        final v = arg(a, 0);
        return v is num ? v.abs() : 0.0;
      }),
      'random': AtaNativeFunction(
          'random', (a, c) async => math.Random().nextDouble()),
      'min': AtaNativeFunction('min', (a, c) async {
        final nums = a.whereType<num>();
        return nums.isEmpty ? null : nums.reduce((x, y) => x < y ? x : y);
      }),
      'max': AtaNativeFunction('max', (a, c) async {
        final nums = a.whereType<num>();
        return nums.isEmpty ? null : nums.reduce((x, y) => x > y ? x : y);
      }),
    });

    m['time'] = AtaHostObject('time', {
      'now': AtaNativeFunction(
          'time.now', (a, c) async => DateTime.now().millisecondsSinceEpoch),
      'iso': AtaNativeFunction(
          'time.iso', (a, c) async => DateTime.now().toIso8601String()),
      'unix': AtaNativeFunction('time.unix', (a, c) async =>
          DateTime.now().millisecondsSinceEpoch / 1000),
    });

    m['string'] = AtaHostObject('string', {
      'upper': AtaNativeFunction(
          'upper', (a, c) async => AtaType.toDisplay(arg(a, 0)).toUpperCase()),
      'lower': AtaNativeFunction(
          'lower', (a, c) async => AtaType.toDisplay(arg(a, 0)).toLowerCase()),
      'trim': AtaNativeFunction(
          'trim', (a, c) async => AtaType.toDisplay(arg(a, 0)).trim()),
      'format': AtaNativeFunction('format', (a, c) async {
        var out = AtaType.toDisplay(arg(a, 0));
        for (var i = 1; i < a.length; i++) {
          out = out.replaceFirst('{}', AtaType.toDisplay(a[i]));
        }
        return out;
      }),
      'split': AtaNativeFunction('split', (a, c) async {
        return AtaList(
            AtaType.toDisplay(arg(a, 0)).split(AtaType.toDisplay(arg(a, 1))).toList());
      }),
    });

    return AtaHostObject('ata', m);
  }

  AtaMapVal _httpToMap(AtaHttpResult r) => AtaMapVal({
        'status': r.status,
        'body': r.body,
        'headers': AtaMapVal(Map<String, Object?>.from(r.headers)),
      });
}

/// 跨平台延迟（无 dart:io 依赖，web 兼容）。
Future<void> osDelay(int ms) => Future<void>.delayed(Duration(milliseconds: ms));