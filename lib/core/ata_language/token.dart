/// AtaLanguage 词法单元定义。
library;

/// 终结符种类。
enum TokenType {
  // 字面量
  identifier,
  number,
  string,
  keyword,

  // 单字符
  leftParen,
  rightParen,
  leftBrace,
  rightBrace,
  leftBracket,
  rightBracket,
  comma,
  dot,
  semicolon,
  colon,
  question,

  // 运算符（单字符）
  plus,
  minus,
  star,
  slash,
  percent,
  bang,

  // 运算符（多字符）
  plusPlus,
  minusMinus,
  plusEqual,
  minusEqual,
  starEqual,
  slashEqual,
  percentEqual,
  equalEqual,
  bangEqual,
  less,
  lessEqual,
  greater,
  greaterEqual,
  equal,
  andAnd,
  orOr,
  arrow,

  eof,
}

/// 一个词法单元。
class Token {
  final TokenType type;
  final String lexeme;

  /// 字面量值：number->double，string->String，keyword 中 true/false/null->bool/null。
  final Object? literal;
  final int line;
  final int column;

  const Token(this.type, this.lexeme, this.literal, this.line, this.column);

  /// 判断是否属于给定运算符集合（便捷构造）。
  bool isOneOf(Set<TokenType> types) => types.contains(type);

  @override
  String toString() => 'Token(${type.name}, "$lexeme", $literal) @ $line:$column';
}