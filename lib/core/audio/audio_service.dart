import 'dart:async';

import 'package:flutter/foundation.dart'; // Import for ValueNotifier
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../utils/logger.dart';

part 'audio_service.g.dart';

// Enum for initialization state
enum AudioServiceInitState { idle, initializing, initialized, error }

// TODO: Define appropriate Filter types or enums
enum AudioFilter { noiseSuppression, voiceBoost, directional }

enum PlaybackState { stopped, playing, paused }

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
  // Add Stream Controllers for pipeline
  StreamController<Uint8List>? _recordingDataController;
  StreamSubscription? _recordingDataSubscription;
  // Define the codec and sample rate for streaming
  // Note: Check compatibility with potential filters (FFMPEG might prefer specific formats)
  final Codec _streamCodec = Codec.pcm16;
  final int _sampleRate = 44100; // Common sample rate
  final int _numChannels = 1; // Mono

  // State Management
  final ValueNotifier<AudioServiceInitState> initStateNotifier = ValueNotifier(
    AudioServiceInitState.idle,
  );
  String? _initError;
  String? get initError => _initError;

  // Public getters for state
  AudioServiceInitState get initState => initStateNotifier.value;
  bool get isInitialized =>
      initStateNotifier.value == AudioServiceInitState.initialized;
  bool get isRecording => _recorder.isRecording;
  PlaybackState get playbackState => playerStateNotifier.value;
  bool get isPlaying => playerStateNotifier.value == PlaybackState.playing;
  String? get currentlyPlayingFile => _currentlyPlayingFile;

  // StreamController for processed audio levels (e.g., for visualiser)
  final StreamController<double> _audioLevelController =
      StreamController.broadcast();
  Stream<double> get audioLevelStream => _audioLevelController.stream;

  // --- Player State --- //
  final ValueNotifier<PlaybackState> playerStateNotifier = ValueNotifier(
    PlaybackState.stopped,
  );
  final ValueNotifier<Duration> playerPositionNotifier = ValueNotifier(
    Duration.zero,
  );
  final ValueNotifier<Duration> playerDurationNotifier = ValueNotifier(
    Duration.zero,
  );
  String? _currentlyPlayingFile;

  AudioService() {
    _initialize();
  }

  Future<void> _initialize() async {
    if (initStateNotifier.value != AudioServiceInitState.idle)
      return; // Already init(ializing/ed)

    initStateNotifier.value = AudioServiceInitState.initializing;
    _initError = null;
    logger.info('AudioService: Initializing...');

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

      // Mark as initialized
      initStateNotifier.value = AudioServiceInitState.initialized;
      logger.info('AudioService: Initialization successful.');
    } catch (e, stack) {
      _initError = e.toString();
      initStateNotifier.value = AudioServiceInitState.error;
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
    _playerSubscription = _player.onProgress?.listen((e) {
      if (e != null) {
        playerPositionNotifier.value = e.position;
        playerDurationNotifier.value = e.duration;
      }
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
      // Initialize stream controller
      _recordingDataController = StreamController<Uint8List>();

      // Start Player first, waiting for data from the stream
      await _player.startPlayerFromStream(
        codec: _streamCodec,
        numChannels: _numChannels,
        sampleRate: _sampleRate,
        bufferSize: 4096, // Example buffer size
        interleaved: false, // Assuming non-interleaved PCM data
      );
      logger.info('AudioService: Player started, waiting for stream data...');

      // Start Recorder, feeding data into the stream controller
      await _recorder.startRecorder(
        toStream: _recordingDataController!.sink,
        codec: _streamCodec,
        sampleRate: _sampleRate,
        numChannels: _numChannels,
      );
      logger.info('AudioService: Recorder started, streaming to controller.');

      // Now manually pipe the stream data to the player's feed method
      _recordingDataSubscription = _recordingDataController!.stream.listen(
        (buffer) {
          // TODO: Apply filters/processing to `buffer` here if needed
          // final processedBuffer = _applyFiltersToBuffer(buffer);
          if (_player.isPlaying && _isPlayerInitialized) {
            _player.feedFromStream(buffer); // Feed buffer to player
            // _player.feedFromStream(processedBuffer); // Feed processed buffer
          }
        },
        onError: (e, stack) {
          logger.error(
            'AudioService: Error in recording stream',
            error: e,
            stackTrace: stack,
          );
          stopListening();
        },
        onDone: () {
          logger.info('AudioService: Recording stream controller closed.');
          stopListening(); // Stop session if recorder stream ends
        },
      );

      // TODO: Insert processing step here if not using direct feed
      // If complex filtering is needed:
      // 1. Recorder streams to `_rawAudioController`
      // 2. Listen to `_rawAudioController.stream`
      // 3. Process buffer (e.g., call FFMPEG)
      // 4. Add processed buffer to `_processedAudioController.sink`
      // 5. Player plays from `_processedAudioController.stream`

      // For now, we assume direct piping (or minimal processing)
      // We don't need the separate _recordingDataSubscription if piping directly

      // No need for placeholder file recording anymore
      // await _recorder.startRecorder(toFile: 'placeholder_output.aac');
    } catch (e, stack) {
      logger.error(
        'AudioService: Failed to start listening pipeline',
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
      // Stop recorder first to finish stream
      if (_recorder.isRecording) {
        await _recorder.stopRecorder();
        logger.info('AudioService: Recorder stopped.');
      }
      // Cancel subscription *before* closing controller
      await _recordingDataSubscription?.cancel();
      _recordingDataSubscription = null;
      // Close the stream controller
      await _recordingDataController?.close();
      _recordingDataController = null;
      logger.info('AudioService: Recording stream closed.');

      // Stop player
      if (_player.isPlaying) {
        await _player.stopPlayer();
        logger.info('AudioService: Player stopped.');
      }

      _audioLevelController.add(0.0); // Reset level visualizer
    } catch (e, stack) {
      logger.error(
        'AudioService: Failed to stop listening cleanly',
        error: e,
        stackTrace: stack,
      );
    }
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
    if (isPlaying || playerStateNotifier.value == PlaybackState.paused) {
      logger.info(
        'AudioService: Stopping current playback before starting new file.',
      );
      await stopPlayback(); // Stop previous playback completely
    }

    try {
      logger.info('AudioService: Starting playback for file: $filePath');
      await _player.startPlayer(
        fromURI: filePath,
        whenFinished: () {
          logger.info('AudioService: Playback finished for file: $filePath');
          // Reset state when playback completes naturally
          playerStateNotifier.value = PlaybackState.stopped;
          playerPositionNotifier.value = Duration.zero;
          _currentlyPlayingFile = null;
        },
      );
      playerStateNotifier.value = PlaybackState.playing;
      _currentlyPlayingFile = filePath;
    } catch (e, stack) {
      logger.error(
        'AudioService: Failed to play file $filePath',
        error: e,
        stackTrace: stack,
      );
      playerStateNotifier.value = PlaybackState.stopped; // Reset state on error
      _currentlyPlayingFile = null;
    }
  }

  /// Pauses the current playback.
  Future<void> pausePlayback() async {
    if (!isPlaying || !_isPlayerInitialized) return;
    try {
      await _player.pausePlayer();
      playerStateNotifier.value = PlaybackState.paused;
      logger.info('AudioService: Playback paused.');
    } catch (e, stack) {
      logger.error(
        'AudioService: Failed to pause player',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Resumes the paused playback.
  Future<void> resumePlayback() async {
    if (playerStateNotifier.value != PlaybackState.paused ||
        !_isPlayerInitialized)
      return;
    try {
      await _player.resumePlayer();
      playerStateNotifier.value = PlaybackState.playing;
      logger.info('AudioService: Playback resumed.');
    } catch (e, stack) {
      logger.error(
        'AudioService: Failed to resume player',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Stops the current playback completely.
  Future<void> stopPlayback() async {
    if (playerStateNotifier.value == PlaybackState.stopped ||
        !_isPlayerInitialized)
      return;
    try {
      await _player.stopPlayer();
      logger.info('AudioService: Playback stopped.');
    } catch (e, stack) {
      logger.error(
        'AudioService: Failed to stop player',
        error: e,
        stackTrace: stack,
      );
    }
    // Reset state regardless of error during stop
    playerStateNotifier.value = PlaybackState.stopped;
    playerPositionNotifier.value = Duration.zero;
    // Keep duration? playerDurationNotifier.value = Duration.zero;
    _currentlyPlayingFile = null;
  }

  /// Seeks to a specific position in the current playback.
  Future<void> seekPlayback(Duration position) async {
    if (playerStateNotifier.value == PlaybackState.stopped ||
        !_isPlayerInitialized)
      return;
    try {
      await _player.seekToPlayer(position);
      playerPositionNotifier.value = position; // Update position immediately
      logger.info('AudioService: Seeked to $position');
    } catch (e, stack) {
      logger.error('AudioService: Failed to seek', error: e, stackTrace: stack);
    }
  }

  /// Cleans up resources when the service is no longer needed.
  Future<void> dispose() async {
    logger.info('AudioService: Disposing...');
    await stopListening();
    await stopPlayback(); // Ensure playback is stopped
    await _recorderSubscription?.cancel();
    await _playerSubscription?.cancel();
    // Ensure controller is closed if stopListening failed somehow
    if (_recordingDataController?.isClosed == false) {
      await _recordingDataController?.close();
    }
    // Player/Recorder closed within stopListening or here if needed
    // await _player.closePlayer(); // Already called if stopListening works
    // await _recorder.closeRecorder(); // Already called if stopListening works
    await _audioLevelController.close();
    initStateNotifier.dispose();
    playerStateNotifier.dispose();
    playerPositionNotifier.dispose();
    playerDurationNotifier.dispose();
    logger.info('AudioService: Disposed.');
  }
}
