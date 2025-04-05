import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../widgets/waveform_visualizer.dart';
import '../viewmodel/live_listening_viewmodel.dart';

// Convert to ConsumerWidget
class LiveListeningPage extends ConsumerWidget {
  const LiveListeningPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use the new viewmodel provider name
    final liveState = ref.watch(liveListeningViewModelProvider);
    final liveViewModel = ref.read(liveListeningViewModelProvider.notifier);

    // Handle stopping listening when leaving the page
    // Note: This is a simple approach. More robust handling might be needed.
    // Consider using WidgetsBindingObserver or autoDispose for the provider
    // if cleanup needs to happen more reliably.
    // useEffect hook from flutter_hooks could also manage this.

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Live Listening'),
        // Add a leading back button that also stops listening
        leading: CupertinoNavigationBarBackButton(
          onPressed: () {
            liveViewModel.stopListening();
            Navigator.of(context).pop();
          },
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: 20),
              Center(
                child: Text(
                  liveState.isListening ? 'Currently Listening' : 'Stopped',
                  style: CupertinoTheme.of(context).textTheme.navTitleTextStyle,
                ),
              ),
              const SizedBox(height: 40),
              // Animated waveform or mic icon placeholder
              Center(
                child: WaveformVisualizer(
                  isActive: liveState.isListening,
                  level: liveState.waveformLevel,
                ),
              ),
              const SizedBox(height: 40),
              // Output Volume Meter
              const Text('Output Volume'),
              CupertinoSlider(
                value: liveState.outputVolume,
                min: 0.0,
                max: 1.0,
                onChanged: liveViewModel.setOutputVolume,
              ),
              const SizedBox(height: 30),
              _buildToggleSwitch(
                'Noise Suppression',
                liveState.noiseSuppression,
                liveViewModel.setNoiseSuppression,
              ),
              _buildToggleSwitch(
                'Voice Boost',
                liveState.voiceBoost,
                liveViewModel.setVoiceBoost,
              ),
              _buildToggleSwitch(
                'Directional Mode',
                liveState.directionalMode,
                liveViewModel.setDirectionalMode,
              ),
              const Spacer(),
              CupertinoButton(
                color: CupertinoColors.destructiveRed,
                // Use viewmodel method to stop
                onPressed: () {
                  liveViewModel.stopListening();
                  Navigator.of(context).pop(); // Also navigate back
                },
                child: const Text('Stop Listening'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleSwitch(
    String title,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title),
          CupertinoSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
