import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart'; // For generating IDs

import '../../../core/audio/audio_service.dart'; // Import AudioService
import '../../../core/transcription/transcription_service.dart';
import '../../../core/utils/logger.dart';
import '../services/recordings_service.dart';
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
    String filePath, // Add filePath parameter
  ) async {
    final newRecording = Recording(
      id: const Uuid().v4(),
      title: title,
      dateTime: DateTime.now(),
      preview: preview,
      filePath: filePath, // Store file path
    );
    logger.info('Adding recording metadata: ${newRecording.title}');
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
    if (recording.filePath.isEmpty) {
      logger.warning('Cannot play recording $id: File path is missing.');
      return;
    }

    logger.info(
      'Initiating playback for: ${recording.title} (Path: ${recording.filePath})',
    );
    // Use AudioService to play the file
    // Need access to AudioService provider
    final audioService = ref.read(audioServiceProvider);
    await audioService.playFile(recording.filePath);
  }

  /// Fetches the full transcript for a recording.
  Future<String?> getTranscript(String id) async {
    final recording = _recordingBox.get(id);
    if (recording == null) {
      logger.warning('Cannot get transcript for $id: Not found.');
      return null;
    }
    logger.info('Fetching transcript for: ${recording.title}');

    // TODO: Implement actual transcript loading
    // 1. Check if transcript already exists (e.g., in Recording object/Hive)
    //    if (recording.transcript != null) return recording.transcript;
    // 2. If not, call TranscriptionService
    final transcript = await ref
        .read(transcriptionServiceProvider)
        .transcribeAudioFile(recording.filePath);
    // 3. (Optional) Save the retrieved transcript back to the Recording object in Hive
    //    if (transcript != null) {
    //       final updatedRecording = recording.copyWith(transcript: transcript, preview: transcript.substring(0, min(50, transcript.length)));
    //       await _recordingBox.put(id, updatedRecording);
    //       state = _loadRecordingsFromBox(); // Update UI state if preview changed
    //    }

    return transcript ?? "[Transcription Failed]";
  }

  /// Initiates transcription for a specific recording.
  /// Called explicitly, e.g., from a button.
  Future<void> transcribeRecording(String id) async {
    logger.info('Manual transcription requested for recording ID: $id');
    final transcript = await getTranscript(id); // Reuse getTranscript logic
    if (transcript != null) {
      logger.info('Manual transcription completed for $id.');
      // Optionally update state or show confirmation
    } else {
      logger.warning('Manual transcription failed for $id.');
      // Optionally show error message
    }
    // Note: getTranscript already handles saving if implemented
  }
}
