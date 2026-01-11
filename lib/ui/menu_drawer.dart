import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_strings.dart';
import '../state/locale_provider.dart';
import '../state/theme_provider.dart';

class MenuDrawer extends ConsumerWidget {
  const MenuDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.watch(localeProvider);
    final localeNotifier = ref.read(localeProvider.notifier);

    final currentTheme = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(AppStrings.get('appTitle', context)),
            accountEmail: Text(AppStrings.get('developedBy', context)),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.music_note, color: Colors.indigo),
            ),
            decoration: const BoxDecoration(color: Colors.indigo),
          ),

          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildSectionHeader(context, AppStrings.get('theme', context)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: SegmentedButton<ThemeMode>(
                    segments: [
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text(AppStrings.get('light', context)),
                        icon: const Icon(Icons.light_mode),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text(AppStrings.get('dark', context)),
                        icon: const Icon(Icons.dark_mode),
                      ),
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text(AppStrings.get('system', context)),
                        icon: const Icon(Icons.settings_system_daydream),
                      ),
                    ],
                    selected: {currentTheme},
                    onSelectionChanged: (Set<ThemeMode> newSelection) {
                      themeNotifier.setTheme(newSelection.first);
                    },
                    showSelectedIcon: false,
                  ),
                ),

                _buildSectionHeader(
                  context,
                  AppStrings.get('language', context),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: [
                      _LanguageChip(
                        label: 'English',
                        code: 'en',
                        selected: currentLocale.languageCode == 'en',
                        onTap: () =>
                            localeNotifier.setLocale(const Locale('en')),
                      ),
                      _LanguageChip(
                        label: 'Bahasa Indonesia',
                        code: 'id',
                        selected: currentLocale.languageCode == 'id',
                        onTap: () =>
                            localeNotifier.setLocale(const Locale('id')),
                      ),
                      _LanguageChip(
                        label: '中文',
                        code: 'zh',
                        selected: currentLocale.languageCode == 'zh',
                        onTap: () =>
                            localeNotifier.setLocale(const Locale('zh')),
                      ),
                      _LanguageChip(
                        label: '日本語',
                        code: 'ja',
                        selected: currentLocale.languageCode == 'ja',
                        onTap: () =>
                            localeNotifier.setLocale(const Locale('ja')),
                      ),
                      _LanguageChip(
                        label: '한국어',
                        code: 'ko',
                        selected: currentLocale.languageCode == 'ko',
                        onTap: () =>
                            localeNotifier.setLocale(const Locale('ko')),
                      ),
                      _LanguageChip(
                        label: 'العربية',
                        code: 'ar',
                        selected: currentLocale.languageCode == 'ar',
                        onTap: () =>
                            localeNotifier.setLocale(const Locale('ar')),
                      ),
                      _LanguageChip(
                        label: 'Русский',
                        code: 'ru',
                        selected: currentLocale.languageCode == 'ru',
                        onTap: () =>
                            localeNotifier.setLocale(const Locale('ru')),
                      ),
                      _LanguageChip(
                        label: 'हिन्दी',
                        code: 'hi',
                        selected: currentLocale.languageCode == 'hi',
                        onTap: () =>
                            localeNotifier.setLocale(const Locale('hi')),
                      ),
                    ],
                  ),
                ),
                const Divider(),

                _buildSectionHeader(
                  context,
                  AppStrings.get('donations', context),
                ),
                ListTile(
                  leading: const Icon(Icons.coffee, color: Colors.orange),
                  title: const Text("Trakteer.id"),
                  subtitle: Text(
                    "${AppStrings.get('supportMe', context)} Trakteer",
                  ),
                  onTap: () => _launch("https://trakteer.id/Ian7672"),
                ),
                ListTile(
                  leading: const Icon(Icons.coffee_maker, color: Colors.blue),
                  title: const Text("Ko-fi"),
                  subtitle: Text(
                    "${AppStrings.get('supportMe', context)} Ko-fi",
                  ),
                  onTap: () => _launch("https://ko-fi.com/Ian7672"),
                ),

                const Divider(),

                _buildSectionHeader(
                  context,
                  AppStrings.get('credits', context),
                ),
                ListTile(
                  leading: const Icon(Icons.code),
                  title: const Text("Ian7672"),
                  subtitle: Text(AppStrings.get('visitGithub', context)),
                  onTap: () => _launch("https://github.com/Ian7672"),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("v1.0.0", style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).primaryColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint("Could not launch $url");
    }
  }
}

class _LanguageChip extends StatelessWidget {
  final String label;
  final String code;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageChip({
    required this.label,
    required this.code,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: true,
    );
  }
}
