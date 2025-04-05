import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

// 1. State Class
class ListeningState {
  final bool isListening;
  final bool noiseSuppression;
  final bool voiceBoost;
  final bool directionalMode;
  final double outputVolume;
  final double waveformLevel; // Add level (e.g., 0.0 to 1.0)
  // Add other relevant state here, e.g., waveform data, errors

  ListeningState({
    this.isListening = false,
    this.noiseSuppression = true, // Default based on previous UI state
    this.voiceBoost = false,
    this.directionalMode = false,
    this.outputVolume = 0.7, // Default based on previous UI state
    this.waveformLevel = 0.0, // Default level
  });

  ListeningState copyWith({
    bool? isListening,
    bool? noiseSuppression,
    bool? voiceBoost,
    bool? directionalMode,
    double? outputVolume,
    double? waveformLevel, // Add level
  }) {
    return ListeningState(
      isListening: isListening ?? this.isListening,
      noiseSuppression: noiseSuppression ?? this.noiseSuppression,
      voiceBoost: voiceBoost ?? this.voiceBoost,
      directionalMode: directionalMode ?? this.directionalMode,
      outputVolume: outputVolume ?? this.outputVolume,
    );
  }
}

// 2. Notifier
class ListeningStateNotifier extends StateNotifier<ListeningState> {
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isPlayerInitialized = false;
  bool _isRecorderInitialized = false;

  StreamSubscription? _recorderSubscription;

  // TODO: Add stream subscriptions for player/recorder state

  ListeningStateNotifier() : super(ListeningState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _player.openPlayer();
      _isPlayerInitialized = true;

      // Request microphone permission
      var status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        throw Exception('Microphone permission not granted');
      }

      await _recorder.openRecorder();
      _isRecorderInitialized = true;

      // Set recorder subscription duration (example: 100ms)
      _recorder.setSubscriptionDuration(const Duration(milliseconds: 100));

      // Start listening to recorder progress
      _recorderSubscription = _recorder.onProgress?.listen((e) {
        if (e != null && e.decibels != null) {
          // Simple mapping of decibels to a 0.0-1.0 level
          // This needs tuning based on expected dB range (-120 to 0)
          double level = (e.decibels! + 120) / 120;
          state = state.copyWith(waveformLevel: level.clamp(0.0, 1.0));
        }
      });
    } catch (e) {
      print('Error initializing audio: $e');
      // TODO: Update state with error
    }
    // Notify UI that initialization is complete (or failed)
  }

  @override
  void dispose() {
    _recorderSubscription?.cancel(); // Cancel subscription
    _player.closePlayer();
    _recorder.closeRecorder();
    super.dispose();
  }

  Future<void> startListening() async {
    if (!_isRecorderInitialized || !_isPlayerInitialized || state.isListening)
      return;

    try {
      // TODO: Define paths and codecs
      // Example: Use flutter_sound's loopback/playback features
      // This requires more complex setup involving feeding recorder output to player input.
      // For now, just start recorder as a placeholder.
      print('Starting Recorder (Placeholder for pipeline)');
      // await _recorder.startRecorder(toFile: 'path/to/audio.aac');

      // TODO: Start player (e.g., playing processed output)

      state = state.copyWith(isListening: true);
    } catch (e) {
      print('Error starting listening: $e');
      stopListening(); // Ensure state is reset on error
    }
  }

  Future<void> stopListening() async {
    if (!_isRecorderInitialized || !_isPlayerInitialized) return;

    // Reset waveform level when stopping
    state = state.copyWith(isListening: false, waveformLevel: 0.0);

    try {
      if (_recorder.isRecording) {
        await _recorder.stopRecorder();
        print('Stopped Recorder');
      }
      if (_player.isPlaying) {
        await _player.stopPlayer();
        print('Stopped Player');
      }
    } catch (e) {
      print('Error stopping listening: $e');
    }
  }

  void setNoiseSuppression(bool value) {
    state = state.copyWith(noiseSuppression: value);
    print('Setting Noise Suppression: $value (TODO: Apply filter)');
    // TODO: Apply/remove FFMPEG filter or other processing
  }

  void setVoiceBoost(bool value) {
    state = state.copyWith(voiceBoost: value);
    print('Setting Voice Boost: $value (TODO: Apply filter)');
    // TODO: Apply/remove FFMPEG filter or other processing
  }

  void setDirectionalMode(bool value) {
    state = state.copyWith(directionalMode: value);
    print('Setting Directional Mode: $value (TODO: Configure mic input)');
    // TODO: Adjust microphone input settings if possible
  }

  void setOutputVolume(double value) {
    state = state.copyWith(outputVolume: value);
    if (_isPlayerInitialized) {
      _player.setVolume(value); // Set player volume
      print('Set player volume to: $value');
    }
  }
}

// 3. Provider
final listeningStateProvider =
    StateNotifierProvider<ListeningStateNotifier, ListeningState>((ref) {
      return ListeningStateNotifier();
    });
