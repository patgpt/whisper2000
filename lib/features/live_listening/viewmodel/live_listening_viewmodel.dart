import 'dart:async';

import 'package:flutter/foundation.dart'; // Import for VoidCallback
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/audio/audio_service.dart';
import '../../../core/utils/logger.dart';
// Import RecordingsService to trigger save
import '../../recordings/services/recordings_service.dart';
// Import SettingsViewModel to check autoSave
import '../../settings/viewmodel/settings_viewmodel.dart';

part 'live_listening_viewmodel.g.dart';

// Re-using state definition, maybe rename to LiveListeningState if preferred
class ListeningState {
  final AudioServiceInitState audioInitState;
  final String? audioInitError;

  final bool isListening;
  final bool noiseSuppression;
  final bool voiceBoost;
  final bool directionalMode;
  final double outputVolume;
  final double waveformLevel;

  const ListeningState({
    this.audioInitState = AudioServiceInitState.idle,
    this.audioInitError,
    this.isListening = false,
    this.noiseSuppression = true,
    this.voiceBoost = false,
    this.directionalMode = false,
    this.outputVolume = 0.7,
    this.waveformLevel = 0.0,
  });

  ListeningState copyWith({
    AudioServiceInitState? audioInitState,
    String? audioInitError,
    bool? isListening,
    bool? noiseSuppression,
    bool? voiceBoost,
    bool? directionalMode,
    double? outputVolume,
    double? waveformLevel,
  }) {
    return ListeningState(
      audioInitState: audioInitState ?? this.audioInitState,
      audioInitError: audioInitError ?? this.audioInitError,
      isListening: isListening ?? this.isListening,
      noiseSuppression: noiseSuppression ?? this.noiseSuppression,
      voiceBoost: voiceBoost ?? this.voiceBoost,
      directionalMode: directionalMode ?? this.directionalMode,
      outputVolume: outputVolume ?? this.outputVolume,
      waveformLevel: waveformLevel ?? this.waveformLevel,
    );
  }
}

// Rename Notifier and Provider
@riverpod
class LiveListeningViewModel extends _$LiveListeningViewModel {
  late final AudioService _audioService;
  StreamSubscription? _audioLevelSubscription;
  // Add listener for init state
  VoidCallback? _initListener;

  @override
  ListeningState build() {
    _audioService = ref.watch(audioServiceProvider);

    // Listen to audio level changes from the service
    _audioLevelSubscription = _audioService.audioLevelStream.listen((level) {
      // Only update level if actively listening (avoids jump when starting)
      if (state.isListening) {
        state = state.copyWith(waveformLevel: level);
      }
    });

    // Listen to init state changes
    _initListener = () {
      state = state.copyWith(
        audioInitState: _audioService.initStateNotifier.value,
        audioInitError: _audioService.initError,
      );
      // If initialized, set initial volume based on state
      if (state.audioInitState == AudioServiceInitState.initialized) {
        _audioService.setOutputVolume(state.outputVolume);
      }
    };
    _audioService.initStateNotifier.addListener(_initListener!);

    // Clean up subscription when the provider is disposed
    ref.onDispose(() {
      logger.info(
        "Disposing LiveListeningViewModel, cancelling subscriptions.",
      );
      _audioLevelSubscription?.cancel();
      _audioService.initStateNotifier.removeListener(
        _initListener!,
      ); // Remove listener
    });

    // Initial state, including current init state from service
    return ListeningState(
      audioInitState: _audioService.initStateNotifier.value,
      audioInitError: _audioService.initError,
      // Keep other defaults
    );
  }

  // Methods delegate to AudioService and update local state

  Future<void> startListening() async {
    logger.info("LiveListeningViewModel: startListening called");
    await _audioService.startListening();
    // Update state based on audio service potentially
    state = state.copyWith(isListening: _audioService.isRecording);
  }

  Future<void> stopListening() async {
    logger.info("LiveListeningViewModel: stopListening called");
    // Stop the audio stream first
    await _audioService.stopListening();

    // Check settings and potentially save the buffer
    final settings = ref.read(settingsViewModelProvider);
    if (settings.autoSave) {
      logger.info(
        "Auto-save enabled, triggering saveLastBuffer in RecordingsService...",
      );
      try {
        // Get the RecordingsService instance and call save
        await ref.read(recordingsServiceProvider).saveLastBuffer();
        logger.info("saveLastBuffer call completed.");
      } catch (e, stack) {
        logger.error(
          "Error calling saveLastBuffer from LiveListeningViewModel",
          error: e,
          stackTrace: stack,
        );
        // Handle error? Maybe notify user?
      }
    } else {
      logger.info("Auto-save disabled, not saving buffer.");
      // If not auto-saving, we might want to discard the temp segments explicitly?
      // Optional: await ref.read(recordingsServiceProvider)._deleteAllSegments();
    }

    // Update the UI state last
    state = state.copyWith(isListening: false, waveformLevel: 0.0);
  }

  // Method to apply all current filters to the audio service
  Future<void> _applyAllFilters() async {
    final activeFilters = <AudioFilter>{};
    if (state.noiseSuppression) activeFilters.add(AudioFilter.noiseSuppression);
    if (state.voiceBoost) activeFilters.add(AudioFilter.voiceBoost);
    if (state.directionalMode) activeFilters.add(AudioFilter.directional);
    await _audioService.applyFilters(activeFilters);
  }

  void setNoiseSuppression(bool value) {
    state = state.copyWith(noiseSuppression: value);
    _applyAllFilters();
  }

  void setVoiceBoost(bool value) {
    state = state.copyWith(voiceBoost: value);
    _applyAllFilters();
  }

  void setDirectionalMode(bool value) {
    state = state.copyWith(directionalMode: value);
    _applyAllFilters();
  }

  void setOutputVolume(double value) {
    // Update state first
    state = state.copyWith(outputVolume: value);
    // Apply only if audio service is actually initialized
    if (_audioService.isInitialized) {
      _audioService.setOutputVolume(value);
    }
  }
}
