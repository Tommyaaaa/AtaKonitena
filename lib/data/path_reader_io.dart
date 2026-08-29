/// 桌面 / 移动端的真实文件读取实现。
library;

import 'dart:io';
import 'dart:typed_data';

Uint8List? readPathBytes(String path) {
  try {
    return File(path).readAsBytesSync();
  } catch (_) {
    return null;
  }
}