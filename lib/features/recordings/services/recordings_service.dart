import 'dart:async';
import 'dart:io';

import 'package:flutter_sound/flutter_sound.dart';
import 'package:intl/intl.dart'; // Import for DateFormat
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/logger.dart';
import '../viewmodel/recordings_viewmodel.dart'; // To add recording metadata

part 'recordings_service.g.dart';

// Constants for buffer logic
const Duration _segmentDuration = Duration(seconds: 15);
const int _maxSegments = 2; // Keep last 2 segments for ~30 seconds

@riverpod
RecordingsService recordingsService(RecordingsServiceRef ref) {
  // Could depend on AudioService, ViewModel, etc.
  return RecordingsService(ref);
}

/// Service responsible for managing the recording process (saving audio snippets).
class RecordingsService {
  final ProviderRef ref;
  final FlutterSoundRecorder _fileRecorder = FlutterSoundRecorder();
  bool _isRecorderInitialized = false;

  // Track multiple segment files
  final List<String> _segmentPaths = [];
  Timer? _segmentSwitchTimer;

  // State for auto-save
  bool _isAutoBufferingEnabled = false; // TODO: Link this to settings

  // Define buffer duration (re-add)
  final Duration _bufferDuration = _segmentDuration * _maxSegments;

  // Remove old single path and timer
  // String? _currentRecordingPath;

  RecordingsService(this.ref) {
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
    // TODO: Check settings for auto-save and start buffering if needed
    if (_isAutoBufferingEnabled) {
      startBuffering();
    }
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

  /// Starts recording the microphone input to a temporary buffer file.
  /// This might be constantly running if auto-save is enabled.
  Future<void> startBuffering() async {
    if (!_isRecorderInitialized || _segmentSwitchTimer != null)
      return; // Already buffering

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

    _isAutoBufferingEnabled = true; // Mark as buffering (or use recorder state)
  }

  /// Stops the current buffering process.
  Future<void> stopBuffering() async {
    logger.info('RecordingsService: Stopping continuous buffering...');
    _segmentSwitchTimer?.cancel();
    _segmentSwitchTimer = null;
    await _stopCurrentRecording();
    _isAutoBufferingEnabled = false;
    // Optionally delete all remaining segment files if stopping completely
    // await _deleteAllSegments();
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

  /// Saves the most recently buffered audio (e.g., last 30s) to permanent storage.
  Future<void> saveLastBuffer() async {
    // Determine which segment to save (the most recently completed one)
    String? segmentToSavePath;
    if (_segmentPaths.length >= _maxSegments) {
      // If we have enough segments, save the second to last one
      segmentToSavePath = _segmentPaths[_segmentPaths.length - _maxSegments];
    } else if (_segmentPaths.isNotEmpty) {
      // Otherwise, save the first/only one we have (less than full buffer duration)
      segmentToSavePath = _segmentPaths.first;
    }

    if (segmentToSavePath == null) {
      logger.warning(
        'RecordingsService: No complete segment available to save.',
      );
      return;
    }

    // No need to stop buffering if it's running continuously
    // await stopBuffering(); // Maybe keep buffering running?

    logger.info(
      'RecordingsService: Attempting to save segment: $segmentToSavePath',
    );

    try {
      // Check if file exists before attempting to save
      final fileToSave = File(segmentToSavePath);
      if (!await fileToSave.exists()) {
        logger.error(
          'RecordingsService: Segment file to save does not exist: $segmentToSavePath',
        );
        return;
      }

      // TODO: Implement actual saving logic
      // 1. Define permanent storage path
      final appDocDir = await getApplicationDocumentsDirectory();
      final permanentPath = p.join(
        appDocDir.path,
        'recordings',
        p.basename(segmentToSavePath),
      );
      // Ensure recordings directory exists
      await Directory(p.dirname(permanentPath)).create(recursive: true);

      // 2. Copy the temporary segment file to the permanent location.
      await fileToSave.copy(permanentPath);
      logger.info(
        'RecordingsService: Copied $segmentToSavePath to $permanentPath',
      );

      // 3. Generate metadata (title, preview - maybe via transcription?).
      final recordingTitle =
          'Rec-${DateFormat.yMd().add_jms().format(DateTime.now())}';
      final recordingPreview =
          'Audio snippet...'; // TODO: Add transcription preview

      // 4. Add metadata to Hive via RecordingsViewModel.
      await ref
          .read(recordingsViewModelProvider.notifier)
          .addManualRecording(recordingTitle, recordingPreview, permanentPath);
      logger.info(
        'RecordingsService: Saved buffer metadata for $recordingTitle',
      );

      // TODO: Optionally delete the *saved* temporary segment file? Or rely on cleanup?
      // await fileToSave.delete();
    } catch (e, stack) {
      logger.error(
        'RecordingsService: Failed to save buffer',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Cleans up resources.
  Future<void> dispose() async {
    logger.info('RecordingsService: Disposing...');
    _segmentSwitchTimer?.cancel();
    if (_fileRecorder.isRecording) await _fileRecorder.stopRecorder();
    await _fileRecorder.closeRecorder();
    logger.info('RecordingsService: Disposed.');
  }
}
