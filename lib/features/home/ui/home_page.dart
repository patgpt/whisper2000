import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../widgets/listening_mode_toggle.dart';
import '../../../widgets/waveform_visualizer.dart';
import '../../live_listening/ui/live_listening_page.dart';
import '../../live_listening/viewmodel/listening_state_provider.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

enum ListeningMode { speechBoost, whisperMode, safeListen }

class _HomePageState extends ConsumerState<HomePage> {
  ListeningMode _selectedMode = ListeningMode.speechBoost;

  void _navigateToLiveListening() {
    ref.read(listeningStateProvider.notifier).startListening();
    Navigator.of(
      context,
    ).push(CupertinoPageRoute(builder: (context) => const LiveListeningPage()));
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Whisper 2000')),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Placeholder for Waveform Animation
              const Center(
                child:
                    WaveformVisualizer(), // TODO: Connect to listening state?
              ),
              const SizedBox(height: 40),
              CupertinoButton.filled(
                onPressed: _navigateToLiveListening,
                child: const Text('Start Listening'),
              ),
              const SizedBox(height: 30),
              ListeningModeToggle(
                selectedMode: _selectedMode,
                onChanged: (ListeningMode? mode) {
                  if (mode != null) {
                    setState(() {
                      _selectedMode = mode;
                      // TODO: Potentially update a provider for the selected mode
                    });
                  }
                },
              ),
              // Add more UI elements as needed
              const Spacer(), // Pushes elements to center/top
            ],
          ),
        ),
      ),
    );
  }
}
