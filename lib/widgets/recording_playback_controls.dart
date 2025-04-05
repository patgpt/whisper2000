import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/audio/audio_service.dart';
import '../core/utils/logger.dart';

/// Formats a Duration into MM:SS or HH:MM:SS format.
String formatDuration(Duration duration) {
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);

  final minutesStr = twoDigits(minutes);
  final secondsStr = twoDigits(seconds);

  if (hours > 0) {
    final hoursStr = twoDigits(hours);
    return '$hoursStr:$minutesStr:$secondsStr';
  } else {
    return '$minutesStr:$secondsStr';
  }
}

class RecordingPlaybackControls extends ConsumerStatefulWidget {
  final String recordingId; // To identify which recording we are controlling
  final String filePath; // File to play

  const RecordingPlaybackControls({
    super.key,
    required this.recordingId,
    required this.filePath,
  });

  @override
  ConsumerState<RecordingPlaybackControls> createState() =>
      _RecordingPlaybackControlsState();
}

class _RecordingPlaybackControlsState
    extends ConsumerState<RecordingPlaybackControls> {
  late AudioService _audioService;
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _positionSubscription;

  PlaybackState _currentState = PlaybackState.stopped;
  Duration _currentPosition = Duration.zero;
  Duration _currentDuration = Duration.zero;

  // Store callbacks to remove in dispose
  final List<VoidCallback> _callbacksToRemove = [];

  @override
  void initState() {
    super.initState();
    _audioService = ref.read(audioServiceProvider);

    // Check initial state
    _updateStateFromService();

    // Listen to state changes from the service
    // Using listenManual for ValueNotifiers
    _playerStateSubscription = _listenToNotifier<PlaybackState>(
      _audioService.playerStateNotifier,
      (state) {
        if (mounted) {
          _updateStateFromService(); // Re-sync if state changes externally
        }
      },
    );
    _positionSubscription = _listenToNotifier<Duration>(
      _audioService.playerPositionNotifier,
      (position) {
        if (mounted && _currentState != PlaybackState.stopped) {
          setState(() {
            _currentPosition = position;
          });
        }
      },
    );
    // No need to listen to duration notifier usually, it updates once
  }

  // Helper to listen to ValueNotifier and manage subscription
  StreamSubscription _listenToNotifier<T>(
    ValueNotifier<T> notifier,
    ValueChanged<T> listener,
  ) {
    final controller = StreamController<T>();
    void callback() {
      // Ensure controller isn't closed before adding
      if (!controller.isClosed) {
        controller.add(notifier.value);
      }
    }

    notifier.addListener(callback);
    // Store the callback to remove it later
    final removeListenerCallback = () => notifier.removeListener(callback);
    // Cleanup happens in dispose using the returned subscription and the callback remover
    final subscription = controller.stream.listen(listener);
    // Return a combined object or manage separately
    // For simplicity, manage callback removal in dispose
    _callbacksToRemove.add(removeListenerCallback);
    return subscription;
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
    // Remove listeners
    for (final callback in _callbacksToRemove) {
      callback();
    }
    _callbacksToRemove.clear();

    // Optional: Stop playback if this widget initiated it and is still playing
    if (_audioService.currentlyPlayingFile == widget.filePath &&
        _audioService.playerStateNotifier.value != PlaybackState.stopped) {
      logger.info(
        'PlaybackControls dispose: Stopping playback for ${widget.filePath}',
      );
      _audioService.stopPlayback();
    }
    super.dispose();
  }

  void _updateStateFromService() {
    // Update local state only if this widget's file is the one being controlled
    if (_audioService.currentlyPlayingFile == widget.filePath) {
      setState(() {
        _currentState = _audioService.playerStateNotifier.value;
        _currentPosition = _audioService.playerPositionNotifier.value;
        _currentDuration = _audioService.playerDurationNotifier.value;
      });
    } else {
      // If service is playing a *different* file, reset this widget's state
      setState(() {
        _currentState = PlaybackState.stopped;
        _currentPosition = Duration.zero;
        _currentDuration = Duration.zero;
      });
    }
  }

  void _handlePlayPause() {
    if (_currentState == PlaybackState.playing) {
      _audioService.pausePlayback();
    } else if (_currentState == PlaybackState.paused) {
      _audioService.resumePlayback();
    } else {
      // Stopped
      _audioService.playFile(widget.filePath);
    }
    // State update will come via listener
  }

  void _handleSeek(double value) {
    final newPosition = Duration(milliseconds: value.toInt());
    _audioService.seekPlayback(newPosition);
    // Optimistically update slider position
    setState(() {
      _currentPosition = newPosition;
    });
  }

  @override
  Widget build(BuildContext context) {
    final maxMilliseconds = _currentDuration.inMilliseconds.toDouble();
    final currentMilliseconds = _currentPosition.inMilliseconds
        .toDouble()
        .clamp(0.0, maxMilliseconds);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _handlePlayPause,
              child: Icon(
                _currentState == PlaybackState.playing
                    ? CupertinoIcons.pause_fill
                    : CupertinoIcons.play_fill,
                size: 36.0,
              ),
            ),
            // TODO: Add Stop button?
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Text(formatDuration(_currentPosition)),
              Expanded(
                child: CupertinoSlider(
                  value: currentMilliseconds,
                  min: 0.0,
                  max:
                      maxMilliseconds > 0
                          ? maxMilliseconds
                          : 1.0, // Avoid max=0
                  //divisions: maxMilliseconds > 0 ? maxMilliseconds ~/ 1000 : null, // Optional divisions
                  onChangeEnd: _handleSeek, // Seek when user releases slider
                  onChanged: (value) {
                    // Optional: Update time display while sliding
                    setState(() {
                      _currentPosition = Duration(milliseconds: value.toInt());
                    });
                  },
                ),
              ),
              Text(formatDuration(_currentDuration)),
            ],
          ),
        ),
      ],
    );
  }
}
