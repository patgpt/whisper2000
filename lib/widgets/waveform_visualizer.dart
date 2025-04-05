import 'package:flutter/cupertino.dart';

class WaveformVisualizer extends StatelessWidget {
  final bool isActive;
  final double level;

  const WaveformVisualizer({
    super.key,
    this.isActive = false,
    this.level = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    // Placeholder for waveform animation
    // For now, just shows an icon that changes slightly if active
    final iconColor =
        isActive
            ? CupertinoTheme.of(context).primaryColor
            : CupertinoColors.systemGrey;
    final iconSize = 60.0 + (level * 40.0);

    return Icon(
      isActive ? CupertinoIcons.waveform_path : CupertinoIcons.waveform,
      size: iconSize.clamp(60.0, 100.0),
      color: iconColor.withOpacity(isActive ? (0.5 + level * 0.5) : 1.0),
    );
  }
}
