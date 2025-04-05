import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/logger.dart';
import '../../recordings/services/recordings_service.dart';
import '../services/settings_service.dart';

part 'settings_viewmodel.g.dart';

// Re-use state class definition
class SettingsState {
  final double micSensitivity;
  final double gainBoost;
  final bool autoTranscribe;
  final bool enableWhisper;
  final bool autoSave;
  final bool isDarkMode;

  // Make constructor const
  const SettingsState({
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

// Provider for SharedPreferences (can stay here or move to core)
// Keep it simple here for now
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((
  ref,
) async {
  logger.info("Loading SharedPreferences...");
  final prefs = await SharedPreferences.getInstance();
  logger.info("SharedPreferences loaded.");
  return prefs;
});

@Riverpod(keepAlive: true) // Keep settings loaded
class SettingsViewModel extends _$SettingsViewModel {
  late final SettingsService _settingsService;
  late final RecordingsService _recordingsService;

  @override
  SettingsState build() {
    _settingsService = ref.watch(settingsServiceProvider);
    _recordingsService = ref.watch(recordingsServiceProvider);

    // Load initial state from the service
    final initialState = SettingsState(
      micSensitivity: _settingsService.micSensitivity,
      gainBoost: _settingsService.gainBoost,
      autoTranscribe: _settingsService.autoTranscribe,
      enableWhisper: _settingsService.enableWhisper,
      autoSave: _settingsService.autoSave,
      isDarkMode: _settingsService.isDarkMode,
    );
    // Sync initial auto-save state with RecordingsService
    // Do this *after* initial state is set to avoid race conditions
    // Using Future.microtask ensures it runs after build completes
    Future.microtask(
      () => _recordingsService.setAutoBufferingEnabled(initialState.autoSave),
    );
    return initialState;
  }

  // Methods update state and call service to persist
  void setMicSensitivity(double value) {
    state = state.copyWith(micSensitivity: value);
    _settingsService.micSensitivity = value;
  }

  void setGainBoost(double value) {
    state = state.copyWith(gainBoost: value);
    _settingsService.gainBoost = value;
  }

  void setAutoTranscribe(bool value) {
    state = state.copyWith(autoTranscribe: value);
    _settingsService.autoTranscribe = value;
  }

  void setEnableWhisper(bool value) {
    state = state.copyWith(enableWhisper: value);
    _settingsService.enableWhisper = value;
  }

  void setAutoSave(bool value) {
    state = state.copyWith(autoSave: value);
    _settingsService.autoSave = value;
    // Call RecordingsService to enable/disable buffering
    _recordingsService.setAutoBufferingEnabled(value);
  }

  void setDarkMode(bool value) {
    state = state.copyWith(isDarkMode: value);
    _settingsService.isDarkMode = value;
    // UI theme updates automatically via MyApp watching this provider state
  }
}
