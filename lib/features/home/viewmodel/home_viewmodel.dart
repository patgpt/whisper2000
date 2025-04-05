import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

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
  @override
  HomeState build() {
    // Initialize state
    // Could potentially read initial mode from settings service
    return const HomeState();
  }

  void setSelectedMode(ListeningMode mode) {
    state = state.copyWith(selectedMode: mode);
    // TODO: Communicate selected mode to AudioService or relevant service
    // ref.read(audioServiceProvider).setListeningMode(mode);
  }

  void setListeningState(bool listening) {
    state = state.copyWith(isListening: listening);
  }
}
