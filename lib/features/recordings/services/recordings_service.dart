import 'dart:async';

import 'package:flutter_sound/flutter_sound.dart';
import 'package:intl/intl.dart'; // Import for DateFormat
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/logger.dart';
import '../viewmodel/recordings_viewmodel.dart'; // To add recording metadata

part 'recordings_service.g.dart';

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
  String? _currentRecordingPath;
  Timer? _bufferTimer;
  Duration _bufferDuration = const Duration(seconds: 30);

  // TODO: Add state for whether auto-recording is enabled

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
  }

  /// Starts recording the microphone input to a temporary buffer file.
  /// This might be constantly running if auto-save is enabled.
  Future<void> startBuffering() async {
    if (!_isRecorderInitialized || _fileRecorder.isRecording) return;

    // TODO: Implement circular buffer logic
    // - Record to a file.
    // - After _bufferDuration, stop and start recording to a new file.
    // - Keep track of the last N files (e.g., 2 files to cover the 30s duration safely).
    // - Delete oldest files.

    // --- Placeholder: Record to single file for now ---
    try {
      final tempDir = await getTemporaryDirectory();
      final recordingId = const Uuid().v4();
      _currentRecordingPath = p.join(tempDir.path, 'buffer_$recordingId.aac');
      await _fileRecorder.startRecorder(
        toFile: _currentRecordingPath,
        codec: Codec.aacADTS,
      );
      logger.info(
        'RecordingsService: Started buffering to $_currentRecordingPath',
      );

      // Set timer to stop after buffer duration (simple approach)
      _bufferTimer?.cancel();
      _bufferTimer = Timer(_bufferDuration, () {
        logger.info(
          'RecordingsService: Buffer duration reached, stopping recorder.',
        );
        stopBuffering(); // Or restart buffering for circular logic
      });
    } catch (e, stack) {
      logger.error(
        'RecordingsService: Failed to start buffering',
        error: e,
        stackTrace: stack,
      );
      _currentRecordingPath = null;
    }
    // --- End Placeholder ---
  }

  /// Stops the current buffering process.
  Future<void> stopBuffering() async {
    _bufferTimer?.cancel();
    _bufferTimer = null;
    if (_fileRecorder.isRecording) {
      try {
        await _fileRecorder.stopRecorder();
        logger.info('RecordingsService: Stopped buffering.');
      } catch (e, stack) {
        logger.error(
          'RecordingsService: Failed to stop recorder cleanly',
          error: e,
          stackTrace: stack,
        );
      }
    } else {
      logger.info('RecordingsService: Buffering already stopped.');
    }
  }

  /// Saves the most recently buffered audio (e.g., last 30s) to permanent storage.
  Future<void> saveLastBuffer() async {
    if (_currentRecordingPath == null) {
      logger.warning('RecordingsService: No buffer available to save.');
      return;
    }
    await stopBuffering(); // Ensure current recording is finished

    try {
      // TODO: Implement actual saving logic
      // 1. Define permanent storage path (e.g., using getApplicationDocumentsDirectory)
      // 2. Copy the temporary buffer file(s) to the permanent location.
      // 3. Generate metadata (title, preview - maybe via transcription?).
      // 4. Add metadata to Hive via RecordingsViewModel.

      logger.info(
        'RecordingsService: Saving buffer from $_currentRecordingPath',
      );

      // --- Placeholder ---
      final recordingTitle =
          'Recording ${DateFormat.jms().format(DateTime.now())}';
      final recordingPreview = 'Audio snippet saved...'; // Placeholder
      await ref
          .read(recordingsViewModelProvider.notifier)
          .addManualRecording(recordingTitle, recordingPreview);
      logger.info(
        'RecordingsService: Saved buffer metadata for $recordingTitle',
      );
      // TODO: Delete the temporary buffer file(s) after successful copy/metadata save
      // File(_currentRecordingPath!).delete();
      _currentRecordingPath = null;
      // --- End Placeholder ---
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
    _bufferTimer?.cancel();
    if (_fileRecorder.isRecording) await _fileRecorder.stopRecorder();
    await _fileRecorder.closeRecorder();
    logger.info('RecordingsService: Disposed.');
  }
}
