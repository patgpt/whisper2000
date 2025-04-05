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

  // --- Pipeline State --- //
  StreamController<Uint8List>?
  _processedAudioController; // Processed data for player
  StreamSubscription?
  _recordingProcessingSubscription; // Subscribes to raw data
  Set<AudioFilter> _activeFilters = {}; // Track currently active filters

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
      // Initialize stream controllers
      _recordingDataController =
          StreamController<
            Uint8List
          >.broadcast(); // Make broadcast if needed elsewhere
      _processedAudioController = StreamController<Uint8List>.broadcast();

      // Start Player, listening to the PROCESSED audio stream
      await _player.startPlayerFromStream(
        codec: _streamCodec,
        numChannels: _numChannels,
        sampleRate: _sampleRate,
        bufferSize: 2048,
        interleaved: true,
      );
      // Feed the player from the processed stream controller
      _playerSubscription = _processedAudioController!.stream.listen(
        (buffer) {
          if (_player.isPlaying && _isPlayerInitialized) {
            _player.feedFromStream(buffer);
          }
        },
        onError:
            (e, stack) => logger.error(
              'Player feed stream error',
              error: e,
              stackTrace: stack,
            ),
        onDone: () => logger.info('Processed audio stream done.'),
      );
      logger.info(
        'AudioService: Player started, listening to processed stream...',
      );

      // Start Recorder, feeding data into the RAW audio stream controller
      await _recorder.startRecorder(
        toStream: _recordingDataController!.sink,
        codec: _streamCodec,
        sampleRate: _sampleRate,
        numChannels: _numChannels,
        // Explicitly set bitrate for PCM16
        bitRate: 705600,
      );
      logger.info('AudioService: Recorder started, streaming raw data...');

      // Start processing the raw audio stream
      _recordingProcessingSubscription = _recordingDataController!.stream
          .listen(
            (buffer) async {
              // Log buffer size using info level
              logger.info(
                'Received buffer with size: ${buffer.lengthInBytes} bytes',
              );

              // Process the buffer (applies filters)
              final processedBuffer = await _processAudioBuffer(buffer);
              // Add processed buffer to the stream the player listens to
              if (_processedAudioController?.isClosed == false) {
                _processedAudioController!.add(processedBuffer);
              }
            },
            onError: (e, stack) {
              logger.error(
                'AudioService: Error in raw recording stream',
                error: e,
                stackTrace: stack,
              );
              stopListening(); // Stop pipeline on error
            },
            onDone: () {
              logger.info(
                'AudioService: Raw recording stream controller closed.',
              );
              // Signal end of stream to player?
              _processedAudioController?.close();
            },
          );
    } catch (e, stack) {
      logger.error(
        'AudioService: Failed to start listening pipeline',
        error: e,
        stackTrace: stack,
      );
      await stopListening();
    }
  }

  /// Placeholder method for processing a single audio buffer.
  /// This is where FFMPEG or other filter logic would be applied.
  Future<Uint8List> _processAudioBuffer(Uint8List rawBuffer) async {
    if (_activeFilters.isEmpty) {
      // No filters active, pass through raw buffer
      return rawBuffer;
    }

    // --- TODO: Implement FFMPEG processing --- //
    logger.info('Processing buffer with filters: ${_activeFilters.join(', ')}');

    // 1. Construct FFmpeg command based on _activeFilters.
    //    Example filter graph fragments:
    //    - Noise Reduction (using RNNoise via af=arnndn=m=path/to/model): Requires model file.
    //    - Noise Reduction (using af=afftdn): Simpler, built-in.
    //    - EQ/Voice Boost (using af=superequalizer=... or af=equalizer=...)
    String filterGraph = _buildFilterGraph();
    String command = ''; // Command needs input/output handling

    // 2. Execute FFmpeg.
    //    - Input: `rawBuffer`. How? FFmpeg needs a file or stdin.
    //      - Option A: Write rawBuffer to temp file, use file path as input.
    //      - Option B: Pipe rawBuffer to FFmpeg stdin (requires ffmpeg_kit support/config).
    //    - Output: Processed buffer. How?
    //      - Option A: FFmpeg writes to another temp file, read that file.
    //      - Option B: Read processed data from FFmpeg stdout.
    //    This I/O is the trickiest part for real-time performance.

    // Example using temp files (likely too slow for real-time, illustrates concept):
    /*
    try {
      final tempDir = await getTemporaryDirectory();
      final inputPath = p.join(tempDir.path, 'ffmpeg_in.pcm');
      final outputPath = p.join(tempDir.path, 'ffmpeg_out.pcm');
      await File(inputPath).writeAsBytes(rawBuffer, flush: true);

      // Construct command carefully (input format, filter graph, output format)
      // Example assuming raw PCM S16LE input/output
      command = '-f s16le -ar $_sampleRate -ac $_numChannels -i "$inputPath" -af "$filterGraph" -f s16le -ar $_sampleRate -ac $_numChannels "$outputPath" -y';
      logger.info('FFmpeg Command: $command');

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
         final processedBytes = await File(outputPath).readAsBytes();
         logger.info('FFmpeg processing successful, returning ${processedBytes.length} bytes.');
         await File(inputPath).delete(); // Clean up temps
         await File(outputPath).delete();
         return processedBytes;
      } else {
         logger.error('FFmpeg processing failed. Code: $returnCode');
         // Fallback: return raw buffer
         await File(inputPath).delete();
         return rawBuffer;
      }
    } catch (e, stack) {
       logger.error('Error during FFmpeg processing', error: e, stackTrace: stack);
       return rawBuffer; // Fallback
    }
    */

    // --- Placeholder: Return raw buffer until FFMPEG is implemented --- //
    return rawBuffer;
  }

  /// Helper to build the FFmpeg filter graph string based on active filters.
  String _buildFilterGraph() {
    List<String> filters = [];
    if (_activeFilters.contains(AudioFilter.noiseSuppression)) {
      // filters.add('afftdn'); // Example built-in NR
      filters.add(
        'arnndn=m=/path/to/rnnoise/model/file',
      ); // Example RNNoise (Needs model!)
      logger.info('Adding NR filter');
    }
    if (_activeFilters.contains(AudioFilter.voiceBoost)) {
      // filters.add('equalizer=f=1000:width_type=h:width=1000:g=6'); // Example EQ boost
      filters.add(
        'compand=attacks=0:points=-80/-900|-60/-60|-30/-30|0/-10|20/-10',
      ); // Basic compression/boost
      logger.info('Adding VB filter');
    }
    // Add other filters like directional based on state

    return filters.join(','); // Comma-separate filters in the graph
  }

  /// Stops the real-time audio processing pipeline.
  Future<void> stopListening() async {
    logger.info('AudioService: Stopping listening pipeline...');
    try {
      // Stop recorder first
      if (_recorder.isRecording) {
        await _recorder.stopRecorder();
        logger.info('AudioService: Recorder stopped.');
      }
      // Cancel processing subscription
      await _recordingProcessingSubscription?.cancel();
      _recordingProcessingSubscription = null;
      // Close raw recording controller
      await _recordingDataController?.close();
      _recordingDataController = null;
      logger.info('AudioService: Raw recording stream closed.');
      // Close processed controller (might happen onDone, but close here for safety)
      await _processedAudioController?.close();
      _processedAudioController = null;
      logger.info('AudioService: Processed audio stream closed.');

      // Stop player
      if (_player.isPlaying) {
        await _player.stopPlayer();
        logger.info('AudioService: Player stopped.');
      }

      // Reset levels
      _audioLevelController.add(0.0);
    } catch (e, stack) {
      logger.error(
        'AudioService: Failed to stop listening cleanly',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Applies the specified audio filters to the pipeline.
  Future<void> applyFilters(Set<AudioFilter> activeFilters) async {
    // Simply store the active filters. The processing loop will use them.
    _activeFilters = activeFilters;
    logger.info(
      'AudioService: Active filters updated: ${_activeFilters.join(', ')}',
    );
    // Note: If FFmpeg requires restarting the process on filter change,
    // more complex logic is needed here (e.g., stop/start pipeline or session).
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
    await stopListening(); // Should close controllers and cancel subs
    // Cancel any remaining subscriptions just in case
    await _recorderSubscription?.cancel();
    await _playerSubscription?.cancel();
    await _recordingProcessingSubscription?.cancel();
    // Close controllers if somehow still open
    await _recordingDataController?.close();
    await _processedAudioController?.close();
    await _audioLevelController.close();
    initStateNotifier.dispose();
    playerStateNotifier.dispose();
    playerPositionNotifier.dispose();
    playerDurationNotifier.dispose();
    logger.info('AudioService: Disposed.');
  }
}
