import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'state/locale_provider.dart';
import 'state/theme_provider.dart';
import 'ui/home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: FadeTailApp()));
}

class FadeTailApp extends ConsumerWidget {
  const FadeTailApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: 'FadeTail',
      theme: ThemeData(
        brightness: Brightness.light,
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      themeMode: themeMode,
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: const [
        Locale('en'),
        Locale('id'),
        Locale('zh'),
        Locale('ja'),
        Locale('ko'),
        Locale('ar'),
        Locale('ru'),
        Locale('hi'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
