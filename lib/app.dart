/// AtaKonitena 根组件：主题 + 主框架。
library;

import 'package:flutter/material.dart';
import 'ui/theme.dart';
import 'ui/home_shell.dart';

class AtaKonitenaApp extends StatelessWidget {
  const AtaKonitenaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AtaKonitena',
      debugShowCheckedModeBanner: false,
      theme: AtaTheme.dark(),
      home: const HomeShell(),
    );
  }
}