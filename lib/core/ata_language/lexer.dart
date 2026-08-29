/// AtaLanguage 词法分析器：将源码字符串切分为 [Token] 流。
library;

import 'token.dart';
import 'errors.dart';

const Set<String> _keywords = {
  'let', 'const', 'func', 'return', 'if', 'else', 'while', 'for',
  'break', 'continue', 'true', 'false', 'null', 'void',
  'and', 'or', 'not', 'in', 'of', 'import',
};

class Lexer {
  final String source;
  int _start = 0;
  int _current = 0;
  int _line = 1;
  int _column = 1;
  final List<Token> tokens = [];

  Lexer(this.source);

  List<Token> tokenize() {
    while (!_isAtEnd) {
      _start = _current;
      _scanToken();
    }
    tokens.add(Token(TokenType.eof, '', null, _line, _column));
    return tokens;
  }

  bool get _isAtEnd => _current >= source.length;

  char peek() => _isAtEnd ? '\u0000' : source[_current];
  char peekNext() =>
      _current + 1 >= source.length ? '\u0000' : source[_current + 1];
  char advance() {
    final c = source[_current];
    _current++;
    if (c == '\n') {
      _line++;
      _column = 1;
    } else {
      _column++;
    }
    return c;
  }

  bool _match(String expected) {
    if (_isAtEnd) return false;
    if (source[_current] != expected) return false;
    _current++;
    _column++;
    return true;
  }

  void _addToken(TokenType type, [Object? literal]) {
    final text = source.substring(_start, _current);
    tokens.add(Token(type, text, literal, _line, _column - text.length));
  }

  void _scanToken() {
    final c = advance();
    switch (c) {
      case ' ':
      case '\t':
      case '\r':
      case '\n':
        break; // 忽略空白
      case '(':
        _addToken(TokenType.leftParen);
        break;
      case ')':
        _addToken(TokenType.rightParen);
        break;
      case '{':
        _addToken(TokenType.leftBrace);
        break;
      case '}':
        _addToken(TokenType.rightBrace);
        break;
      case '[':
        _addToken(TokenType.leftBracket);
        break;
      case ']':
        _addToken(TokenType.rightBracket);
        break;
      case ',':
        _addToken(TokenType.comma);
        break;
      case ';':
        _addToken(TokenType.semicolon);
        break;
      case ':':
        _addToken(_match('=') ? TokenType.arrow : TokenType.colon);
        break;
      case '?':
        _addToken(_match('?') ? TokenType.questionQuestion : TokenType.question);
        break;
      case '.':
        if (_isDigit(peek())) {
          _numberAfterDot();
        } else {
          _addToken(TokenType.dot);
        }
        break;
      case '+':
        if (_match('+')) {
          _addToken(TokenType.plusPlus);
        } else if (_match('=')) {
          _addToken(TokenType.plusEqual);
        } else {
          _addToken(TokenType.plus);
        }
        break;
      case '-':
        if (_match('-')) {
          _addToken(TokenType.minusMinus);
        } else if (_match('=')) {
          _addToken(TokenType.minusEqual);
        } else {
          _addToken(TokenType.minus);
        }
        break;
      case '*':
        _addToken(_match('=') ? TokenType.starEqual : TokenType.star);
        break;
      case '/':
        if (_match('/')) {
          while (peek() != '\n' && !_isAtEnd) {
            advance();
          }
        } else if (_match('*')) {
          _blockComment();
        } else if (_match('=')) {
          _addToken(TokenType.slashEqual);
        } else {
          _addToken(TokenType.slash);
        }
        break;
      case '%':
        _addToken(_match('=') ? TokenType.percentEqual : TokenType.percent);
        break;
      case '!':
        _addToken(_match('=') ? TokenType.bangEqual : TokenType.bang);
        break;
      case '=':
        if (_match('=')) {
          _addToken(TokenType.equalEqual);
        } else {
          _addToken(TokenType.equal);
        }
        break;
      case '<':
        _addToken(_match('=') ? TokenType.lessEqual : TokenType.less);
        break;
      case '>':
        _addToken(_match('=') ? TokenType.greaterEqual : TokenType.greater);
        break;
      case '&':
        if (_match('&')) {
          _addToken(TokenType.andAnd);
        } else {
          _error('意外的字符 "&"');
        }
        break;
      case '|':
        if (_match('|')) {
          _addToken(TokenType.orOr);
        } else {
          _error('意外的字符 "|"');
        }
        break;
      case '#':
        while (peek() != '\n' && !_isAtEnd) {
          advance();
        }
        break;
      case '"':
      case "'":
        _string(_lastChar(c));
        break;
      default:
        if (_isDigit(c)) {
          _number();
        } else if (_isAlpha(c) || c == '_') {
          _identifier();
        } else {
          _error('意外的字符 "$c"');
        }
        break;
    }
  }

  char _lastChar(char c) => c;

  void _identifier() {
    while (_isAlphaNumeric(peek())) {
      advance();
    }
    final text = source.substring(_start, _current);
    if (_keywords.contains(text)) {
      _addToken(TokenType.keyword);
    } else {
      _addToken(TokenType.identifier);
    }
  }

  void _number() {
    while (_isDigit(peek())) {
      advance();
    }
    if (peek() == '.' && _isDigit(peekNext())) {
      advance();
      while (_isDigit(peek())) {
        advance();
      }
    }
    if ((peek() == 'e' || peek() == 'E') &&
        (_isDigit(peekNext()) ||
            ((peekNext() == '+' || peekNext() == '-') &&
                _current + 2 < source.length &&
                _isDigit(source[_current + 2])))) {
      advance();
      if (peek() == '+' || peek() == '-') advance();
      while (_isDigit(peek())) {
        advance();
      }
    }
    final value = double.parse(source.substring(_start, _current));
    _addToken(TokenType.number, value);
  }

  void _numberAfterDot() {
    while (_isDigit(peek())) {
      advance();
    }
    final value = double.parse(source.substring(_start, _current));
    _addToken(TokenType.number, value);
  }

  void _string(String quote) {
    final buf = StringBuffer();
    while (peek() != quote && !_isAtEnd) {
      var c = advance();
      if (c == r'\') {
        if (_isAtEnd) break;
        final esc = advance();
        switch (esc) {
          case 'n':
            buf.write('\n');
            break;
          case 't':
            buf.write('\t');
            break;
          case 'r':
            buf.write('\r');
            break;
          case '\\':
            buf.write(r'\');
            break;
          case '"':
            buf.write('"');
            break;
          case "'":
            buf.write("'");
            break;
          case r'$':
            buf.write(r'$');
            break;
          default:
            buf.write(esc);
            break;
        }
      } else {
        buf.write(c);
      }
    }
    if (_isAtEnd) {
      _error('字符串未闭合');
      return;
    }
    advance(); // 消耗闭合引号
    _addToken(TokenType.string, buf.toString());
  }

  void _blockComment() {
    var depth = 1;
    while (!_isAtEnd && depth > 0) {
      final c = advance();
      if (c == '*' && peek() == '/') {
        advance();
        depth--;
      } else if (c == '/' && peek() == '*') {
        advance();
        depth++;
      }
    }
    if (depth > 0) {
      _error('块注释未闭合');
    }
  }

  void _error(String message) {
    throw AtaLexError(message, line: _line, column: _column);
  }

  bool _isDigit(String c) => c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;
  bool _isAlpha(String c) =>
      (c.codeUnitAt(0) >= 97 && c.codeUnitAt(0) <= 122) ||
      (c.codeUnitAt(0) >= 65 && c.codeUnitAt(0) <= 90);
  bool _isAlphaNumeric(String c) => _isAlpha(c) || _isDigit(c) || c == '_';
}

// 便捷类型别名：char 即 String 单字符。
typedef char = String;