/// AtaLanguage 抽象语法树节点。
library;

import 'token.dart';

sealed class Node {
  Token? token;
}

// ------------------------------- 表达式 -------------------------------

sealed class Expr extends Node {
  int get line => token?.line ?? 0;
}

class LiteralExpr extends Expr {
  final Object? value;
  final TokenType type;
  LiteralExpr(this.value, {Token? at}) : type = TokenType.string {
    token = at;
  }
}

class VarExpr extends Expr {
  final String name;
  VarExpr(this.name, {Token? at}) {
    token = at;
  }
  VarExpr.named(this.name);
}

class ArrayExpr extends Expr {
  final List<Expr> elements;
  ArrayExpr(this.elements, {List<Token>? at});
}

class MapExpr extends Expr {
  final List<String> keys;
  final List<Expr> values;
  MapExpr(this.keys, this.values);
}

class UnaryExpr extends Expr {
  final TokenType op;
  final Expr right;
  UnaryExpr(this.op, this.right, {Token? at}) {
    token = at;
  }
}

class BinaryExpr extends Expr {
  final TokenType op;
  final Expr left;
  final Expr right;
  BinaryExpr(this.op, this.left, this.right, {Token? at}) {
    token = at;
  }
}

class LogicalExpr extends Expr {
  final TokenType op; // and/andAnd, or/orOr
  final Expr left;
  final Expr right;
  LogicalExpr(this.op, this.left, this.right, {Token? at}) {
    token = at;
  }
}

class TernaryExpr extends Expr {
  final Expr condition;
  final Expr thenBranch;
  final Expr elseBranch;
  TernaryExpr(this.condition, this.thenBranch, this.elseBranch);
}

class CallExpr extends Expr {
  final Expr callee;
  final List<Expr> args;
  final List<Token> argTokens;
  CallExpr(this.callee, this.args, this.argTokens);
}

class IndexExpr extends Expr {
  final Expr object;
  final Expr index;
  IndexExpr(this.object, this.index);
}

class MemberExpr extends Expr {
  final Expr object;
  final String name;
  final Token nameTok;
  MemberExpr(this.object, this.name, this.nameTok);
}

class AssignExpr extends Expr {
  final Expr target; // VarExpr | MemberExpr | IndexExpr
  final Expr value;
  final TokenType op; // equal / plusEqual / minusEqual ...
  AssignExpr(this.target, this.value, this.op);
}

class PostfixExpr extends Expr {
  final Expr target; // VarExpr | MemberExpr | IndexExpr
  final TokenType op; // plusPlus / minusMinus
  PostfixExpr(this.target, this.op);
}

class FunctionExpr extends Expr {
  final List<String> params;
  final BlockStmt body;
  final String? name;
  FunctionExpr(this.params, this.body, {this.name});
}

// ------------------------------- 语句 -------------------------------

sealed class Stmt extends Node {
  int get line => token?.line ?? 0;
}

class ExprStmt extends Stmt {
  final Expr expr;
  ExprStmt(this.expr);
}

class BlockStmt extends Stmt {
  final List<Stmt> statements;
  BlockStmt(this.statements, {Token? at}) {
    token = at;
  }
}

class LetStmt extends Stmt {
  final String name;
  final bool isConst;
  final Expr? initializer;
  LetStmt(this.name, this.isConst, this.initializer, {Token? at}) {
    token = at;
  }
}

class IfStmt extends Stmt {
  final Expr condition;
  final Stmt thenBranch;
  final Stmt? elseBranch;
  IfStmt(this.condition, this.thenBranch, this.elseBranch);
}

class WhileStmt extends Stmt {
  final Expr condition;
  final Stmt body;
  WhileStmt(this.condition, this.body);
}

class ForStmt extends Stmt {
  final Stmt? initializer; // LetStmt | ExprStmt | null
  final Expr? condition;
  final Expr? increment;
  final Stmt body;
  ForStmt(this.initializer, this.condition, this.increment, this.body);
}

class ReturnStmt extends Stmt {
  final Expr? value;
  ReturnStmt(this.value, {Token? at}) {
    token = at;
  }
}

class BreakStmt extends Stmt {}

class ContinueStmt extends Stmt {}

class FunctionStmt extends Stmt {
  final String name;
  final List<String> params;
  final BlockStmt body;
  FunctionStmt(this.name, this.params, this.body, {Token? at}) {
    token = at;
  }
}

class ImportStmt extends Stmt {
  final String module; // 形如 ata.http 或 app.vendor
  final String? alias;
  ImportStmt(this.module, this.alias);
}

/// 程序根：入口文件可以是一个表达式块（直接求值）。
class Program extends Node {
  final List<Stmt> statements;
  Program(this.statements);
}