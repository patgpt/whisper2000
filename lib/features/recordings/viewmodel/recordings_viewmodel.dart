import 'dart:math'; // For min function

import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:whisper2000/core/transcription/transcription_service.dart';

import '../../../core/audio/audio_service.dart'; // Import AudioService
import '../../../core/utils/logger.dart';
import '../ui/recordings_page.dart';

part 'recordings_viewmodel.g.dart';

// Box name constant - reuse if service doesn't own it
const String _recordingsBoxName = 'recordings';

// State is just the list of recordings
typedef RecordingsState = List<Recording>;

@Riverpod(keepAlive: true) // Keep recordings loaded
class RecordingsViewModel extends _$RecordingsViewModel {
  late final Box<Recording> _recordingBox;
  // late final RecordingsService _recordingService; // Optional: use service for logic

  @override
  RecordingsState build() {
    // _recordingService = ref.watch(recordingsServiceProvider);
    _recordingBox = Hive.box<Recording>(_recordingsBoxName);
    return _loadRecordingsFromBox();
  }

  List<Recording> _loadRecordingsFromBox() {
    final recordings =
        _recordingBox.values.toList()..sort(
          (a, b) => b.dateTime.compareTo(a.dateTime),
        ); // Sort newest first
    logger.info('Loaded ${_recordingBox.length} recordings from Hive.');
    return recordings;
  }

  /// Deletes a recording by its unique ID.
  Future<void> deleteRecording(String id) async {
    logger.info('Deleting recording with id: $id');
    await _recordingBox.delete(id);
    state = _loadRecordingsFromBox(); // Update state
  }

  /// Adds a new recording (potentially called by RecordingsService).
  /// Requires path to audio file and optional transcript.
  Future<void> addManualRecording(
    String title,
    String preview,
    // Revert to accepting single filePath directly
    String filePath,
    String id, // Add ID as required positional argument
  ) async {
    // Remove check for empty path if constructor handles it, or keep if desired
    if (filePath.isEmpty) {
      logger.error('addManualRecording called with empty filePath. Aborting.');
      return;
    }
    final newRecording = Recording(
      id: id, // Use the passed ID
      title: title,
      dateTime: DateTime.now(),
      preview: preview,
      // Pass filePath directly again
      filePath: filePath,
    );
    logger.info(
      'Adding recording metadata: ${newRecording.title} (ID: ${newRecording.id})',
    );
    await _recordingBox.put(newRecording.id, newRecording);
    state = _loadRecordingsFromBox(); // Update state
  }

  /// Initiates playback for a recording.
  Future<void> playRecording(String id) async {
    final recording = _recordingBox.get(id);
    if (recording == null) {
      logger.warning('Cannot play recording $id: Not found.');
      return;
    }
    // Revert check to use single filePath
    if (recording.filePath.isEmpty) {
      logger.warning('Cannot play recording $id: File path is missing.');
      return;
    }

    // Use filePath directly
    // final primaryFilePath = recording.filePaths.first;
    logger.info(
      'Initiating playback for: ${recording.title} (Path: ${recording.filePath})',
    );
    // Use AudioService to play the file
    final audioService = ref.read(audioServiceProvider);
    await audioService.playFile(recording.filePath);
  }

  /// Fetches the full transcript for a recording.
  Future<String?> getTranscript(String id, {bool forceRefresh = false}) async {
    final recording = _recordingBox.get(id);
    if (recording == null) {
      logger.warning('Cannot get transcript for $id: Recording not found.');
      return null;
    }

    if (!forceRefresh &&
        recording.transcript != null &&
        recording.transcript!.isNotEmpty) {
      logger.info('Returning cached transcript for: ${recording.title}');
      return recording.transcript;
    }

    logger.info(
      'Transcript not cached or refresh forced for: ${recording.title}. Calling service...',
    );

    // Revert check for empty file path
    if (recording.filePath.isEmpty) {
      logger.error('Cannot transcribe recording $id: File path is empty.');
      return "[Error: Recording has no audio file]";
    }

    // Use filePath directly
    // final primaryFilePath = recording.filePaths.first;

    // 2. Call TranscriptionService
    String? transcript;
    try {
      transcript = await ref
          .read(transcriptionServiceProvider)
          .transcribeAudioFile(recording.filePath); // Pass filePath directly
    } catch (e, stack) {
      logger.error(
        'Error calling transcription service for $id',
        error: e,
        stackTrace: stack,
      );
      return "[Error calling Transcription Service]"; // Return error indication
    }

    // 3. Save the retrieved transcript back to Hive if valid
    if (transcript != null &&
        transcript.isNotEmpty &&
        !transcript.startsWith('[')) {
      // Check for errors
      logger.info('Transcription successful for $id. Saving to Hive.');
      final newPreview = transcript.substring(0, min(100, transcript.length));
      final updatedRecording = recording.copyWith(
        transcript: transcript,
        preview: newPreview,
      );
      await _recordingBox.put(id, updatedRecording);
      state = _loadRecordingsFromBox(); // Update UI state
      return transcript;
    } else {
      logger.warning(
        'Transcription service returned null, empty, or error for $id: $transcript',
      );
      // Don't save invalid transcript back, just return the result
      return transcript ?? "[Transcription Failed]";
    }
  }

  /// Initiates transcription for a specific recording.
  Future<void> transcribeRecording(String id) async {
    logger.info('Manual transcription requested for recording ID: $id');
    // Call getTranscript with forceRefresh: true to trigger service call & saving
    final transcript = await getTranscript(id, forceRefresh: true);
    if (transcript != null && !transcript.startsWith('[')) {
      logger.info('Manual transcription completed successfully for $id.');
      // UI state already updated in getTranscript
    } else {
      logger.warning(
        'Manual transcription failed for $id. Result: $transcript',
      );
      // TODO: Show error message to user
    }
  }
}
