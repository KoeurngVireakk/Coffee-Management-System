import 'package:flutter/material.dart';

import 'features/preview/presentation/design_system_preview_page.dart';
import 'shared/theme/app_theme.dart';

/// Root application widget for the Coffee Management System mobile & tablet client.
class CoffeeManagementApp extends StatefulWidget {
  const CoffeeManagementApp({
    super.key,
    this.initialThemeMode = ThemeMode.light,
  });

  final ThemeMode initialThemeMode;

  @override
  State<CoffeeManagementApp> createState() => _CoffeeManagementAppState();
}

class _CoffeeManagementAppState extends State<CoffeeManagementApp> {
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.initialThemeMode;
  }

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light
          ? ThemeMode.dark
          : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Coffee Management System',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.buildLightTheme(),
      darkTheme: AppTheme.buildDarkTheme(),
      themeMode: _themeMode,
      home: DesignSystemPreviewPage(
        themeMode: _themeMode,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}
