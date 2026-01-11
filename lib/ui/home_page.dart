import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/jobs_provider.dart';
import 'file_list_view.dart';
import 'settings_panel.dart';
import '../l10n/app_strings.dart';
import 'menu_drawer.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsState = ref.watch(jobsProvider);
    final notifier = ref.read(jobsProvider.notifier);

    final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

    return Scaffold(
      key: scaffoldKey,
      appBar: AppBar(
        title: Text(AppStrings.get('appTitle', context)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: AppStrings.get('helpTooltip', context),
            onPressed: () => _showHelpDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              scaffoldKey.currentState?.openEndDrawer();
            },
            tooltip: AppStrings.get('menu', context),
          ),
        ],
      ),
      endDrawer: const MenuDrawer(),
      body: DropTarget(
        onDragDone: (details) {
          final paths = details.files.map((e) => e.path).toList();
          notifier.addFiles(paths);
        },
        onDragEntered: (details) {},
        onDragExited: (details) {},
        child: Column(
          children: [
            // Settings Area
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SettingsPanel(),
            ),

            const Divider(height: 1),

            if (jobsState.jobs.isNotEmpty) ...[
              const SizedBox(height: 20),
              // File List Area
              Expanded(
                child: FileListView(
                  jobs: jobsState.jobs,
                  onRemove: notifier.removeJob,
                ),
              ),

              const SizedBox(height: 20),

              // Actions
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: jobsState.isProcessing
                            ? null
                            : () => notifier.startProcessing(),
                        icon: jobsState.isProcessing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.play_arrow),
                        label: Text(
                          jobsState.isProcessing
                              ? AppStrings.get('processing', context)
                              : AppStrings.get('processAll', context),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    if (jobsState.isProcessing) ...[
                      const SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => notifier.stopProcessing(),
                          icon: const Icon(Icons.stop),
                          label: Text(AppStrings.get('cancel', context)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            if (jobsState.jobs.isEmpty)
              Expanded(
                child: Center(
                  child: IgnorePointer(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.audio_file,
                          size: 64,
                          color: Theme.of(context).disabledColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          AppStrings.get('dragDrop', context),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: Theme.of(context).disabledColor,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () {},
                          label: Text(AppStrings.get('addFiles', context)),
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: jobsState.jobs.isNotEmpty && !jobsState.isProcessing
          ? FloatingActionButton(
              onPressed: () async {
                FilePickerResult? result = await FilePicker.platform.pickFiles(
                  allowMultiple: true,
                  type: FileType.audio,
                );

                if (result != null) {
                  List<String> paths = result.paths
                      .where((path) => path != null)
                      .cast<String>()
                      .toList();
                  notifier.addFiles(paths);
                }
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(AppStrings.get('helpDialogTitle', dialogContext)),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppStrings.get('helpDialogIntro', dialogContext)),
                  const SizedBox(height: 16),
                  _HelpSection(
                    title: AppStrings.get('settings', dialogContext),
                    body: AppStrings.get('helpSettingsDesc', dialogContext),
                  ),
                  _HelpSection(
                    title: AppStrings.get('advancedSettings', dialogContext),
                    body: AppStrings.get('helpAdvancedDesc', dialogContext),
                  ),
                  _HelpSection(
                    title: AppStrings.get('processAll', dialogContext),
                    body: AppStrings.get('helpProcessingDesc', dialogContext),
                  ),
                  _HelpSection(
                    title: AppStrings.get('menu', dialogContext),
                    body: AppStrings.get('helpMenuDesc', dialogContext),
                  ),
                  _HelpSection(
                    title: AppStrings.get('theme', dialogContext),
                    body: AppStrings.get('helpThemeDesc', dialogContext),
                  ),
                  _HelpSection(
                    title: AppStrings.get('language', dialogContext),
                    body: AppStrings.get('helpLanguageDesc', dialogContext),
                  ),
                  _HelpSection(
                    title: AppStrings.get('donations', dialogContext),
                    body: AppStrings.get('helpDonationsDesc', dialogContext),
                  ),
                  _HelpSection(
                    title: AppStrings.get('credits', dialogContext),
                    body: AppStrings.get('helpCreditsDesc', dialogContext),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                MaterialLocalizations.of(dialogContext).closeButtonLabel,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HelpSection extends StatelessWidget {
  final String title;
  final String body;

  const _HelpSection({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
