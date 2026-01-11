import 'package:uuid/uuid.dart';

enum JobStatus { queued, running, success, failed, cancelled }

class Job {
  final String id;
  final String inputPath;
  final String? outputPath;
  final JobStatus status;
  final double progress; // 0.0 to 1.0
  final String? error;
  final String log;

  Job({
    required this.id,
    required this.inputPath,
    this.outputPath,
    this.status = JobStatus.queued,
    this.progress = 0.0,
    this.error,
    this.log = '',
  });

  factory Job.create(String inputPath) {
    return Job(id: const Uuid().v4(), inputPath: inputPath);
  }

  Job copyWith({
    String? outputPath,
    JobStatus? status,
    double? progress,
    String? error,
    String? log,
  }) {
    return Job(
      id: id,
      inputPath: inputPath,
      outputPath: outputPath ?? this.outputPath,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      error: error ?? this.error,
      log:
          log ??
          this.log, // Accumulate logs? Or replace? Usually replace for immutable copy, but logic handles accumulation
    );
  }
}
