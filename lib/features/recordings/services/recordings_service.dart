import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:hive/hive.dart'; // Import Hive
import 'package:intl/intl.dart'; // Ensure intl is imported for DateFormat
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/logger.dart';
import '../ui/recordings_page.dart';

part 'recordings_service.g.dart';

// Constants for buffer logic
const Duration _segmentDuration = Duration(seconds: 15);
const int _maxSegments = 2; // Keep last 2 segments for ~30 seconds

@riverpod
RecordingsService recordingsService(RecordingsServiceRef ref) {
  // Need access to the Hive box
  final box = Hive.box<Recording>('recordings');
  return RecordingsService(ref, box); // Pass box to constructor
}

/// Service responsible for managing the recording process (saving audio snippets).
class RecordingsService {
  final ProviderRef ref;
  final Box<Recording> _recordingsBox; // Store Hive box instance
  final FlutterSoundRecorder _fileRecorder = FlutterSoundRecorder();
  bool _isRecorderInitialized = false;

  // Track multiple segment files
  final List<String> _segmentPaths = [];
  Timer? _segmentSwitchTimer;

  // Define buffer duration (re-add)
  final Duration _bufferDuration = _segmentDuration * _maxSegments;

  RecordingsService(this.ref, this._recordingsBox) {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _fileRecorder.openRecorder();
      _isRecorderInitialized = true;
      logger.info('RecordingsService: File recorder initialized.');
    } catch (e, stack) {
      logger.error(
        'RecordingsService: Initialization failed',
        error: e,
        stackTrace: stack,
      );
    }
    // Don't start buffering automatically here anymore
    // if (_isAutoBufferingEnabled) { ... }
  }

  /// Generates a path for a new recording segment.
  Future<String> _generateSegmentPath() async {
    final tempDir = await getTemporaryDirectory();
    final recordingId = const Uuid().v4();
    return p.join(tempDir.path, 'segment_$recordingId.aac');
  }

  /// Starts recording a new audio segment.
  Future<void> _startNextSegment() async {
    if (!_isRecorderInitialized) {
      logger.warning('Cannot start segment: Recorder not initialized.');
      return;
    }
    if (_fileRecorder.isRecording) {
      logger.warning('Cannot start new segment: Recorder already active.');
      return; // Should not happen if timer logic is correct
    }

    try {
      final segmentPath = await _generateSegmentPath();
      await _fileRecorder.startRecorder(
        toFile: segmentPath,
        codec: Codec.aacADTS,
      );
      _segmentPaths.add(segmentPath);
      logger.info('RecordingsService: Started segment: $segmentPath');

      // Remove oldest segments if exceeding max count
      while (_segmentPaths.length > _maxSegments) {
        final oldSegmentPath = _segmentPaths.removeAt(0);
        try {
          final file = File(oldSegmentPath);
          if (await file.exists()) {
            await file.delete();
            logger.info(
              'RecordingsService: Deleted old segment: $oldSegmentPath',
            );
          }
        } catch (e) {
          logger.error(
            'RecordingsService: Failed to delete old segment $oldSegmentPath',
            error: e,
          );
        }
      }
    } catch (e, stack) {
      logger.error(
        'RecordingsService: Failed to start segment',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Starts or stops the continuous background audio buffering.
  Future<void> setAutoBufferingEnabled(bool enabled) async {
    logger.info("RecordingsService: Setting Auto Buffering to $enabled");
    if (enabled) {
      await startBuffering();
    } else {
      await stopBuffering();
    }
  }

  /// Starts recording the microphone input to temporary segment files.
  Future<void> startBuffering() async {
    if (!_isRecorderInitialized || _segmentSwitchTimer != null) {
      logger.info(
        "RecordingsService: startBuffering called but already buffering or not ready.",
      );
      return; // Already buffering or not ready
    }

    logger.info('RecordingsService: Starting continuous buffering...');
    await _stopCurrentRecording(); // Ensure any previous recording is stopped
    _segmentPaths.clear(); // Clear any old paths

    // Start the first segment immediately
    await _startNextSegment();

    // Start a periodic timer to switch segments
    _segmentSwitchTimer = Timer.periodic(_segmentDuration, (timer) async {
      logger.info('RecordingsService: Segment duration reached, switching...');
      await _stopCurrentRecording();
      await _startNextSegment();
    });
  }

  /// Stops the continuous buffering process.
  Future<void> stopBuffering() async {
    logger.info('RecordingsService: Stopping continuous buffering...');
    _segmentSwitchTimer?.cancel();
    _segmentSwitchTimer = null;
    await _stopCurrentRecording();
    // Don't change internal flag here
    // _isAutoBufferingEnabled = false;
    // await _deleteAllSegments(); // Keep segments until explicitly saved or overwritten
  }

  /// Helper to safely stop the current recording if active.
  Future<void> _stopCurrentRecording() async {
    if (_fileRecorder.isRecording) {
      try {
        await _fileRecorder.stopRecorder();
        logger.info('RecordingsService: Stopped current recording segment.');
      } catch (e, stack) {
        logger.error(
          'RecordingsService: Failed to stop recorder segment cleanly',
          error: e,
          stackTrace: stack,
        );
      }
    }
  }

  // Add helper to delete all segments (optional cleanup)
  Future<void> _deleteAllSegments() async {
    logger.info('RecordingsService: Deleting all remaining segments...');
    for (final path in List<String>.from(_segmentPaths)) {
      // Iterate over a copy
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
          logger.info('RecordingsService: Deleted segment: $path');
        }
      } catch (e) {
        logger.error(
          'RecordingsService: Failed to delete segment $path',
          error: e,
        );
      }
    }
    _segmentPaths.clear();
  }

  /// Concatenates the most recently buffered audio segments using FFmpeg,
  /// saves the result to permanent storage, and creates a Hive entry.
  Future<void> saveLastBuffer() async {
    if (_segmentPaths.isEmpty) {
      logger.warning('RecordingsService: No segments available to save.');
      return;
    }

    // Use the FFmpeg concatenation logic
    final List<String> pathsToConcatenate = List.from(_segmentPaths);
    logger.info(
      'RecordingsService: Attempting to save buffer by concatenating segments: ${pathsToConcatenate.join(", ")}',
    );

    // 1. Define permanent storage path
    final appDocDir = await getApplicationDocumentsDirectory();
    final recordingsDir = p.join(appDocDir.path, 'recordings');
    await Directory(recordingsDir).create(recursive: true);
    final recordingId = const Uuid().v4();
    final permanentPath = p.join(recordingsDir, 'recording_$recordingId.aac');

    // 2. Create FFmpeg command input file
    final tempDir = await getTemporaryDirectory();
    final concatListPath = p.join(tempDir.path, 'concat_list.txt');
    final fileListContent = pathsToConcatenate
        .map((path) => "file '$path'")
        .join('\n');
    await File(concatListPath).writeAsString(fileListContent);

    // 3. Define FFmpeg command
    final command =
        '-f concat -safe 0 -i "$concatListPath" -c copy "$permanentPath"';
    logger.info('RecordingsService: FFmpeg Concat Command: $command');

    try {
      // 4. Execute FFmpeg command
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      // 5. Check result and proceed if successful
      if (ReturnCode.isSuccess(returnCode)) {
        logger.info(
          'RecordingsService: FFmpeg concatenation successful: $permanentPath',
        );

        // 6. Create Hive entry with the single permanent path
        final now = DateTime.now();
        final title = 'Rec-${DateFormat.yMd().add_jms().format(now)}';
        final preview =
            'Buffered audio recording saved at ${DateFormat.Hm().format(now)}';

        final recording = Recording(
          id: recordingId,
          title: title,
          dateTime: now,
          preview: preview,
          filePath: permanentPath, // Pass the single concatenated path
          transcript: null,
        );

        await _recordingsBox.put(recording.id, recording);
        logger.info(
          'RecordingsService: Saved Recording entry to Hive: ${recording.id}',
        );

        // 7. Clean up temporary files (segments and concat list)
        await File(concatListPath).delete();
        for (final segmentPath in pathsToConcatenate) {
          try {
            final file = File(segmentPath);
            if (await file.exists()) {
              await file.delete();
            }
          } catch (e) {
            logger.error(
              'Failed to delete temp segment $segmentPath',
              error: e,
            );
          }
        }
        _segmentPaths.clear(); // Clear the list after saving
      } else {
        // Handle FFmpeg failure
        logger.error(
          'RecordingsService: FFmpeg concatenation failed. Code: $returnCode',
        );
        final logs = await session.getLogsAsString();
        logger.error('FFmpeg logs:\n$logs');
        // Clean up concat list file even on failure
        try {
          await File(concatListPath).delete();
        } catch (_) {}
        // Maybe delete the potentially incomplete permanent file?
        // try { await File(permanentPath).delete(); } catch (_) {}
        return; // Don't proceed if FFmpeg failed
      }
    } catch (e, stack) {
      logger.error(
        'RecordingsService: Exception during FFmpeg save/concat process',
        error: e,
        stackTrace: stack,
      );
      // Clean up list file even on error
      try {
        await File(concatListPath).delete();
      } catch (_) {}
    }
  }

  /// Cleans up resources.
  Future<void> dispose() async {
    logger.info('RecordingsService: Disposing...');
    _segmentSwitchTimer?.cancel();
    await _stopCurrentRecording(); // Ensure recorder is stopped
    await _fileRecorder.closeRecorder();
    await _deleteAllSegments(); // Clean up any remaining temp files on dispose
    _isRecorderInitialized = false;
    logger.info('RecordingsService: Disposed.');
  }
}
