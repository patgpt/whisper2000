import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/audio/audio_service.dart';
import '../../../core/utils/logger.dart';

part 'live_listening_viewmodel.g.dart';

// Re-using state definition, maybe rename to LiveListeningState if preferred
class ListeningState {
  final bool isListening;
  final bool noiseSuppression;
  final bool voiceBoost;
  final bool directionalMode;
  final double outputVolume;
  final double waveformLevel;

  const ListeningState({
    this.isListening = false,
    this.noiseSuppression = true,
    this.voiceBoost = false,
    this.directionalMode = false,
    this.outputVolume = 0.7,
    this.waveformLevel = 0.0,
  });

  ListeningState copyWith({
    bool? isListening,
    bool? noiseSuppression,
    bool? voiceBoost,
    bool? directionalMode,
    double? outputVolume,
    double? waveformLevel,
  }) {
    return ListeningState(
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

    // Clean up subscription when the provider is disposed
    ref.onDispose(() {
      logger.info(
        "Disposing LiveListeningViewModel, cancelling subscriptions.",
      );
      _audioLevelSubscription?.cancel();
    });

    // Initial state, reflecting defaults
    return const ListeningState();
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
    await _audioService.stopListening();
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
    state = state.copyWith(outputVolume: value);
    _audioService.setOutputVolume(value);
  }
}
