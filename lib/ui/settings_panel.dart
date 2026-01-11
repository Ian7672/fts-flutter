import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/jobs_provider.dart';
import '../l10n/app_strings.dart';

class SettingsPanel extends ConsumerWidget {
  const SettingsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(jobsProvider);
    final notifier = ref.read(jobsProvider.notifier);

    return Card(
      elevation: 0,
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.get('settings', context),
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _NumberInput(
                    label: AppStrings.get('fadeTail', context),
                    value: state.defaultFadeSeconds,
                    onChanged: (val) => notifier.setFadeSeconds(val),
                    min: 0,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _NumberInput(
                    label: AppStrings.get('silenceLast', context),
                    value: state.defaultSilenceSeconds,
                    onChanged: (val) => notifier.setSilenceSeconds(val),
                    min: 0,
                    error:
                        state.defaultSilenceSeconds >= state.defaultFadeSeconds
                        ? "Must be < Fade"
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: AppStrings.get('outputFormat', context),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    value: state.outputFormat,
                    items: [
                      DropdownMenuItem(
                        value: "Same as input",
                        child: Text(AppStrings.get('sameAsInput', context)),
                      ),
                      const DropdownMenuItem(value: "mp3", child: Text("MP3")),
                      const DropdownMenuItem(
                        value: "m4a",
                        child: Text("M4A (AAC)"),
                      ),
                      const DropdownMenuItem(value: "wav", child: Text("WAV")),
                    ],
                    onChanged: (val) {
                      if (val != null) notifier.setOutputFormat(val);
                    },
                  ),
                ),
              ],
            ),
            if (state.defaultSilenceSeconds >= state.defaultFadeSeconds)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  "Error: Silence duration must be strictly less than Fade duration.",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),

            const SizedBox(height: 8),

            // Advanced Settings Expansion
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: Text(
                  AppStrings.get('advancedSettings', context),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                children: [
                  const Divider(),
                  const SizedBox(height: 8),
                  // Parallel Switch
                  SwitchListTile(
                    title: Text(AppStrings.get('parallelProcessing', context)),
                    subtitle: Text(AppStrings.get('parallelSubtitle', context)),
                    value: state.isParallel,
                    onChanged: (val) => notifier.setParallel(val),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),
                  // custom FFmpeg Path
                  TextFormField(
                    initialValue: state.ffmpegPath,
                    decoration: InputDecoration(
                      labelText: AppStrings.get('customFfmpeg', context),
                      hintText: AppStrings.get('ffmpegHint', context),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (val) => notifier.setFfmpegPath(val),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Note: If path is valid, app uses external executable. Otherwise falls back to built-in library.",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberInput extends StatefulWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final String? error;

  const _NumberInput({
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0.0,
    this.error,
  });

  @override
  State<_NumberInput> createState() => _NumberInputState();
}

class _NumberInputState extends State<_NumberInput> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toStringAsFixed(1));
  }

  @override
  void didUpdateWidget(covariant _NumberInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      if (double.tryParse(_controller.text) != widget.value) {
        _controller.text = widget.value.toStringAsFixed(1);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
        errorText: widget.error,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      onChanged: (val) {
        final d = double.tryParse(val);
        if (d != null && d >= widget.min) {
          widget.onChanged(d);
        }
      },
    );
  }
}
