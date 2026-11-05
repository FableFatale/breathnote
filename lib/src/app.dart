import 'package:flutter/material.dart';

import 'screens/home_shell.dart';
import 'theme/app_theme.dart';

class BreathnoteApp extends StatelessWidget {
  const BreathnoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '息音',
      theme: AppTheme.dark,
      home: const HomeShell(),
    );
  }
}
