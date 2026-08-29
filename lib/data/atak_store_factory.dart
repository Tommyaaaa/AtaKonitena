/// AtakStore 工厂：编译期依据平台选择实现。
library;

import 'atak_store.dart' show AtakStore;
import 'atak_store_io.dart'
    if (dart.library.html) 'atak_store_web.dart' as impl;

/// 创建平台对应的 AtakStore。
Future<AtakStore> createAtakStore() => impl.createDefault();