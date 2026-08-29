/// 平台无关的本地路径读取入口。Web 端恒返回 null（改用 file_picker 的 bytes）。
library;

export 'path_reader_io.dart'
    if (dart.library.js_interop) 'path_reader_stub.dart';