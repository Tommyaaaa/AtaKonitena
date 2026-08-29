/// AtaLanguage 作用域环境。
library;

/// 词法作用域：支持变量定义、读取、赋值、就近覆盖。
class Environment {
  final Environment? parent;
  final Map<String, Object?> _values = {};
  final Map<String, bool> _consts = {};

  Environment(this.parent);

  /// 当前作用域内是否已定义。
  bool existsLocally(String name) => _values.containsKey(name);

  /// 沿作用域链查找变量所有者。
  Environment? enclosing(String name) {
    if (_values.containsKey(name)) return this;
    return parent?.enclosing(name);
  }

  Object? get(String name) {
    final holder = enclosing(name);
    if (holder == null) return null;
    return holder._values[name];
  }

  bool isConst(String name) {
    final holder = enclosing(name);
    if (holder == null) return false;
    return holder._consts[name] ?? false;
  }

  void define(String name, Object? value, {bool isConst = false}) {
    _values[name] = value;
    _consts[name] = isConst;
  }

  /// 赋值：允许覆盖父作用域中已存在的普通变量。
  void assign(String name, Object? value) {
    final holder = enclosing(name);
    if (holder == null) {
      throw StateError('未知变量 "$name"');
    }
    if (holder._consts[name] ?? false) {
      throw StateError('不能给常量 "$name" 重新赋值');
    }
    holder._values[name] = value;
  }

  Environment child() => Environment(this);
}