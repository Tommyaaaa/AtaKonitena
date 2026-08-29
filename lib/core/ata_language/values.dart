/// AtaLanguage 运行时值类型。
library;

import 'ast.dart';
import 'environment.dart';
import 'interpreter.dart';

/// 运行时值。
/// 基础值直接复用 Dart 类型：num / String / bool / null。
/// 复合值与函数使用如下包装类。
sealed class AtaValue {}

/// 数组。
class AtaList extends AtaValue {
  final List<Object?> items = [];
  AtaList([Iterable<Object?>? seed]) {
    if (seed != null) items.addAll(seed);
  }
}

/// Map（对象）。
class AtaMapVal extends AtaValue {
  final Map<String, Object?> entries = {};
  AtaMapVal([Map<String, Object?>? seed]) {
    if (seed != null) entries.addAll(seed);
  }
}

/// 宿主对象（由容器暴露的能力视图，如 `ata` 命名空间）。
class AtaHostObject extends AtaValue {
  final String name;
  final Map<String, Object?> members;
  AtaHostObject(this.name, this.members);
}

/// Ata 函数（用户定义函数）。
class AtaFunction extends AtaValue {
  final String? name;
  final List<String> params;
  final BlockStmt body;
  final Environment closure;
  final bool isArrow;
  AtaFunction(this.params, this.body, this.closure,
      {this.name, this.isArrow = false});
}

/// 原生函数（由宿主注入，如 ata.print）。
class AtaNativeFunction extends AtaValue {
  final String name;
  /// args 为已求值的实参列表；ctx 提供对宿主与环境的访问。
  final Object? Function(List<Object?> args, NativeCallContext ctx) call;
  AtaNativeFunction(this.name, this.call);
}

/// 类型判断与转换工具。
class AtaType {
  static bool isTruthy(Object? v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) return v.isNotEmpty;
    return true;
  }

  static String typeName(Object? v) {
    if (v == null) return 'null';
    return switch (v) {
      int() || double() => 'number',
      String() => 'string',
      bool() => 'boolean',
      AtaList() => 'array',
      AtaMapVal() => 'map',
      AtaHostObject() => 'object',
      AtaFunction() || AtaNativeFunction() => 'function',
      _ => v.runtimeType.toString(),
    };
  }

  static String toDisplay(Object? v) {
    if (v == null) return 'null';
    return switch (v) {
      bool b => b ? 'true' : 'false',
      String s => s,
      num n => n.toString(),
      AtaList l => _listToDisplay(l.items),
      AtaMapVal m => _mapToDisplay(m.entries),
      AtaHostObject o => '<${o.name}>',
      AtaFunction f => '<func${f.name == null ? '' : ' ${f.name}'}(${f.params.join(', ')})>',
      AtaNativeFunction n => '<native func ${n.name}>',
      _ => v.toString(),
    };
  }

  static String _listToDisplay(List<Object?> items) {
    final parts = items.map(toDisplay).join(', ');
    return '[$parts]';
  }

  static String _mapToDisplay(Map<String, Object?> m) {
    final parts = m.entries
        .map((e) => '"${e.key}": ${toDisplay(e.value)}')
        .join(', ');
    return '{$parts}';
  }
}