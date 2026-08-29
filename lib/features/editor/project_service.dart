/// 项目服务：在应用存储中持久化项目，并将其打包为 .atak 安装。
library;

import 'dart:convert';
import 'dart:typed_data';
import '../../app_services.dart';
import '../../core/atak/atak_manifest.dart';
import '../../data/atak_store.dart';
import '../../core/atak/atak_package.dart';
import 'project_model.dart';

class ProjectService {
  final AtakStore store;

  ProjectService(this.store);

  bool get ready => store.ready;

  Future<void> init() => store.init();

  List<String> _listIds() => store
      .listChildren('projects')
      .where((n) => n.endsWith('.json'))
      .map((n) => n.substring(0, n.length - 5))
      .toList();

  /// 列出全部项目（按名称排序）。
  List<AtaProject> listProjects() {
    final out = <AtaProject>[];
    for (final id in _listIds()) {
      final p = load(id);
      if (p != null) out.add(p);
    }
    out.sort((a, b) => a.manifest.name.compareTo(b.manifest.name));
    return out;
  }

  AtaProject? load(String id) {
    final raw = store.readText('projects/$id.json');
    if (raw == null) return null;
    try {
      return AtaProject.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  void save(AtaProject project) {
    if (!store.ready) return;
    store.writeText(
      'projects/${project.manifest.id}.json',
      const JsonEncoder.withIndent('  ').convert(project.toJson()),
    );
  }

  void delete(String id) {
    store.deleteRecursive('projects/$id.json');
  }

  /// 新建一个默认示例项目（供「新建项目」使用）。
  AtaProject createDefault({String? id, String? name}) {
    final pid = id ?? 'com.example.myapp';
    final pname = name ?? '我的应用';
    final manifest = AtaManifest(
      id: pid,
      name: pname,
      version: '1.0.0',
      author: '我',
      description: '在 AtaKonitena 内置编辑器中创建的应用。',
      entry: 'app.ata',
      permissions: ['atak:display', 'atak:input'],
    );
    return AtaProject(manifest: manifest, files: {'app.ata': _starterSource(pname)});
  }

  String _starterSource(String name) => '''
// $name —— 在 AtaKonitena 内置代码编辑器中创建
ata.heading("$name");
ata.show("这是你创建的第一个 Ata 应用。");

let name = ata.input("你叫什么名字？");
ata.show("你好，\${name}！");
''';

  /// 将项目打包成 .atak 字节流。
  Uint8List build(AtaProject project) {
    final entry = project.manifest.entry;
    final entrySource = project.files[entry];
    if (entrySource == null) {
      throw StateError('入口脚本 $entry 不存在，请先在项目中创建该文件。');
    }
    return buildAtakFromStrings(
      manifestJson: project.manifest.toJsonString(),
      entry: entry,
      entrySource: entrySource,
      extraTexts: project.extraTexts,
    );
  }

  /// 构建并安装到本机（覆盖同 id 已安装版本）。
  AtaManifest install(AtaProject project) {
    final bytes = build(project);
    AppServices.instance.installer.install(bytes);
    return project.manifest;
  }
}
