import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../../core/audio/audio_service.dart';
import '../../../widgets/recording_card.dart';
import '../../../widgets/recording_playback_controls.dart';
import '../viewmodel/recordings_viewmodel.dart';

part 'recordings_page.g.dart';

@HiveType(typeId: 0)
class Recording {
  @HiveField(0)
  final String title;
  @HiveField(1)
  final DateTime dateTime;
  @HiveField(2)
  final String preview;
  @HiveField(3)
  final String id;
  @HiveField(4)
  final String filePath;
  @HiveField(5)
  final String? transcript;

  Recording({
    required this.id,
    required this.title,
    required this.dateTime,
    required this.preview,
    required this.filePath,
    this.transcript,
  });

  Recording copyWith({
    String? id,
    String? title,
    DateTime? dateTime,
    String? preview,
    String? filePath,
    String? transcript,
    bool setTranscriptNull = false,
  }) {
    return Recording(
      id: id ?? this.id,
      title: title ?? this.title,
      dateTime: dateTime ?? this.dateTime,
      preview: preview ?? this.preview,
      filePath: filePath ?? this.filePath,
      transcript: setTranscriptNull ? null : (transcript ?? this.transcript),
    );
  }
}

class RecordingsPage extends ConsumerWidget {
  const RecordingsPage({super.key});

  void _showRecordingDetails(
    BuildContext context,
    WidgetRef ref,
    Recording recording,
  ) {
    final viewModel = ref.read(recordingsViewModelProvider.notifier);

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return FutureBuilder<String?>(
          future: viewModel.getTranscript(recording.id),
          builder: (context, snapshot) {
            String displayMessage;
            if (snapshot.connectionState == ConnectionState.waiting) {
              displayMessage = 'Loading transcript...';
            } else if (snapshot.hasError) {
              displayMessage = 'Error loading transcript: ${snapshot.error}';
            } else if (snapshot.hasData && snapshot.data != null) {
              displayMessage = snapshot.data!;
            } else {
              displayMessage = 'No transcript available.';
            }

            return CupertinoActionSheet(
              title: Text(recording.title),
              message: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RecordingPlaybackControls(
                    key: ValueKey(recording.id),
                    recordingId: recording.id,
                    filePath: recording.filePath,
                  ),
                  const SizedBox(height: 15),
                  Text(displayMessage, textAlign: TextAlign.center),
                ],
              ),
              actions: <CupertinoActionSheetAction>[
                CupertinoActionSheetAction(
                  child: const Text('Transcribe'),
                  onPressed: () {
                    viewModel.transcribeRecording(recording.id);
                    Navigator.pop(context);
                  },
                ),
                CupertinoActionSheetAction(
                  isDestructiveAction: true,
                  child: const Text('Delete'),
                  onPressed: () {
                    Navigator.pop(context);
                    viewModel.deleteRecording(recording.id);
                  },
                ),
              ],
              cancelButton: CupertinoActionSheetAction(
                child: const Text('Cancel'),
                onPressed: () {
                  ref.read(audioServiceProvider).stopPlayback();
                  Navigator.pop(context);
                },
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordings = ref.watch(recordingsViewModelProvider);

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Recordings')),
      child:
          recordings.isEmpty
              ? const Center(child: Text('No recordings yet.'))
              : ListView.builder(
                itemCount: recordings.length,
                itemBuilder: (context, index) {
                  final recording = recordings[index];
                  return RecordingCard(
                    recording: recording,
                    onDelete: () {
                      ref
                          .read(recordingsViewModelProvider.notifier)
                          .deleteRecording(recording.id);
                    },
                    onTap: () => _showRecordingDetails(context, ref, recording),
                  );
                },
              ),
    );
  }
}
