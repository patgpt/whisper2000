import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'; // Import for kIsWeb, defaultTargetPlatform
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../viewmodel/settings_provider.dart';

// Convert to ConsumerWidget
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Add WidgetRef
    // Read the state and the notifier
    final settingsState = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    // Determine horizontal padding based on platform
    final isDesktop =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.windows);
    final horizontalPadding = isDesktop ? 40.0 : 16.0;

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Settings')),
      child: SafeArea(
        child: Padding(
          // Apply adaptive horizontal padding
          padding: EdgeInsets.symmetric(
            vertical: 16.0,
            horizontal: horizontalPadding,
          ),
          child: Column(
            children: <Widget>[
              _buildSliderSection(
                context,
                label: 'Mic Sensitivity',
                // Read value from state
                value: settingsState.micSensitivity,
                onChanged: (value) {
                  // Call notifier method
                  settingsNotifier.setMicSensitivity(value);
                },
              ),
              _buildSliderSection(
                context,
                label: 'Gain Boost',
                // Read value from state
                value: settingsState.gainBoost,
                onChanged: (value) {
                  // Call notifier method
                  settingsNotifier.setGainBoost(value);
                },
              ),
              const SizedBox(height: 20),
              _buildSwitchTile(
                context,
                label: 'Auto Transcribe Recordings',
                // Read value from state
                value: settingsState.autoTranscribe,
                onChanged: (value) {
                  // Call notifier method
                  settingsNotifier.setAutoTranscribe(value);
                },
              ),
              _buildSwitchTile(
                context,
                label: 'Enable Whisper Mode Feature',
                // Read value from state
                value: settingsState.enableWhisper,
                onChanged: (value) {
                  // Call notifier method
                  settingsNotifier.setEnableWhisper(value);
                },
              ),
              _buildSwitchTile(
                context,
                label: 'Auto Save Last 30 Seconds',
                // Read value from state
                value: settingsState.autoSave,
                onChanged: (value) {
                  // Call notifier method
                  settingsNotifier.setAutoSave(value);
                },
              ),
              const SizedBox(height: 20),
              _buildSwitchTile(
                context,
                label: 'Dark Mode',
                // Read value from state
                value: settingsState.isDarkMode,
                onChanged: (value) {
                  // Call notifier method
                  settingsNotifier.setDarkMode(value);
                  // TODO: Implement actual theme change logic
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliderSection(
    BuildContext context, {
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    final isDesktop =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.windows);
    final horizontalPadding = isDesktop ? 40.0 : 16.0;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 8.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 4),
          CupertinoSlider(
            value: value,
            min: 0.0,
            max: 1.0,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final isDesktop =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.windows);
    final horizontalPadding = isDesktop ? 40.0 : 16.0;

    return Container(
      color: CupertinoTheme.of(context).barBackgroundColor,
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 12.0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          CupertinoSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
