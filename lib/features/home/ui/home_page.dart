import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/audio_service.dart';
import '../../../widgets/listening_mode_toggle.dart';
import '../../../widgets/waveform_visualizer.dart';
import '../../live_listening/ui/live_listening_page.dart';
import '../../live_listening/viewmodel/live_listening_viewmodel.dart';
import '../../settings/viewmodel/settings_viewmodel.dart';
import '../viewmodel/home_viewmodel.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeState = ref.watch(homeViewModelProvider);
    final homeViewModel = ref.read(homeViewModelProvider.notifier);
    final liveState = ref.watch(liveListeningViewModelProvider);
    final liveViewModel = ref.read(liveListeningViewModelProvider.notifier);
    final settingsState = ref.watch(settingsViewModelProvider);
    final settingsViewModel = ref.read(settingsViewModelProvider.notifier);
    final audioService = ref.read(audioServiceProvider);

    // Determine button/UI state based on audio service init state
    final bool canStartListening =
        liveState.audioInitState == AudioServiceInitState.initialized;
    final bool isInitializing =
        liveState.audioInitState == AudioServiceInitState.initializing;
    final String? initError = liveState.audioInitError;

    void navigateToLiveListening() {
      if (!canStartListening || liveState.isListening) return; // Guard clause

      // Apply initial filters based on settings *before* starting
      Set<AudioFilter> initialFilters = {};
      if (settingsState.enableNoiseSuppression) {
        initialFilters.add(AudioFilter.noiseSuppression);
      }
      if (settingsState.enableVoiceBoost) {
        initialFilters.add(AudioFilter.voiceBoost);
      }
      audioService.applyFilters(initialFilters);

      liveViewModel.startListening(); // Now start with filters applied

      Navigator.of(context).push(
        CupertinoPageRoute(builder: (context) => const LiveListeningPage()),
      );
    }

    // Helper to update audio service filters based on current settings state
    void _updateAudioFilters(WidgetRef ref) {
      // Read the latest settings state directly
      final currentSettings = ref.read(settingsViewModelProvider);
      Set<AudioFilter> activeFilters = {};
      if (currentSettings.enableNoiseSuppression) {
        activeFilters.add(AudioFilter.noiseSuppression);
      }
      if (currentSettings.enableVoiceBoost) {
        activeFilters.add(AudioFilter.voiceBoost);
      }
      audioService.applyFilters(activeFilters);
    }

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('EchoGhost')),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Show Initializing or Error state
              if (isInitializing)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: Center(child: CupertinoActivityIndicator()),
                ),
              if (initError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: Center(
                    child: Text(
                      'Audio Error: $initError',
                      style: TextStyle(
                        color:
                            CupertinoTheme.of(context).brightness ==
                                    Brightness.dark
                                ? CupertinoColors.systemRed.darkColor
                                : CupertinoColors.systemRed.color,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

              // Show visualizer only when initialized
              if (canStartListening)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: Center(
                    child: WaveformVisualizer(
                      isActive: liveState.isListening,
                      level: liveState.waveformLevel,
                    ),
                  ),
                ),

              // Spacer to push button/toggles down if visualizer isn't showing
              if (!canStartListening) const Spacer(),

              const SizedBox(height: 40),
              // Disable button if not initialized or already listening
              CupertinoButton.filled(
                onPressed:
                    canStartListening && !liveState.isListening
                        ? navigateToLiveListening
                        : null,
                child: Text(
                  liveState.isListening ? 'Listening...' : 'Start Listening',
                ),
              ),
              const SizedBox(height: 30),
              // Disable toggles if audio isn't ready
              AbsorbPointer(
                absorbing: !canStartListening,
                child: Opacity(
                  opacity: canStartListening ? 1.0 : 0.5,
                  child: Column(
                    // Use Column to stack toggles
                    children: [
                      ListeningModeToggle(
                        selectedMode: homeState.selectedMode,
                        onChanged: (ListeningMode? mode) {
                          if (mode != null) {
                            homeViewModel.setSelectedMode(mode);
                          }
                        },
                      ),
                      const SizedBox(height: 15), // Spacing
                      // Noise Suppression Toggle
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Noise Suppression'),
                          CupertinoSwitch(
                            value: settingsState.enableNoiseSuppression,
                            onChanged: (bool value) {
                              settingsViewModel.setNoiseSuppression(value);
                              // Update filters in AudioService
                              _updateAudioFilters(ref);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10), // Spacing
                      // Voice Boost Toggle
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Voice Boost'),
                          CupertinoSwitch(
                            value: settingsState.enableVoiceBoost,
                            onChanged: (bool value) {
                              settingsViewModel.setVoiceBoost(value);
                              // Update filters in AudioService
                              _updateAudioFilters(ref);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
