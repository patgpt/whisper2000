import 'package:riverpod_annotation/riverpod_annotation.dart';

// Use our custom logger
import '../../../core/utils/logger.dart';

part 'home_viewmodel.g.dart';

// Define listening modes here
enum ListeningMode { speechBoost, whisperMode, safeListen }

// State class
class HomeState {
  final bool isListening; // Could reflect AudioService state if needed
  final ListeningMode selectedMode;

  const HomeState({
    this.isListening = false,
    this.selectedMode = ListeningMode.speechBoost, // Default mode
  });

  HomeState copyWith({bool? isListening, ListeningMode? selectedMode}) {
    return HomeState(
      isListening: isListening ?? this.isListening,
      selectedMode: selectedMode ?? this.selectedMode,
    );
  }
}

// ViewModel (Notifier)
@riverpod
class HomeViewModel extends _$HomeViewModel {
  // No need for local logger instance if using global one

  @override
  HomeState build() {
    // Initialize state
    // Could potentially read initial mode from settings service
    return const HomeState();
  }

  void setSelectedMode(ListeningMode mode) {
    state = state.copyWith(selectedMode: mode);
    // Use global logger instance
    logger.info('HomeViewModel: Mode selected - $mode');
    // TODO: Communicate selected mode to AudioService or relevant service
    // This might involve configuring parameters before starting listening
    // or calling a method on LiveListeningService/AudioService.
    // Example:
    // final liveListeningService = ref.read(liveListeningServiceProvider);
    // liveListeningService.setListeningModeConfiguration(mode);
    if (mode == ListeningMode.whisperMode) {
      logger.info(
        'Whisper Mode selected - specific audio configuration needed.',
      );
      // The actual application of Whisper Mode settings would happen
      // when startListening is called, potentially using different filters.
    }
  }

  void setListeningState(bool listening) {
    state = state.copyWith(isListening: listening);
  }
}
