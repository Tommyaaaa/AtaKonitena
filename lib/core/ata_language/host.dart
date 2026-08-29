/// 容器宿主桥接接口：解释器通过它访问宿主能力（UI、网络、沙盒存储等）。
/// 解释器本身保持纯 Dart、可离线测试；Flutter 端实现本接口注入真实能力。
library;

/// 一段推送到宿主 UI 的内容块（对应 `ata.show` / `ata.text`）。
class AtaUiChunk {
  final String kind; // 'text' | 'heading' | 'list' | 'error'
  final String content;
  const AtaUiChunk(this.kind, this.content);
}

/// HTTP 返回。
class AtaHttpResult {
  final int status;
  final String body;
  final Map<String, String> headers;
  const AtaHttpResult(this.status, this.body, [this.headers = const {}]);
}

/// AtaLanguage 允许访问的能力位。
class AtaCapability {
  static const String display = 'atak:display';
  static const String input = 'atak:input';
  static const String http = 'atak:http';
  static const String openUrl = 'atak:open';
  static const String storage = 'atak:storage';
  static const String notify = 'atak:notify';
}

/// 宿主实现。所有方法均异步，以兼容 Flutter UI 交互与网络。
abstract class AtaHost {
  String get appId;
  Map<String, dynamic> get manifest;

  /// 打印到该应用的日志流/控制台。
  Future<void> log(String message);

  /// 将内容块推送到宿主为该应用保留的 UI 画布。
  Future<void> renderChunk(AtaUiChunk chunk);

  /// 清除该应用 UI 画布。
  Future<void> clearUi();

  /// 弹输入框，返回 null 表示取消。
  Future<String?> input(String prompt);

  /// 弹确认框。
  Future<bool> confirm(String message);

  /// 弹信息提示。
  Future<void> alert(String message);

  /// 发送系统通知。
  Future<void> notify(String title, String body);

  /// 发起 HTTP 请求（宿主需校验权限后放行）。
  Future<AtaHttpResult> http(String method, String url,
      {Map<String, String>? headers, Object? body});

  /// 用系统浏览器打开链接。
  Future<void> openUrl(String url);

  /// 沙盒内键值存储（per-app 隔离目录）。
  Object? storeGet(String key);
  Future<void> storeSet(String key, Object? value);
  Future<void> storeRemove(String key);

  /// 退出并返回结果。
  Future<void> exit(Object? value);
}