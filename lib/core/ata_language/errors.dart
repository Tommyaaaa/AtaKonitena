/// AtaLanguage 错误类型统一入口。
library;

/// 统一的 Ata 错误基类。
class AtaError implements Exception {
  final String message;
  final int? line;
  final int? column;
  AtaError(this.message, {this.line, this.column});

  @override
  String toString() {
    final loc = line == null ? '' : '[$line:${column ?? 0}] ';
    return 'AtaError: $loc$message';
  }
}

/// 词法分析错误。
class AtaLexError extends AtaError {
  AtaLexError(super.message, {super.line, super.column});
  @override
  String toString() => 'AtaLexError: ${line ?? ''} $message'.trim();
}

/// 语法解析错误。
class AtaParseError extends AtaError {
  AtaParseError(super.message, {super.line, super.column});
  @override
  String toString() =>
      'AtaParseError: ${line == null ? '' : '[$line:${column ?? 0}] '}$message'
          .trim();
}

/// 运行时错误。
class AtaRuntimeError extends AtaError {
  AtaRuntimeError(super.message, {super.line, super.column});
  @override
  String toString() =>
      'AtaRuntimeError: ${line == null ? '' : '[$line:${column ?? 0}] '}$message'
          .trim();
}

/// 权限错误（沙盒容器拒绝访问未声明的能力）。
class AtaPermissionError extends AtaRuntimeError {
  AtaPermissionError(super.message, {super.line, super.column});
  @override
  String toString() =>
      'AtaPermissionError: ${line == null ? '' : '[$line:${column ?? 0}] '}$message'
          .trim();
}

/// 超时/被杀信号。
class AtaTimeoutError extends AtaRuntimeError {
  AtaTimeoutError(super.message);
}

/// 通过该异常实现宿主 `ata.exit()`。
class AtaExitSignal implements Exception {
  final Object? value;
  AtaExitSignal(this.value);
}