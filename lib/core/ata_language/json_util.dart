/// AtaLanguage JSON 工具：在 Ata 值与 JSON 安全对象之间转换。
library;

import 'dart:convert';
import 'values.dart';

/// 将 JSON 安全对象转换为 Ata 值（数组->AtaList，Map->AtaMapVal）。
Object? toAtaValue(Object? v) {
  if (v is List) return AtaList(v.map(toAtaValue).toList());
  if (v is Map) {
    final m = AtaMapVal();
    v.forEach((k, val) => m.entries['$k'] = toAtaValue(val));
    return m;
  }
  return v; // num/String/bool/null 原生直通
}

/// 将 Ata 值转换为 JSON 安全对象（去除包装类）。
Object? toPlain(Object? v) {
  if (v is AtaList) return v.items.map(toPlain).toList();
  if (v is AtaMapVal) {
    final m = <String, Object?>{};
    v.entries.forEach((k, val) => m[k] = toPlain(val));
    return m;
  }
  if (v is AtaHostObject) {
    final m = <String, Object?>{};
    v.members.forEach((k, val) => m[k] = toPlain(val));
    return m;
  }
  if (v == null || v is num || v is bool || v is String) return v;
  return AtaType.toDisplay(v);
}

/// 宽松解码 JSON 字符串（直接返回 Dart 原生对象，供调用方再转 Ata）。
Object? decodeAny(String s) {
  try {
    return jsonDecode(s);
  } catch (_) {
    // 标量宽松处理
    final t = s.trim();
    final d = double.tryParse(t);
    if (d != null) return d;
    if (t == 'true') return true;
    if (t == 'false') return false;
    if (t == 'null') return null;
    if ((t.startsWith('"') && t.endsWith('"')) || t.startsWith("'") && t.endsWith("'")) {
      return t.substring(1, t.length - 1);
    }
    return s;
  }
}

/// 序列化为 JSON 字符串。
String encodeAny(Object? v) {
  try {
    return jsonEncode(toPlain(v));
  } catch (_) {
    return AtaType.toDisplay(v);
  }
}