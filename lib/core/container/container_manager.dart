/// 沙盒容器运行会话：将已安装的 .atak 应用在西式环境中隔离运行。
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as athttp;
import 'package:url_launcher/url_launcher.dart';

import '../ata_language/host.dart';
import '../ata_language/interpreter.dart';
import '../ata_language/lexer.dart';
import '../ata_language/parser.dart';
import '../ata_language/errors.dart';
import '../atak/atak_manifest.dart';
import '../atak/atak_storage.dart';

/// 运行画面实现此接口以向脚本提供对话框能力。
mixin LiveHostBridge {
  Future<String?> showInput(String prompt);
  Future<bool> showConfirm(String message);
  Future<void> showAlert(String message);
  Future<void> showNotify(String title, String body);
}

/// AtaLanguage 解释器的宿主实现（Live 容器端）。
class LiveAtaHost implements AtaHost {
  final AppSession session;
  final AtakStorage storage;

  LiveAtaHost(this.session, this.storage);

  @override
  String get appId => session.manifest.id;

  @override
  Map<String, dynamic> get manifest => session.manifest.toJson();

  @override
  Future<void> log(String message) async {
    session.addLog(message);
  }

  @override
  Future<void> renderChunk(AtaUiChunk chunk) async {
    session.addChunk(chunk);
  }

  @override
  Future<void> clearUi() async {
    session.clearChunks();
  }

  @override
  Future<String?> input(String prompt) async {
    final b = session.bridge;
    if (b == null) return null;
    return b.showInput(prompt);
  }

  @override
  Future<bool> confirm(String message) async {
    final b = session.bridge;
    if (b == null) return false;
    return b.showConfirm(message);
  }

  @override
  Future<void> alert(String message) async {
    final b = session.bridge;
    if (b != null) {
      await b.showAlert(message);
    } else {
      session.addLog('ALERT: $message');
    }
  }

  @override
  Future<void> notify(String title, String body) async {
    final b = session.bridge;
    if (b != null) {
      await b.showNotify(title, body);
    } else {
      session.addLog('NOTIFY: $title - $body');
    }
  }

  @override
  Future<AtaHttpResult> http(String method, String url,
      {Map<String, String>? headers, Object? body}) async {
    final uri = Uri.parse(url);
    final athttp.Client client = athttp.Client();
    try {
      if (method.toUpperCase() == 'POST') {
        final resp = await client.post(uri,
            headers: headers,
            body: body == null ? null : (body is String ? body : jsonEncode(body)));
        return AtaHttpResult(resp.statusCode, resp.body, resp.headers);
      }
      final resp = await client.get(uri, headers: headers);
      return AtaHttpResult(resp.statusCode, resp.body, resp.headers);
    } finally {
      client.close();
    }
  }

  @override
  Future<void> openUrl(String url) async {
    await session.openExternal(url);
  }

  @override
  Object? storeGet(String key) => storage.containerGet(appId, key);

  @override
  Future<void> storeSet(String key, Object? value) async {
    storage.containerSet(appId, key, value);
  }

  @override
  Future<void> storeRemove(String key) async {
    storage.containerRemove(appId, key);
  }

  @override
  Future<void> exit(Object? value) async {
    session.addLog('[exit] $value');
  }
}

/// 单个应用的运行会话（沙盒隔离 + 状态通知宿主界面）。
class AppSession extends ChangeNotifier {
  final AtaManifest manifest;
  final String entrySource;
  final AtakStorage storage;
  final List<String> logs = [];
  final List<AtaUiChunk> chunks = [];
  final List<String> errors = [];

  LiveHostBridge? bridge;
  Interpreter? interpreter;
  bool running = false;
  Future? _runFuture;

  AppSession(this.manifest, this.entrySource, this.storage);

  void addLog(String message) {
    logs.add(message);
    notifyListeners();
  }

  void addChunk(AtaUiChunk chunk) {
    chunks.add(chunk);
    notifyListeners();
  }

  void clearChunks() {
    chunks.clear();
    notifyListeners();
  }

  Future<void> openExternal(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      addLog('打开链接失败：$url ($e)');
    }
    addLog('[open] $url');
  }

  Future<void> start() async {
    if (running) return;
    running = true;
    logs.clear();
    chunks.clear();
    errors.clear();
    notifyListeners();

    final host = LiveAtaHost(this, storage);
    final interp = Interpreter(
      host: host,
      granted: manifest.permissions.toSet(),
      stepBudget: 500000,
    );
    interpreter = interp;
    _runFuture = _run(interp);
    await _runFuture;
  }

  Future<void> _run(Interpreter interp) async {
    try {
      final lexer = Lexer(entrySource);
      final parser = Parser(lexer.tokenize());
      final program = parser.parse();
      await interp.interpret(program);
    } on AtaError catch (e) {
      errors.add(e.toString());
      addLog('AtaError: $e');
    } catch (e) {
      errors.add('$e');
      addLog('Error: $e');
    } finally {
      running = false;
      notifyListeners();
    }
  }
}

/// 容器管理器：负责创建会话。
class ContainerManager {
  final AtakStorage storage;

  ContainerManager(this.storage);

  AppSession createSession(AtaManifest manifest, String entrySource) {
    return AppSession(manifest, entrySource, storage);
  }
}