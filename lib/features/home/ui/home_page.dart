import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../widgets/listening_mode_toggle.dart';
import '../../../widgets/waveform_visualizer.dart';
import '../../live_listening/ui/live_listening_page.dart';
import '../../live_listening/viewmodel/live_listening_viewmodel.dart';
import '../viewmodel/home_viewmodel.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeState = ref.watch(homeViewModelProvider);
    final homeViewModel = ref.read(homeViewModelProvider.notifier);
    final listeningViewModel = ref.read(
      liveListeningViewModelProvider.notifier,
    );

    void navigateToLiveListening() {
      listeningViewModel.startListening();
      Navigator.of(context).push(
        CupertinoPageRoute(builder: (context) => const LiveListeningPage()),
      );
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
              const Center(child: WaveformVisualizer(isActive: false)),
              const SizedBox(height: 40),
              CupertinoButton.filled(
                onPressed: navigateToLiveListening,
                child: const Text('Start Listening'),
              ),
              const SizedBox(height: 30),
              ListeningModeToggle(
                selectedMode: homeState.selectedMode,
                onChanged: (ListeningMode? mode) {
                  if (mode != null) {
                    homeViewModel.setSelectedMode(mode);
                  }
                },
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
