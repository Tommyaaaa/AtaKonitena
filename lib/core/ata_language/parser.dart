/// AtaLanguage 语法分析器：将 [Token] 流解析为 AST。
library;

import 'token.dart';
import 'ast.dart';
import 'errors.dart';

class Parser {
  final List<Token> tokens;
  int _current = 0;

  Parser(List<Token> tokens) : tokens = tokens;

  Program parse() {
    final statements = <Stmt>[];
    while (!_isAtEnd) {
      statements.add(_declaration());
    }
    return Program(statements);
  }

  bool get _isAtEnd => peek().type == TokenType.eof;
  Token get _previous => tokens[_current - 1];
  Token peek() => tokens[_current];
  Token advance() {
    if (!_isAtEnd) _current++;
    return _previous;
  }

  bool _check(TokenType type) => !_isAtEnd && peek().type == type;
  bool _matchAny(List<TokenType> types) {
    for (final t in types) {
      if (_check(t)) {
        advance();
        return true;
      }
    }
    return false;
  }

  Token _consume(TokenType type, String message) {
    if (_check(type)) return advance();
    final t = peek();
    throw AtaParseError(message, line: t.line, column: t.column);
  }

  bool _checkKeyword(String kw) =>
      !_isAtEnd && peek().type == TokenType.keyword && peek().lexeme == kw;

  bool _consumeKeyword(String kw) {
    if (_checkKeyword(kw)) {
      advance();
      return true;
    }
    return false;
  }

  // -------------------------- 语句 --------------------------

  Stmt _declaration() {
    if (_consumeKeyword('func')) return _functionStmt();
    if (_consumeKeyword('import')) return _importStmt();
    return _statement();
  }

  Stmt _importStmt() {
    final start = _previous;
    final module = <String>[];
    module.add(_consume(TokenType.identifier, 'import 后需为模块名').lexeme);
    while (_matchAny(const [TokenType.dot])) {
      module.add(_consume(TokenType.identifier, '模块路径需为标识符').lexeme);
    }
    String? alias;
    if (_consumeKeyword('as')) {
      alias = _consume(TokenType.identifier, '需为别名命名').lexeme;
    }
    _consume(TokenType.semicolon, "import 语句需以 ';' 结尾");
    return ImportStmt(module.join('.'), alias)..token = start;
  }

  Stmt _functionStmt() {
    final start = _previous;
    final name = _consume(TokenType.identifier, '函数名需为标识符').lexeme;
    _consume(TokenType.leftParen, "函数名后应接 '('");
    final params = _parameterList();
    _consume(TokenType.rightParen, "参数列表后应接 ')'");
    final body = _block();
    return FunctionStmt(name, params, body, at: start);
  }

  List<String> _parameterList() {
    final params = <String>[];
    if (!_check(TokenType.rightParen)) {
      do {
        params.add(_consume(TokenType.identifier, '参数名需为标识符').lexeme);
      } while (_matchAny(const [TokenType.comma]));
    }
    return params;
  }

  Stmt _statement() {
    if (_matchAny(const [TokenType.semicolon])) {
      return ExprStmt(LiteralExpr(null, at: _previous));
    }
    if (_checkKeyword('let') || _checkKeyword('const')) return _letStmt();
    if (_consumeKeyword('if')) return _ifStmt();
    if (_consumeKeyword('while')) return _whileStmt();
    if (_consumeKeyword('for')) return _forStmt();
    if (_consumeKeyword('return')) return _returnStmt();
    if (_consumeKeyword('break')) {
      _consume(TokenType.semicolon, "break 后应接 ';'") ;
      return BreakStmt();
    }
    if (_consumeKeyword('continue')) {
      _consume(TokenType.semicolon, "continue 后应接 ';'") ;
      return ContinueStmt();
    }
    if (_check(TokenType.leftBrace)) return _block();
    return _exprStatement();
  }

  Stmt _letStmt() {
    final isConst = _consumeKeyword('const');
    _consumeKeyword('let'); // 已匹配则忽略
    final start = _previous;
    final name = _consume(TokenType.identifier, '变量名需为标识符').lexeme;
    Expr? init;
    if (_matchAny(const [TokenType.equal])) {
      init = _expression();
    }
    _consume(TokenType.semicolon, "声明语句需以 ';' 结尾");
    return LetStmt(name, isConst, init, at: start);
  }

  Stmt _ifStmt() {
    _consume(TokenType.leftParen, "if 后应接 '('");
    final cond = _expression();
    _consume(TokenType.rightParen, "if 条件后应接 ')'");
    final thenBranch = _statement();
    Stmt? elseBranch;
    if (_consumeKeyword('else')) {
      elseBranch = _statement();
    }
    return IfStmt(cond, thenBranch, elseBranch);
  }

  Stmt _whileStmt() {
    _consume(TokenType.leftParen, "while 后应接 '('");
    final cond = _expression();
    _consume(TokenType.rightParen, "while 条件后应接 ')'");
    final body = _statement();
    return WhileStmt(cond, body);
  }

  Stmt _forStmt() {
    _consume(TokenType.leftParen, "for 后应接 '('");
    Stmt? init;
    if (!_matchAny(const [TokenType.semicolon])) {
      if (_checkKeyword('let') || _checkKeyword('const')) {
        init = _letStmtNoSemi();
      } else {
        init = _exprStatementNoSemi();
      }
    }
    Expr? cond;
    if (!_check(TokenType.semicolon)) {
      cond = _expression();
    }
    _consume(TokenType.semicolon, "for 条件后应接 ';'");
    Expr? incr;
    if (!_check(TokenType.rightParen)) {
      incr = _expression();
    }
    _consume(TokenType.rightParen, "for 声明后应接 ')'");
    final body = _statement();
    return ForStmt(init, cond, incr, body);
  }

  Stmt _letStmtNoSemi() {
    final isConst = _consumeKeyword('const');
    _consumeKeyword('let');
    final start = _previous;
    final name = _consume(TokenType.identifier, '变量名需为标识符').lexeme;
    Expr? init;
    if (_matchAny(const [TokenType.equal])) {
      init = _expression();
    }
    return LetStmt(name, isConst, init, at: start);
  }

  Stmt _exprStatementNoSemi() {
    final expr = _expression();
    return ExprStmt(expr);
  }

  Stmt _returnStmt() {
    final start = _previous;
    Expr? value;
    if (!_check(TokenType.semicolon)) {
      value = _expression();
    }
    _consume(TokenType.semicolon, "return 后应接 ';'");
    return ReturnStmt(value, at: start);
  }

  BlockStmt _block() {
    final lbrace = _consume(TokenType.leftBrace, "应为 '{'");
    final statements = <Stmt>[];
    while (!_check(TokenType.rightBrace) && !_isAtEnd) {
      statements.add(_declaration());
    }
    _consume(TokenType.rightBrace, "应为 '}'");
    return BlockStmt(statements, at: lbrace);
  }

  Stmt _exprStatement() {
    final expr = _expression();
    _consume(TokenType.semicolon, "语句需以 ';' 结尾");
    return ExprStmt(expr);
  }

  // -------------------------- 表达式 --------------------------

  Expr _expression() => _assignment();

  Expr _assignment() {
    final expr = _ternary();
    if (_matchAny(const [
      TokenType.equal,
      TokenType.plusEqual,
      TokenType.minusEqual,
      TokenType.starEqual,
      TokenType.slashEqual,
      TokenType.percentEqual,
    ])) {
      final op = _previous.type;
      final value = _assignment();
      if (expr is! VarExpr && expr is! MemberExpr && expr is! IndexExpr) {
        throw AtaParseError(
            '赋值目标不合法：应为变量、成员或下标',
            line: _previous.line,
            column: _previous.column);
      }
      return AssignExpr(expr, value, op);
    }
    return expr;
  }

  Expr _ternary() {
    final cond = _logicalOr();
    if (_matchAny(const [TokenType.question])) {
      final thenBranch = _expression();
      _consume(TokenType.colon, "三元表达式需要 ':'");
      final elseBranch = _expression();
      return TernaryExpr(cond, thenBranch, elseBranch);
    }
    return cond;
  }

  Expr _logicalOr() {
    var expr = _logicalAnd();
    while (true) {
      if (_matchAny(const [TokenType.orOr])) {
        // 已消费 ||
      } else if (_consumeKeyword('or')) {
        // 已消费关键字 or
      } else {
        break;
      }
      final right = _logicalAnd();
      expr = LogicalExpr(TokenType.orOr, expr, right);
    }
    return expr;
  }

  Expr _logicalAnd() {
    var expr = _equality();
    while (true) {
      if (_matchAny(const [TokenType.andAnd])) {
        // 已消费 &&
      } else if (_consumeKeyword('and')) {
        // 已消费关键字 and
      } else {
        break;
      }
      final right = _equality();
      expr = LogicalExpr(TokenType.andAnd, expr, right);
    }
    return expr;
  }

  Expr _equality() {
    var expr = _comparison();
    while (_matchAny(const [TokenType.equalEqual, TokenType.bangEqual])) {
      final op = _previous.type;
      final right = _comparison();
      expr = BinaryExpr(op, expr, right);
    }
    return expr;
  }

  Expr _comparison() {
    var expr = _term();
    while (_matchAny(const [
      TokenType.less,
      TokenType.lessEqual,
      TokenType.greater,
      TokenType.greaterEqual,
    ])) {
      final op = _previous.type;
      final right = _term();
      expr = BinaryExpr(op, expr, right);
    }
    return expr;
  }

  Expr _term() {
    var expr = _factor();
    while (_matchAny(const [TokenType.plus, TokenType.minus])) {
      final op = _previous.type;
      final right = _factor();
      expr = BinaryExpr(op, expr, right);
    }
    return expr;
  }

  Expr _factor() {
    var expr = _unary();
    while (_matchAny(const [
      TokenType.star,
      TokenType.slash,
      TokenType.percent,
    ])) {
      final op = _previous.type;
      final right = _unary();
      expr = BinaryExpr(op, expr, right);
    }
    return expr;
  }

  Expr _unary() {
    if (_matchAny(const [TokenType.bang, TokenType.minus, TokenType.plus])) {
      final op = _previous.type;
      final right = _unary();
      return UnaryExpr(op, right);
    }
    if (_checkKeyword('not')) {
      advance();
      final right = _unary();
      return UnaryExpr(TokenType.bang, right);
    }
    return _postfix();
  }

  Expr _postfix() {
    var expr = _primary();
    while (true) {
      if (_matchAny(const [TokenType.dot])) {
        final nameTok =
            _consume(TokenType.identifier, "成员访问需要标识符");
        expr = MemberExpr(expr, nameTok.lexeme, nameTok);
      } else if (_matchAny(const [TokenType.leftParen])) {
        final args = <Expr>[];
        final argTokens = <Token>[];
        if (!_check(TokenType.rightParen)) {
          do {
            args.add(_expression());
            argTokens.add(_previous);
          } while (_matchAny(const [TokenType.comma]));
        }
        _consume(TokenType.rightParen, "调用参数后应接 ')'");
        expr = CallExpr(expr, args, argTokens);
      } else if (_matchAny(const [TokenType.leftBracket])) {
        final index = _expression();
        _consume(TokenType.rightBracket, "下标后应接 ']'");
        expr = IndexExpr(expr, index);
      } else if (_matchAny(const [TokenType.plusPlus, TokenType.minusMinus])) {
        final op = _previous.type;
        if (expr is! VarExpr && expr is! MemberExpr && expr is! IndexExpr) {
          throw AtaParseError('++/-- 目标不合法', line: _previous.line);
        }
        expr = PostfixExpr(expr, op);
      } else {
        break;
      }
    }
    return expr;
  }

  Expr _primary() {
    if (_matchAny(const [TokenType.number])) {
      return LiteralExpr(_previous.literal, at: _previous);
    }
    if (_matchAny(const [TokenType.string])) {
      return LiteralExpr(_previous.literal, at: _previous);
    }
    if (_matchAny(const [TokenType.identifier])) {
      return VarExpr(_previous.lexeme, at: _previous);
    }
    if (_checkKeyword('true')) {
      advance();
      return LiteralExpr(true, at: _previous);
    }
    if (_checkKeyword('false')) {
      advance();
      return LiteralExpr(false, at: _previous);
    }
    if (_checkKeyword('null') || _checkKeyword('void')) {
      advance();
      return LiteralExpr(null, at: _previous);
    }
    if (_checkKeyword('func')) {
      advance();
      return _anonymousFunction();
    }
    if (_matchAny(const [TokenType.leftParen])) {
      final expr = _expression();
      _consume(TokenType.rightParen, "应为 ')'");
      return expr;
    }
    if (_matchAny(const [TokenType.leftBracket])) {
      return _arrayLiteral();
    }
    if (_matchAny(const [TokenType.leftBrace])) {
      return _mapLiteral();
    }
    final err = peek();
    throw AtaParseError('意外的 token "${err.lexeme}"',
        line: err.line, column: err.column);
  }

  Expr _anonymousFunction() {
    // func(参数列表) { 函数体 } —— 匿名 / 立即执行函数
    _consume(TokenType.leftParen, "func 后应接 '('");
    final params = _parameterList();
    _consume(TokenType.rightParen, "参数列表后应接 ')'");
    final body = _block();
    return FunctionExpr(params, body);
  }

  Expr _arrayLiteral() {
    final elements = <Expr>[];
    if (!_check(TokenType.rightBracket)) {
      do {
        elements.add(_expression());
      } while (_matchAny(const [TokenType.comma]));
    }
    _consume(TokenType.rightBracket, "应为 ']'");
    return ArrayExpr(elements);
  }

  Expr _mapLiteral() {
    final keys = <String>[];
    final values = <Expr>[];
    if (!_check(TokenType.rightBrace)) {
      do {
        // key: identifier / string / number
        if (_matchAny(const [TokenType.identifier])) {
          keys.add(_previous.lexeme);
        } else if (_matchAny(const [TokenType.string])) {
          keys.add(_previous.literal as String);
        } else if (_matchAny(const [TokenType.number])) {
          keys.add((_previous.literal as num).toString());
        } else {
          throw AtaParseError('Map 键需为标识符/字符串/数字',
              line: peek().line, column: peek().column);
        }
        _consume(TokenType.colon, "Map 键后应接 ':'");
        values.add(_expression());
      } while (_matchAny(const [TokenType.comma, TokenType.semicolon]));
    }
    _consume(TokenType.rightBrace, "应为 '}'");
    return MapExpr(keys, values);
  }
}