import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/logger.dart';
import '../viewmodel/settings_viewmodel.dart'; // For sharedPreferencesProvider

part 'settings_service.g.dart';

// Define keys for SharedPreferences
const String _keyMicSensitivity = 'settings_micSensitivity';
const String _keyGainBoost = 'settings_gainBoost';
const String _keyAutoTranscribe = 'settings_autoTranscribe';
const String _keyEnableWhisper = 'settings_enableWhisper';
const String _keyAutoSave = 'settings_autoSave';
const String _keyIsDarkMode = 'settings_isDarkMode';
const String _noiseSuppressionKey = 'noise_suppression_enabled';
const String _voiceBoostKey = 'voice_boost_enabled';

@Riverpod(keepAlive: true)
SettingsService settingsService(SettingsServiceRef ref) {
  // Depend on SharedPreferences finishing loading
  final prefs = ref.watch(sharedPreferencesProvider).requireValue;
  return SettingsService(prefs);
}

/// Service layer for managing persistent user settings.
class SettingsService {
  final SharedPreferences _prefs;

  SettingsService(this._prefs) {
    logger.info('SettingsService initialized with SharedPreferences.');
  }

  // --- Getters --- //

  double get micSensitivity => _prefs.getDouble(_keyMicSensitivity) ?? 0.6;
  double get gainBoost => _prefs.getDouble(_keyGainBoost) ?? 0.4;
  bool get autoTranscribe => _prefs.getBool(_keyAutoTranscribe) ?? true;
  bool get enableWhisper => _prefs.getBool(_keyEnableWhisper) ?? false;
  bool get autoSave => _prefs.getBool(_keyAutoSave) ?? true;
  bool get isDarkMode => _prefs.getBool(_keyIsDarkMode) ?? false;

  // --- Setters --- //

  set micSensitivity(double value) {
    _prefs.setDouble(_keyMicSensitivity, value);
    logger.info('Setting saved: Mic Sensitivity = $value');
  }

  set gainBoost(double value) {
    _prefs.setDouble(_keyGainBoost, value);
    logger.info('Setting saved: Gain Boost = $value');
  }

  set autoTranscribe(bool value) {
    _prefs.setBool(_keyAutoTranscribe, value);
    logger.info('Setting saved: Auto Transcribe = $value');
  }

  set enableWhisper(bool value) {
    _prefs.setBool(_keyEnableWhisper, value);
    logger.info('Setting saved: Enable Whisper = $value');
  }

  set autoSave(bool value) {
    _prefs.setBool(_keyAutoSave, value);
    logger.info('Setting saved: Auto Save = $value');
  }

  set isDarkMode(bool value) {
    _prefs.setBool(_keyIsDarkMode, value);
    logger.info('Setting saved: Is Dark Mode = $value');
  }

  // --- Filter Settings ---

  bool get noiseSuppressionEnabled =>
      _prefs.getBool(_noiseSuppressionKey) ?? false;
  set noiseSuppressionEnabled(bool value) =>
      _prefs.setBool(_noiseSuppressionKey, value);

  bool get voiceBoostEnabled => _prefs.getBool(_voiceBoostKey) ?? false;
  set voiceBoostEnabled(bool value) => _prefs.setBool(_voiceBoostKey, value);
}
