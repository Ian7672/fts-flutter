import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../models/job.dart';
import '../l10n/app_strings.dart';

class FileListView extends StatelessWidget {
  final List<Job> jobs;
  final Function(String) onRemove;

  const FileListView({super.key, required this.jobs, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: jobs.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final job = jobs[index];
        return JobTile(job: job, onRemove: () => onRemove(job.id));
      },
    );
  }
}

class JobTile extends StatelessWidget {
  final Job job;
  final VoidCallback onRemove;

  const JobTile({super.key, required this.job, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final fileName = p.basename(job.inputPath);

    IconData statusIcon;
    Color statusColor;

    switch (job.status) {
      case JobStatus.queued:
        statusIcon = Icons.hourglass_empty;
        statusColor = Colors.grey;
        break;
      case JobStatus.running:
        statusIcon = Icons.refresh;
        statusColor = Colors.blue;
        break;
      case JobStatus.success:
        statusIcon = Icons.check_circle;
        statusColor = Colors.green;
        break;
      case JobStatus.failed:
        statusIcon = Icons.error;
        statusColor = Colors.red;
        break;
      case JobStatus.cancelled:
        statusIcon = Icons.cancel;
        statusColor = Colors.orange;
        break;
    }

    // Localize status text
    String statusText = AppStrings.get(job.status.name, context);

    return Dismissible(
      key: Key(job.id),
      direction: job.status == JobStatus.running
          ? DismissDirection.none
          : DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: ListTile(
        leading: Icon(
          Icons.audio_file,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (job.status == JobStatus.running)
              LinearProgressIndicator(value: job.progress, minHeight: 4),

            const SizedBox(height: 4),
            Row(
              children: [
                Icon(statusIcon, size: 14, color: statusColor),
                const SizedBox(width: 4),
                Text(
                  statusText,
                  style: TextStyle(color: statusColor, fontSize: 12),
                ),
                if (job.status == JobStatus.failed && job.error != null)
                  Expanded(
                    child: Text(
                      ": ${job.error}",
                      style: TextStyle(color: statusColor, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ],
        ),
        trailing: job.status != JobStatus.running
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: onRemove,
                tooltip: AppStrings.get('removeFile', context),
              )
            : null,
      ),
    );
  }
}
