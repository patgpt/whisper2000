import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart'; // Import Hive

import '../ui/recordings_page.dart'; // Import Recording class definition

// Box name constant
const String _recordingsBoxName = 'recordings';

// 1. State is just the list of recordings
typedef RecordingsState = List<Recording>;

// 2. Notifier
class RecordingNotifier extends StateNotifier<RecordingsState> {
  // Keep a reference to the box
  final Box<Recording> _box;

  // Pass the opened box to the notifier
  RecordingNotifier(this._box) : super([]) {
    // Start with empty list
    loadRecordings(); // Load existing recordings on init
  }

  // Method to add a new recording
  void addRecording(Recording recording) {
    // Hive requires unique keys. We can use timestamp or UUID.
    // For simplicity, using dateTime as key (potential for collision)
    // A robust solution would use a proper UUID.
    _box.put(recording.dateTime.toIso8601String(), recording);
    loadRecordings(); // Reload state from box
  }

  // Modify delete to use the key
  void deleteRecordingByKey(String key) {
    _box.delete(key);
    loadRecordings(); // Reload state from box
  }

  // Method to load recordings from the box
  void loadRecordings() {
    // Load all recordings from the box
    // Sort them, e.g., by date descending
    final recordings =
        _box.values.toList()..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    state = recordings;
  }
}

// 3. Provider
final recordingProvider =
    StateNotifierProvider<RecordingNotifier, RecordingsState>((ref) {
      // Get the box (already opened in main.dart)
      final box = Hive.box<Recording>(_recordingsBoxName);
      return RecordingNotifier(box);
    });
