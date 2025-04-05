import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/audio/audio_service.dart';

part 'live_listening_service.g.dart';

@riverpod
LiveListeningService liveListeningService(LiveListeningServiceRef ref) {
  // Depends on AudioService
  final audioService = ref.watch(audioServiceProvider);
  return LiveListeningService(audioService);
}

/// Service layer for the Live Listening feature.
/// Primarily acts as a wrapper/facade around the core AudioService,
/// potentially adding feature-specific configuration or logic.
class LiveListeningService {
  final AudioService _audioService;

  LiveListeningService(this._audioService);

  /// Configures and starts the listening session.
  Future<void> startSession(
    /* Add session specific parameters if needed */
  ) async {
    // TODO: Apply specific configurations from settings or mode before starting
    // Example: await _audioService.setSampleRate(44100);
    await _audioService.startListening();
  }

  /// Stops the current listening session.
  Future<void> stopSession() async {
    await _audioService.stopListening();
  }

  /// Applies a set of filters relevant to the live listening mode.
  Future<void> applyLiveFilters(Set<AudioFilter> filters) async {
    await _audioService.applyFilters(filters);
  }

  /// Sets the output volume.
  Future<void> setOutputVolume(double volume) async {
    await _audioService.setOutputVolume(volume);
  }

  // Expose relevant streams or states from AudioService if needed
  Stream<double> get audioLevelStream => _audioService.audioLevelStream;
  bool get isListening => _audioService.isRecording;
}
