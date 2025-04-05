import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../../widgets/recording_card.dart';
import '../viewmodel/recording_provider.dart';

part 'recordings_page.g.dart';

@HiveType(typeId: 0)
class Recording {
  @HiveField(0)
  final String title;
  @HiveField(1)
  final DateTime dateTime;
  @HiveField(2)
  final String preview;

  Recording({
    required this.title,
    required this.dateTime,
    required this.preview,
  });
}

class RecordingsPage extends ConsumerWidget {
  const RecordingsPage({super.key});

  void _showRecordingDetails(
    BuildContext context,
    WidgetRef ref,
    Recording recording,
  ) {
    final recordingNotifier = ref.read(recordingProvider.notifier);

    showCupertinoModalPopup(
      context: context,
      builder:
          (BuildContext context) => CupertinoActionSheet(
            title: Text(recording.title),
            message: Text(
              'Full transcript would appear here.\n${recording.preview}...',
            ),
            actions: <CupertinoActionSheetAction>[
              CupertinoActionSheetAction(
                child: const Text('Play'),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
              CupertinoActionSheetAction(
                isDestructiveAction: true,
                child: const Text('Delete'),
                onPressed: () {
                  Navigator.pop(context);
                  recordingNotifier.deleteRecordingByKey(
                    recording.dateTime.toIso8601String(),
                  );
                },
              ),
            ],
            cancelButton: CupertinoActionSheetAction(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordings = ref.watch(recordingProvider);

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Recordings')),
      child: ListView.builder(
        itemCount: recordings.length,
        itemBuilder: (context, index) {
          final recording = recordings[index];
          return RecordingCard(
            recording: recording,
            onPlay: () {
              // TODO: Implement play action
            },
            onDelete: () {
              ref
                  .read(recordingProvider.notifier)
                  .deleteRecordingByKey(recording.dateTime.toIso8601String());
            },
            onTap: () => _showRecordingDetails(context, ref, recording),
          );
        },
      ),
    );
  }
}
