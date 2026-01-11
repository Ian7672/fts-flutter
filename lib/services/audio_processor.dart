import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:ffmpeg_kit_flutter_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_audio/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_audio/return_code.dart';
import 'package:ffmpeg_kit_flutter_audio/session.dart';
import 'package:flutter/foundation.dart';

class AudioProcessor {
  Future<double?> getDuration(String filePath, {String? ffmpegPath}) async {
    // 1. Try external ffprobe if ffmpegPath is provided
    if (ffmpegPath != null &&
        ffmpegPath.isNotEmpty &&
        File(ffmpegPath).existsSync()) {
      // Assume ffprobe is next to ffmpeg
      final ffprobePath = ffmpegPath.replaceAll("ffmpeg.exe", "ffprobe.exe");
      if (File(ffprobePath).existsSync()) {
        try {
          // ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 input.mp3
          final result = await Process.run(ffprobePath, [
            "-v",
            "error",
            "-show_entries",
            "format=duration",
            "-of",
            "default=noprint_wrappers=1:nokey=1",
            filePath,
          ]);
          if (result.exitCode == 0) {
            final dur = double.tryParse(result.stdout.toString().trim());
            if (dur != null) return dur;
          }
        } catch (e) {
          debugPrint("External ffprobe failed: $e");
        }
      }
    }

    // 2. Fallback to FFprobeKit (might fail on Windows if plugin is broken)
    try {
      final session = await FFprobeKit.getMediaInformation(filePath);
      final info = session.getMediaInformation();
      if (info == null) {
        debugPrint("FFprobe info is null for $filePath");
        return null;
      }
      final durationStr = info.getDuration();
      if (durationStr == null) return null;
      return double.tryParse(durationStr);
    } catch (e) {
      debugPrint("FFprobeKit failed: $e");
      return null;
    }
  }

  List<String> buildCommandArgs({
    required String inputPath,
    required String outputPath,
    required double duration,
    required double fadeTailSeconds,
    required double silenceLastSeconds,
  }) {
    final double startFade = max(0, duration - fadeTailSeconds);
    final double silenceStart = max(0, duration - silenceLastSeconds);
    final double fadeDur = max(0, silenceStart - startFade);

    String filter;
    if (duration <= silenceLastSeconds) {
      filter = "volume=0";
    } else if (fadeDur > 0) {
      filter =
          "afade=t=out:st=${startFade.toStringAsFixed(3)}:d=${fadeDur.toStringAsFixed(3)},volume=0:enable='gte(t,${silenceStart.toStringAsFixed(3)})'";
    } else {
      filter = "volume=0:enable='gte(t,${silenceStart.toStringAsFixed(3)})'";
    }

    return ["-y", "-i", inputPath, "-af", filter, "-map", "0:a:0", outputPath];
  }

  Future<void> processAudio({
    required String inputPath,
    required String outputPath,
    required double fadeTailSeconds,
    required double silenceLastSeconds,
    String? ffmpegPath,
    required Function(String log) onLog,
    required Function(double progress) onProgress,
    required Function(bool success, String? error) onComplete,
    required Function(int sessionId) onSessionStart,
  }) async {
    // 1. Get Duration
    onLog("Analysing duration for: $inputPath");
    final duration = await getDuration(inputPath, ffmpegPath: ffmpegPath);
    if (duration == null) {
      onComplete(false, "Could not determine duration. (FFprobe failed)");
      return;
    }
    onLog("Duration: ${duration}s");

    // 2. Build Args
    final args = buildCommandArgs(
      inputPath: inputPath,
      outputPath: outputPath,
      duration: duration,
      fadeTailSeconds: fadeTailSeconds,
      silenceLastSeconds: silenceLastSeconds,
    );

    onLog("Command args: $args");

    // 3. Execute
    if (ffmpegPath != null &&
        ffmpegPath.isNotEmpty &&
        File(ffmpegPath).existsSync()) {
      // --- External Execution ---
      onLog("Using external FFmpeg: $ffmpegPath");
      try {
        final process = await Process.start(ffmpegPath, args);

        // Placeholder session ID for external process
        // onSessionStart(-process.pid);

        // Parse stderr for progress
        process.stderr.transform(utf8.decoder).listen((data) {
          // onLog(data);
          final regex = RegExp(r"time=(\d{2}:\d{2}:\d{2}\.\d{2})");
          final match = regex.firstMatch(data);
          if (match != null) {
            final timeStr = match.group(1)!;
            final parts = timeStr.split(':');
            try {
              final seconds =
                  double.parse(parts[0]) * 3600 +
                  double.parse(parts[1]) * 60 +
                  double.parse(parts[2]);
              if (duration > 0) {
                onProgress((seconds / duration).clamp(0.0, 1.0));
              }
            } catch (_) {}
          }
        });

        int exitCode = await process.exitCode;
        if (exitCode == 0) {
          onComplete(true, null);
        } else {
          onComplete(false, "External FFmpeg failed with exit code $exitCode");
        }
      } catch (e) {
        onComplete(false, "Failed to start external FFmpeg: $e");
      }
    } else {
      // --- Library Execution ---
      if (ffmpegPath != null && ffmpegPath.isNotEmpty) {
        onLog("External FFmpeg path invalid, falling back to built-in.");
      }

      FFmpegKit.executeWithArgumentsAsync(
        args,
        (Session session) async {
          final returnCode = await session.getReturnCode();

          if (ReturnCode.isSuccess(returnCode)) {
            onComplete(true, null);
          } else if (ReturnCode.isCancel(returnCode)) {
            onComplete(false, "Cancelled");
          } else {
            final failLog = await session.getAllLogsAsString();
            onComplete(
              false,
              "Failed (RC ${returnCode?.getValue()}): $failLog",
            );
          }
        },
        (log) {
          // onLog(log.getMessage());
        },
        (statistics) {
          final time = statistics.getTime();
          if (duration > 0) {
            double p = time / (duration * 1000.0);
            onProgress(p.clamp(0.0, 1.0));
          }
        },
      ).then((session) {
        final sid = session.getSessionId();
        if (sid != null) {
          onSessionStart(sid);
        }
      });
    }
  }

  Future<void> cancelSession(int sessionId) async {
    if (sessionId >= 0) {
      await FFmpegKit.cancel(sessionId);
    }
  }
}
