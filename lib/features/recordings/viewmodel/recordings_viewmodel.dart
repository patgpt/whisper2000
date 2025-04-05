import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart'; // For generating IDs

import '../../../core/utils/logger.dart';
import '../services/recordings_service.dart'; // Import service
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
  Future<void> addManualRecording(String title, String preview) async {
    final newRecording = Recording(
      id: const Uuid().v4(),
      title: title,
      dateTime: DateTime.now(),
      preview: preview,
    );
    logger.info('Manually adding recording: ${newRecording.title}');
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
    logger.info('Initiating playback for: ${recording.title}');
    // TODO: Implement playback logic
    // - Needs access to the audio file associated with the recording ID.
    // - Use AudioService or a dedicated playback service.
    // Example: ref.read(audioServiceProvider).playFile(filePath);
  }

  /// Fetches the full transcript for a recording.
  Future<String?> getTranscript(String id) async {
    final recording = _recordingBox.get(id);
    if (recording == null) return null;
    logger.info('Fetching transcript for: ${recording.title}');
    // TODO: Implement transcript loading logic
    // - Load from file path stored in Recording object or separate storage.
    return "Placeholder transcript for ${recording.title}...";
  }
}
