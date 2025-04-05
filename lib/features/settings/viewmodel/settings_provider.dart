import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 1. Define the state class
class SettingsState {
  final double micSensitivity;
  final double gainBoost;
  final bool autoTranscribe;
  final bool enableWhisper;
  final bool autoSave;
  final bool isDarkMode;

  // Add key for persistence
  static const String _darkModeKey = 'isDarkMode';

  SettingsState({
    this.micSensitivity = 0.6,
    this.gainBoost = 0.4,
    this.autoTranscribe = true,
    this.enableWhisper = false,
    this.autoSave = true,
    this.isDarkMode = false,
  });

  SettingsState copyWith({
    double? micSensitivity,
    double? gainBoost,
    bool? autoTranscribe,
    bool? enableWhisper,
    bool? autoSave,
    bool? isDarkMode,
  }) {
    return SettingsState(
      micSensitivity: micSensitivity ?? this.micSensitivity,
      gainBoost: gainBoost ?? this.gainBoost,
      autoTranscribe: autoTranscribe ?? this.autoTranscribe,
      enableWhisper: enableWhisper ?? this.enableWhisper,
      autoSave: autoSave ?? this.autoSave,
      isDarkMode: isDarkMode ?? this.isDarkMode,
    );
  }
}

// 2. Create the Notifier
class SettingsNotifier extends StateNotifier<SettingsState> {
  // Pass SharedPreferences instance (will be provided by the provider)
  final SharedPreferences _prefs;

  SettingsNotifier(this._prefs) : super(SettingsState()) {
    _loadSettings(); // Load settings on initialization
  }

  // Load initial settings from SharedPreferences
  void _loadSettings() {
    final isDarkMode = _prefs.getBool(SettingsState._darkModeKey) ?? false;
    // Load other settings if they were persisted
    state = state.copyWith(isDarkMode: isDarkMode);
  }

  void setMicSensitivity(double value) {
    state = state.copyWith(micSensitivity: value);
    // _prefs.setDouble('micSensitivity', value); // Example persistence
  }

  void setGainBoost(double value) {
    state = state.copyWith(gainBoost: value);
    // _prefs.setDouble('gainBoost', value); // Example persistence
  }

  void setAutoTranscribe(bool value) {
    state = state.copyWith(autoTranscribe: value);
    // _prefs.setBool('autoTranscribe', value); // Example persistence
  }

  void setEnableWhisper(bool value) {
    state = state.copyWith(enableWhisper: value);
    // _prefs.setBool('enableWhisper', value); // Example persistence
  }

  void setAutoSave(bool value) {
    state = state.copyWith(autoSave: value);
    // _prefs.setBool('autoSave', value); // Example persistence
  }

  void setDarkMode(bool value) {
    state = state.copyWith(isDarkMode: value);
    _prefs.setBool(SettingsState._darkModeKey, value); // Persist the value
  }
}

// Provider for SharedPreferences (loads asynchronously)
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((
  ref,
) async {
  return await SharedPreferences.getInstance();
});

// 3. Update the Settings Provider to depend on SharedPreferences
final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) {
    // Watch the FutureProvider. When it resolves, this provider will rebuild.
    final prefs = ref.watch(sharedPreferencesProvider).asData?.value;

    // Handle loading state or error state if needed
    if (prefs == null) {
      // Return a default notifier or handle loading state appropriately
      // For simplicity, we might return a notifier with default state,
      // but it won't have persistence until prefs load.
      // A better approach might involve a loading state in SettingsState.
      // Or using .when() on the future provider in the UI.
      throw Exception(
        "SharedPreferences not loaded",
      ); // Or return default state notifier
    }

    return SettingsNotifier(prefs);
  },
);
