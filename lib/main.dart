import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'ui/home_page.dart';

void main() {
  runApp(const TerLogoApp());
}

class TerLogoApp extends StatefulWidget {
  const TerLogoApp({super.key});

  @override
  State<TerLogoApp> createState() => _TerLogoAppState();
}

class _TerLogoAppState extends State<TerLogoApp> {
  final themeMode = ValueNotifier(ThemeMode.system);

  ThemeData _theme(Brightness b) {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32), brightness: b);
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      visualDensity: VisualDensity.compact,
      tooltipTheme: const TooltipThemeData(waitDuration: Duration(milliseconds: 500)),
      sliderTheme: const SliderThemeData(showValueIndicator: ShowValueIndicator.never),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: themeMode,
      builder: (context, mode, _) => MaterialApp(
        title: 'TER Logo Reboot',
        debugShowCheckedModeBanner: false,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        themeMode: mode,
        locale: const Locale('fr'),
        supportedLocales: const [Locale('fr')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: HomePage(themeMode: themeMode),
      ),
    );
  }
}
