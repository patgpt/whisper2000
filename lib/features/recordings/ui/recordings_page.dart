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
            Widget messageWidget;
            bool transcriptionComplete = false;
            bool canTranscribe = true; // Assume possible initially

            if (snapshot.connectionState == ConnectionState.waiting) {
              messageWidget = const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: CupertinoActivityIndicator(),
              );
              canTranscribe = false; // Don't allow trigger while loading
            } else if (snapshot.hasError) {
              messageWidget = Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: CupertinoColors.systemRed),
                textAlign: TextAlign.center,
              );
            } else if (snapshot.hasData &&
                snapshot.data != null &&
                !snapshot.data!.startsWith('[')) {
              // Success and not an error placeholder
              messageWidget = Text(snapshot.data!, textAlign: TextAlign.center);
              transcriptionComplete = true;
              canTranscribe = false; // Already transcribed
            } else {
              // No data, or it's an error placeholder like "[Transcription Failed]"
              messageWidget = Text(
                snapshot.data ?? 'No transcript available.',
                textAlign: TextAlign.center,
              );
              // Allow retrying transcription if it failed or hasn't run
              canTranscribe = true;
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
                  // Use the widget built above
                  messageWidget,
                ],
              ),
              actions: <CupertinoActionSheetAction>[
                CupertinoActionSheetAction(
                  // Disable if transcription is done or loading
                  isDefaultAction: canTranscribe,
                  onPressed:
                      canTranscribe
                          ? () {
                            viewModel.transcribeRecording(recording.id);
                            Navigator.pop(context);
                            // Optionally show a temp message "Transcription started..."
                          }
                          : () {}, // Provide empty non-null callback when disabled
                  child: Text(
                    transcriptionComplete
                        ? 'Transcription Complete'
                        : 'Transcribe',
                  ),
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
