/// `.atak` 应用包清单模型与校验。
library;

import 'dart:convert';

/// 支持的权限白名单。
const List<String> kKnownCapabilities = [
  'atak:display', // 在宿主画布上显示文本
  'atak:input',   // 输入框 / 确认框
  'atak:http',    // 网络请求
  'atak:open',    // 打开外部链接
  'atak:storage', // 沙盒内键值存储
  'atak:notify',  // 系统通知
];

/// 一个 .atak 应用的清单。
class AtaManifest {
  final String id;
  final String name;
  final String version;
  final String author;
  final String description;
  final String entry;
  final String iconPath; // 包内相对路径，可为空
  final String type; // app | widget | cli
  final List<String> permissions;
  final String minRuntime;
  final int formatVersion;

  const AtaManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.author,
    required this.description,
    required this.entry,
    this.iconPath = '',
    this.type = 'app',
    this.permissions = const [],
    this.minRuntime = '1.0',
    this.formatVersion = 1,
  });

  factory AtaManifest.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    final name = json['name'] as String? ?? '未命名应用';
    final version = json['version'] as String? ?? '0.0.0';
    final entry = json['entry'] as String? ?? 'app.ata';

    final manifest = AtaManifest(
      id: id,
      name: name,
      version: version,
      author: json['author'] as String? ?? '',
      description: json['description'] as String? ?? '',
      entry: entry,
      iconPath: json['icon'] as String? ?? '',
      type: json['type'] as String? ?? 'app',
      permissions: (json['permissions'] as List?)?.map((e) => '$e').toList() ??
          const [],
      minRuntime: json['minRuntime'] as String? ?? '1.0',
      formatVersion: (json['formatVersion'] as num?)?.toInt() ?? 1,
    );
    return manifest;
  }

  /// 校验清单，返回错误信息列表（空表示通过）。
  List<String> validate() {
    final errors = <String>[];
    if (id.isEmpty) errors.add('缺少 id');
    if (!RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9._-]*$').hasMatch(id)) {
      errors.add('id 格式非法（需为类似 com.example.hello 的反向域名）');
    }
    if (name.isEmpty) errors.add('缺少 name');
    if (version.isEmpty) errors.add('缺少 version');
    if (entry.isEmpty) errors.add('缺少 entry（入口脚本）');
    final unknown = permissions
        .where((p) => !kKnownCapabilities.contains(p))
        .toList();
    if (unknown.isNotEmpty) errors.add('包含未知权限：${unknown.join(', ')}');
    return errors;
  }

  Map<String, dynamic> toJson() => {
        'format': 'atak',
        'formatVersion': formatVersion,
        'id': id,
        'name': name,
        'version': version,
        'author': author,
        'description': description,
        'entry': entry,
        'icon': iconPath,
        'type': type,
        'permissions': permissions,
        'minRuntime': minRuntime,
      };

  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());
}