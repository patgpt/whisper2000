import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart'; // For date formatting

import '../features/recordings/ui/recordings_page.dart'; // Updated path

class RecordingCard extends StatelessWidget {
  final Recording recording;
  final VoidCallback? onPlay;
  final VoidCallback? onDelete;
  final VoidCallback? onTap; // For tapping the main card body

  const RecordingCard({
    super.key,
    required this.recording,
    this.onPlay,
    this.onDelete,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy hh:mm a'); // Example format

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color:
              CupertinoTheme.of(context).barBackgroundColor, // Use theme color
          borderRadius: BorderRadius.circular(12.0),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemGrey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 2), // changes position of shadow
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              recording.title,
              style: CupertinoTheme.of(
                context,
              ).textTheme.textStyle.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              dateFormat.format(recording.dateTime),
              style: CupertinoTheme.of(context).textTheme.tabLabelTextStyle,
            ),
            const SizedBox(height: 8),
            Text(
              recording.preview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: CupertinoTheme.of(context).textTheme.textStyle,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onPlay != null)
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: onPlay,
                    child: const Icon(CupertinoIcons.play_arrow, size: 24),
                  ),
                if (onDelete != null)
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: onDelete,
                    child: const Icon(
                      CupertinoIcons.delete,
                      size: 24,
                      color: CupertinoColors.destructiveRed,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
