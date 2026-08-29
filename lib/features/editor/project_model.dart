/// 一个可在应用内创建、编辑、打包的项目。
library;

import '../../core/atak/atak_manifest.dart';

/// 应用内项目：清单 + 一组源文件（相对路径 -> 文本内容）。
class AtaProject {
  final AtaManifest manifest;
  final Map<String, String> files;

  AtaProject({required this.manifest, required this.files});

  /// 入口脚本源码。
  String? get entrySource => files[manifest.entry];

  /// 除入口与 manifest.json 外的其它文本文件（用于打包进 .atak）。
  Map<String, String> get extraTexts {
    final out = <String, String>{};
    files.forEach((path, content) {
      if (path == manifest.entry) return;
      if (path == 'manifest.json') return;
      out[path] = content;
    });
    return out;
  }

  AtaProject copyWith({AtaManifest? manifest, Map<String, String>? files}) =>
      AtaProject(
        manifest: manifest ?? this.manifest,
        files: files ?? Map.from(this.files),
      );

  Map<String, dynamic> toJson() => {
        'manifest': manifest.toJson(),
        'files': files,
      };

  factory AtaProject.fromJson(Map<String, dynamic> json) {
    final m = json['manifest'] as Map;
    final filesRaw = json['files'] as Map;
    return AtaProject(
      manifest: AtaManifest.fromJson(Map<String, dynamic>.from(m)),
      files: Map<String, String>.from(
          filesRaw.map((k, v) => MapEntry('$k', '$v'))),
    );
  }
}
