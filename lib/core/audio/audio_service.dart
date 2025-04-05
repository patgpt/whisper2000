import 'dart:async';

import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../utils/logger.dart';

part 'audio_service.g.dart';

// TODO: Define appropriate Filter types or enums
enum AudioFilter { noiseSuppression, voiceBoost, directional }

@Riverpod(keepAlive: true)
AudioService audioService(AudioServiceRef ref) {
  // Creates a singleton instance managed by Riverpod
  return AudioService();
}

/// Manages audio input (microphone), output (speaker/headphones),
/// and real-time processing pipeline.
class AudioService {
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isPlayerInitialized = false;
  bool _isRecorderInitialized = false;
  StreamSubscription? _recorderSubscription;
  StreamSubscription? _playerSubscription;

  bool get isRecording => _recorder.isRecording;
  bool get isPlaying => _player.isPlaying;

  // StreamController for processed audio levels (e.g., for visualiser)
  final StreamController<double> _audioLevelController =
      StreamController.broadcast();
  Stream<double> get audioLevelStream => _audioLevelController.stream;

  AudioService() {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _player.openPlayer();
      _isPlayerInitialized = true;
      _setupPlayerListener();
      logger.info('AudioService: Player initialized.');

      var status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        logger.warning('AudioService: Microphone permission denied.');
        throw Exception('Microphone permission not granted');
      }

      await _recorder.openRecorder();
      _isRecorderInitialized = true;
      _setupRecorderListener();
      logger.info('AudioService: Recorder initialized.');
    } catch (e, stack) {
      logger.error(
        'AudioService: Initialization failed',
        error: e,
        stackTrace: stack,
      );
      // TODO: Propagate error state to UI if needed
    }
  }

  void _setupRecorderListener() {
    if (!_isRecorderInitialized) return;
    _recorder.setSubscriptionDuration(const Duration(milliseconds: 100));
    _recorderSubscription = _recorder.onProgress?.listen((e) {
      if (e.decibels != null) {
        // Simple mapping of decibels to a 0.0-1.0 level
        double level = (e.decibels! + 120) / 120; // Adjust range as needed
        _audioLevelController.add(level.clamp(0.0, 1.0));

        // TODO: Get raw audio buffer `e.data` if needed for processing/recording
      }
    });
  }

  void _setupPlayerListener() {
    if (!_isPlayerInitialized) return;
    // TODO: Listen to player state if needed (e.g., end of playback)
    _playerSubscription = _player.onProgress?.listen((e) {
      // Handle playback progress if necessary
    });
  }

  /// Starts the real-time audio processing pipeline (Mic -> Filters -> Output).
  Future<void> startListening() async {
    if (!_isRecorderInitialized || !_isPlayerInitialized || isRecording) {
      logger.warning(
        'AudioService: Cannot start listening - not initialized or already recording.',
      );
      return;
    }
    logger.info('AudioService: Starting listening pipeline...');
    try {
      // TODO: Implement the actual audio pipeline:
      // 1. Start recorder to capture mic input (maybe to a stream codec like opus or pcm).
      //    Consider using `startRecorder(toStream: ..., codec: Codec.pcm16)`
      //    Need a StreamController to receive the recorder's output stream data.
      // await _recorder.startRecorder(toStream: _recordingDataController.sink, codec: Codec.pcm16);

      // 2. Process the stream: Apply filters based on current settings.
      //    - Use FFMPEG commands via ffmpeg_kit_flutter for complex filtering (NR, EQ).
      //    - Or potentially use Dart-based libraries if available/suitable.
      // _recordingDataController.stream.listen((buffer) {
      //   var processedBuffer = _applyCurrentFilters(buffer);
      //   _playbackDataController.add(processedBuffer);
      // });

      // 3. Start player to play back the processed stream.
      //    Use `feedFromStream` or similar method if available with flutter_sound player.
      //    Or write processed data to a temporary file and play that file (less real-time).
      // await _player.startPlayerFromStream(codec: Codec.pcm16, numChannels: 1, sampleRate: 44100);
      // _playbackDataController.stream.listen((buffer) {
      //    _player.feedFromStream(buffer);
      // });

      // --- Placeholder ---
      await _recorder.startRecorder(
        toFile: 'placeholder_output.aac',
      ); // Using file temporarily
      logger.info('AudioService: Placeholder recorder started.');
      // --- End Placeholder ---

      // TODO: Update internal state if needed (e.g., isPipelineActive)
    } catch (e, stack) {
      logger.error(
        'AudioService: Failed to start listening',
        error: e,
        stackTrace: stack,
      );
      await stopListening(); // Ensure cleanup on error
    }
  }

  /// Stops the real-time audio processing pipeline.
  Future<void> stopListening() async {
    logger.info('AudioService: Stopping listening pipeline...');
    try {
      if (_recorder.isRecording) {
        await _recorder.stopRecorder();
        logger.info('AudioService: Recorder stopped.');
      }
      if (_player.isPlaying) {
        await _player.stopPlayer();
        logger.info('AudioService: Player stopped.');
      }
      // TODO: Close any intermediate streams (recordingDataController, playbackDataController)
      _audioLevelController.add(0.0); // Reset level visualizer
    } catch (e, stack) {
      logger.error(
        'AudioService: Failed to stop listening cleanly',
        error: e,
        stackTrace: stack,
      );
    }
    // TODO: Update internal state
  }

  /// Applies the specified audio filters to the pipeline.
  /// This might involve modifying FFMPEG commands or parameters.
  Future<void> applyFilters(Set<AudioFilter> activeFilters) async {
    if (!isRecording) {
      logger.warning("AudioService: Cannot apply filters, not listening.");
      return;
    }
    logger.info('AudioService: Applying filters: ${activeFilters.join(', ')}');
    // TODO: Implement filter application logic.
    // This is complex and depends heavily on the chosen audio processing method.
    // Example: If using FFMPEG, might need to restart the ffmpeg process
    // with new filter arguments. If using Dart processing, adjust parameters.
  }

  /// Adjusts the output volume.
  Future<void> setOutputVolume(double volume) async {
    if (!_isPlayerInitialized) return;
    try {
      await _player.setVolume(volume.clamp(0.0, 1.0));
      logger.info('AudioService: Output volume set to $volume');
    } catch (e, stack) {
      logger.error(
        'AudioService: Failed to set volume',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Plays the specified audio file.
  Future<void> playFile(String filePath) async {
    if (!_isPlayerInitialized) {
      logger.warning('AudioService: Cannot play file, player not initialized.');
      return;
    }
    if (isPlaying) {
      logger.info(
        'AudioService: Stopping current playback before starting new file.',
      );
      await _player.stopPlayer();
    }
    // TODO: May need to handle recorder being active depending on use case
    // if (isRecording) { await stopListening(); } // Example: Stop live listening?

    try {
      logger.info('AudioService: Starting playback for file: $filePath');
      await _player.startPlayer(
        fromURI: filePath,
        // codec: Codec.aacADTS, // Specify codec if known/needed
        whenFinished: () {
          logger.info('AudioService: Playback finished for file: $filePath');
          // TODO: Update state if needed (e.g., clear now playing info)
        },
      );
    } catch (e, stack) {
      logger.error(
        'AudioService: Failed to play file $filePath',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Cleans up resources when the service is no longer needed.
  Future<void> dispose() async {
    logger.info('AudioService: Disposing...');
    await _recorderSubscription?.cancel();
    await _playerSubscription?.cancel();
    if (_recorder.isRecording) await _recorder.stopRecorder();
    if (_player.isPlaying) await _player.stopPlayer();
    await _player.closePlayer();
    await _recorder.closeRecorder();
    await _audioLevelController.close();
    logger.info('AudioService: Disposed.');
  }
}
