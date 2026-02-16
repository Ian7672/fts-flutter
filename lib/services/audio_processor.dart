import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:ffmpeg_kit_audio_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_audio_flutter/ffprobe_kit.dart';
import 'package:ffmpeg_kit_audio_flutter/return_code.dart';
import 'package:ffmpeg_kit_audio_flutter/session.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class AudioMetadata {
  final double duration;
  final int? sampleRate;
  final int? bitRate;
  final int? channels;
  final String? codecName;

  const AudioMetadata({
    required this.duration,
    this.sampleRate,
    this.bitRate,
    this.channels,
    this.codecName,
  });

  bool get hasSampleRate => sampleRate != null;
  bool get hasBitRate => bitRate != null;
  bool get hasChannels => channels != null;
  bool get hasCodec => codecName != null && codecName!.isNotEmpty;
}

class AudioProcessor {
  Future<AudioMetadata?> getMetadata(String filePath, {String? ffmpegPath}) async {
    final metadata = await _probeWithExternal(filePath, ffmpegPath: ffmpegPath);
    if (metadata != null) {
      return metadata;
    }

    try {
      final session = await FFprobeKit.getMediaInformation(filePath);
      final info = session.getMediaInformation();
      if (info == null) {
        debugPrint("FFprobe info is null for $filePath");
        return null;
      }

      final durationStr = info.getDuration();
      final duration = double.tryParse(durationStr ?? "");
      if (duration == null) {
        debugPrint("FFprobeKit did not return duration for $filePath");
        return null;
      }

      final streams = info.getStreams();
      dynamic audioStream;
      for (final stream in streams) {
        if (stream.getType() == "audio") {
          audioStream = stream;
          break;
        }
      }

      final sampleRate = _parseToInt(audioStream?.getSampleRate());
      final bitRate =
          _parseToInt(audioStream?.getBitrate() ?? info.getBitrate());
      final channels = _parseToInt(audioStream?.getProperty("channels"));
      final codecName = audioStream?.getCodec();

      return AudioMetadata(
        duration: duration,
        sampleRate: sampleRate,
        bitRate: bitRate,
        channels: channels,
        codecName: codecName,
      );
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
    AudioMetadata? metadata,
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

    final args = ["-y", "-i", inputPath, "-af", filter, "-map", "0:a:0"];

    if (metadata != null) {
      args.addAll(
        _buildPreservationArgs(
          metadata,
          inputPath: inputPath,
          outputPath: outputPath,
        ),
      );
    }

    args.add(outputPath);
    return args;
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
    final metadata = await getMetadata(inputPath, ffmpegPath: ffmpegPath);
    if (metadata == null) {
      onComplete(false, "Could not determine duration. (FFprobe failed)");
      return;
    }
    final duration = metadata.duration;
    onLog(
      "Duration: ${duration}s, sampleRate: ${metadata.sampleRate ?? 'unknown'}, bitrate: ${metadata.bitRate ?? 'unknown'}",
    );

    // 2. Build Args
    final args = buildCommandArgs(
      inputPath: inputPath,
      outputPath: outputPath,
      duration: duration,
      fadeTailSeconds: fadeTailSeconds,
      silenceLastSeconds: silenceLastSeconds,
      metadata: metadata,
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

  Future<AudioMetadata?> _probeWithExternal(
    String filePath, {
    String? ffmpegPath,
  }) async {
    if (ffmpegPath == null || ffmpegPath.isEmpty) return null;
    final ffmpegFile = File(ffmpegPath);
    if (!ffmpegFile.existsSync()) return null;

    final ffprobePath = _findFfprobePath(ffmpegFile);
    if (ffprobePath == null) return null;

    try {
      final result = await Process.run(ffprobePath, [
        "-v",
        "error",
        "-print_format",
        "json",
        "-show_streams",
        "-show_format",
        filePath,
      ]);

      if (result.exitCode != 0) {
        debugPrint("External ffprobe failed: ${result.stderr}");
        return null;
      }

      final root = jsonDecode(result.stdout.toString());
      if (root is! Map) return null;

      final format = root["format"] is Map
          ? Map<String, dynamic>.from(root["format"])
          : <String, dynamic>{};
      final streams = root["streams"] is List ? root["streams"] as List : const [];

      Map<String, dynamic>? audioStream;
      for (final raw in streams) {
        if (raw is Map && raw["codec_type"] == "audio") {
          audioStream = Map<String, dynamic>.from(raw);
          break;
        }
      }

      final duration = double.tryParse(format["duration"]?.toString() ?? "");
      if (duration == null) return null;

      final sampleRate = _parseToInt(audioStream?["sample_rate"]);
      final bitRate =
          _parseToInt(audioStream?["bit_rate"] ?? format["bit_rate"]);
      final channels = _parseToInt(audioStream?["channels"]);
      final codecName = audioStream?["codec_name"]?.toString();

      return AudioMetadata(
        duration: duration,
        sampleRate: sampleRate,
        bitRate: bitRate,
        channels: channels,
        codecName: codecName,
      );
    } catch (e) {
      debugPrint("External ffprobe parse failed: $e");
      return null;
    }
  }

  String? _findFfprobePath(File ffmpegFile) {
    final ffmpegDir = ffmpegFile.parent.path;
    final candidates = <String>[
      p.join(ffmpegDir, "ffprobe${Platform.isWindows ? '.exe' : ''}"),
      p.join(ffmpegDir, "ffprobe.exe"),
      p.join(ffmpegDir, "ffprobe"),
    ];

    for (final path in candidates) {
      if (File(path).existsSync()) {
        return path;
      }
    }
    return null;
  }

  List<String> _buildPreservationArgs(
    AudioMetadata metadata, {
    required String inputPath,
    required String outputPath,
  }) {
    final args = <String>[];

    if (metadata.sampleRate != null && metadata.sampleRate! > 0) {
      args.addAll(["-ar", metadata.sampleRate!.toString()]);
    }
    if (metadata.channels != null && metadata.channels! > 0) {
      args.addAll(["-ac", metadata.channels!.toString()]);
    }

    if (_shouldApplyBitrate(metadata, outputPath)) {
      args.addAll(["-b:a", metadata.bitRate!.toString()]);
    }

    final codec = _codecForOutput(metadata, inputPath, outputPath);
    if (codec != null) {
      args.addAll(["-c:a", codec]);
    }

    return args;
  }

  String? _codecForOutput(
    AudioMetadata metadata,
    String inputPath,
    String outputPath,
  ) {
    if (!metadata.hasCodec) return null;
    final inputExt = p.extension(inputPath).toLowerCase();
    final outputExt = p.extension(outputPath).toLowerCase();
    if (inputExt == outputExt || outputExt.isEmpty) {
      return metadata.codecName;
    }
    return null;
  }

  bool _shouldApplyBitrate(AudioMetadata metadata, String outputPath) {
    if (!metadata.hasBitRate) return false;
    if (_isLosslessCodec(metadata.codecName, outputPath)) {
      return false;
    }
    return true;
  }

  bool _isLosslessCodec(String? codecName, String outputPath) {
    final codec = codecName?.toLowerCase() ?? "";
    if (codec.startsWith("pcm_") ||
        codec.contains("flac") ||
        codec.contains("alac")) {
      return true;
    }
    final ext = p.extension(outputPath).toLowerCase();
    const losslessExts = {".wav", ".aif", ".aiff", ".flac"};
    return losslessExts.contains(ext);
  }

  int? _parseToInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.tryParse(value.split(".").first);
    }
    return null;
  }
}
