/// 应用级服务聚合：持有存储、安装器与容器管理器。
library;

import 'data/atak_store.dart';
import 'core/atak/atak_storage.dart';
import 'core/atak/atak_installer.dart';
import 'core/container/container_manager.dart';
import 'features/editor/project_service.dart';

/// 全局服务单例（App 启动时初始化）。
class AppServices {
  static AppServices? _instance;
  static AppServices get instance => _instance!;
  static bool get isInitialized => _instance != null;

  final AtakStore store;
  final AtakStorage storage;
  final AtakInstaller installer;
  final ContainerManager containerManager;
  final ProjectService projects;

  AppServices._(this.store)
      : storage = AtakStorage(store),
        installer = AtakInstaller(AtakStorage(store)),
        containerManager = ContainerManager(AtakStorage(store)),
        projects = ProjectService(store) {
    _instance = this;
  }

  static Future<AppServices> create() async {
    final store = await createAtakStore();
    final services = AppServices._(store);
    await services.storage.init();
    return services;
  }
}