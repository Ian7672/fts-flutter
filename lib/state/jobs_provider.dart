import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pool/pool.dart'; // Add pool dependency

import '../models/job.dart';
import '../services/audio_processor.dart';

// --- Providers ---

final audioProcessorProvider = Provider((ref) => AudioProcessor());

final jobsProvider = NotifierProvider<JobsNotifier, JobsState>(
  JobsNotifier.new,
);

// --- State Class ---

class JobsState {
  final List<Job> jobs;
  final bool isProcessing;
  final double defaultFadeSeconds;
  final double defaultSilenceSeconds;
  final String? outputFolder;
  final String outputFormat; // "Same as input", "mp3", "m4a", "wav"
  final String? ffmpegPath;
  final bool isParallel;

  JobsState({
    this.jobs = const [],
    this.isProcessing = false,
    this.defaultFadeSeconds = 9.0,
    this.defaultSilenceSeconds = 2.0,
    this.outputFolder,
    this.outputFormat = "Same as input",
    this.ffmpegPath = "D:\\mylib\\ffmpeg-8.0.1-full_build\\bin\\ffmpeg.exe",
    this.isParallel = true,
  });

  JobsState copyWith({
    List<Job>? jobs,
    bool? isProcessing,
    double? defaultFadeSeconds,
    double? defaultSilenceSeconds,
    String? outputFolder,
    String? outputFormat,
    String? ffmpegPath,
    bool? isParallel,
  }) {
    return JobsState(
      jobs: jobs ?? this.jobs,
      isProcessing: isProcessing ?? this.isProcessing,
      defaultFadeSeconds: defaultFadeSeconds ?? this.defaultFadeSeconds,
      defaultSilenceSeconds:
          defaultSilenceSeconds ?? this.defaultSilenceSeconds,
      outputFolder: outputFolder ?? this.outputFolder,
      outputFormat: outputFormat ?? this.outputFormat,
      ffmpegPath: ffmpegPath ?? this.ffmpegPath,
      isParallel: isParallel ?? this.isParallel,
    );
  }
}

// --- Notifier ---

class JobsNotifier extends Notifier<JobsState> {
  late final AudioProcessor _processor;
  final Map<String, int> _activeSessions = {}; // JobID -> SessionID

  @override
  JobsState build() {
    _processor = ref.watch(audioProcessorProvider);
    return JobsState();
  }

  void setOutputFolder(String path) {
    state = state.copyWith(outputFolder: path);
  }

  void setFadeSeconds(double seconds) {
    state = state.copyWith(defaultFadeSeconds: seconds);
  }

  void setSilenceSeconds(double seconds) {
    state = state.copyWith(defaultSilenceSeconds: seconds);
  }

  void setOutputFormat(String format) {
    state = state.copyWith(outputFormat: format);
  }

  void setFfmpegPath(String path) {
    state = state.copyWith(ffmpegPath: path);
  }

  void setParallel(bool parallel) {
    state = state.copyWith(isParallel: parallel);
  }

  void addFiles(List<String> paths) {
    final newJobs = paths.map((path) => Job.create(path)).toList();
    state = state.copyWith(jobs: [...state.jobs, ...newJobs]);
  }

  void removeJob(String jobId) {
    state = state.copyWith(
      jobs: state.jobs.where((j) => j.id != jobId).toList(),
    );
  }

  void clearCompleted() {
    state = state.copyWith(
      jobs: state.jobs
          .where(
            (j) =>
                j.status == JobStatus.queued || j.status == JobStatus.running,
          )
          .toList(),
    );
  }

  void clearAll() {
    if (state.isProcessing) return;
    state = state.copyWith(jobs: []);
  }

  Future<void> startProcessing() async {
    if (state.isProcessing) return;
    state = state.copyWith(isProcessing: true);

    // Limit concurrency for "parallel" execution to avoid thrashing
    final pool = Pool(state.isParallel ? 4 : 1);

    final jobsToProcess = state.jobs
        .where(
          (j) => j.status == JobStatus.queued || j.status == JobStatus.failed,
        )
        .toList(); // Process queued or failed.

    final futures = <Future>[];

    for (var job in jobsToProcess) {
      if (!state.isProcessing) break;

      final future = pool.withResource(() async {
        if (!state.isProcessing) return;
        await _runJobSafely(job);
      });
      futures.add(future);
    }

    // Wait for all spawned tasks to complete
    await Future.wait(futures);

    state = state.copyWith(isProcessing: false);
  }

  Future<void> _runJobSafely(Job job) async {
    // Check if job exists in current state (might be cleared/removed)
    // We can't easily rely on index, so find by ID.
    if (!state.jobs.any((j) => j.id == job.id)) return;

    _updateJob(job.id, status: JobStatus.running, progress: 0.0);

    try {
      final outDirBase =
          state.outputFolder ?? (await _getDefaultOutputFolder(job.inputPath));
      // Create subfolder "FadeTail_Output"
      final outDir = Directory(p.join(outDirBase, "FadeTail_Output"));
      if (!outDir.existsSync()) {
        await outDir.create(recursive: true);
      }

      final String inputExt = p.extension(job.inputPath);
      final String basename = p.basenameWithoutExtension(job.inputPath);

      String outputExt = inputExt;
      if (state.outputFormat != "Same as input") {
        outputExt = ".${state.outputFormat}";
      }

      final String outPath = p.join(
        outDir.path,
        "${basename}_fade_tail$outputExt",
      );

      await _processSingleJob(job.id, job.inputPath, outPath);
    } catch (e) {
      _updateJob(job.id, status: JobStatus.failed, error: e.toString());
    }
  }

  Future<void> stopProcessing() async {
    state = state.copyWith(isProcessing: false);
    for (var sessionId in _activeSessions.values) {
      await _processor.cancelSession(sessionId);
    }
    _activeSessions.clear();
  }

  Future<String> _getDefaultOutputFolder(String inputPath) async {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return p.dirname(inputPath);
    } else {
      final directory = await getApplicationDocumentsDirectory();
      return directory.path;
    }
  }

  Future<void> _processSingleJob(
    String jobId,
    String input,
    String output,
  ) async {
    await _processor.processAudio(
      inputPath: input,
      outputPath: output,
      fadeTailSeconds: state.defaultFadeSeconds,
      silenceLastSeconds: state.defaultSilenceSeconds,
      ffmpegPath: state.ffmpegPath,
      onLog: (log) {},
      onProgress: (prog) {
        _updateJob(jobId, progress: prog);
      },
      onComplete: (success, error) {
        _activeSessions.remove(jobId);
        _updateJob(
          jobId,
          status: success ? JobStatus.success : JobStatus.failed,
          progress: success ? 1.0 : 0.0,
          error: error,
          outputPath: success ? output : null,
        );
      },
      onSessionStart: (sid) {
        _activeSessions[jobId] = sid;
      },
    );
  }

  void _updateJob(
    String id, {
    JobStatus? status,
    double? progress,
    String? error,
    String? outputPath,
  }) {
    if (!state.jobs.any((j) => j.id == id)) return;
    state = state.copyWith(
      jobs: state.jobs.map((j) {
        if (j.id == id) {
          return j.copyWith(
            status: status,
            progress: progress,
            error: error,
            outputPath: outputPath,
          );
        }
        return j;
      }).toList(),
    );
  }
}
