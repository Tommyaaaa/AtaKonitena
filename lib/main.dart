/// AtaKonitena 入口。
library;

import 'package:flutter/material.dart';
import 'app_services.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppServices.create();
  runApp(const AtaKonitenaApp());
}