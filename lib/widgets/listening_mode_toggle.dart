import 'package:flutter/cupertino.dart';

// Import enum from home viewmodel
import '../features/home/viewmodel/home_viewmodel.dart';

class ListeningModeToggle extends StatelessWidget {
  final ListeningMode selectedMode;
  final ValueChanged<ListeningMode?> onChanged;

  const ListeningModeToggle({
    super.key,
    required this.selectedMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Using CupertinoSegmentedControl for the toggle chips style
    return CupertinoSegmentedControl<ListeningMode>(
      children: const {
        ListeningMode.speechBoost: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text('Speech Boost'),
        ),
        ListeningMode.whisperMode: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text('Whisper Mode'),
        ),
        ListeningMode.safeListen: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text('Safe Listen'),
        ),
      },
      onValueChanged: onChanged,
      groupValue: selectedMode,
      // You might need to adjust padding/colors for the desired visual style
      // unselectedColor: CupertinoColors.systemGrey5,
      // selectedColor: CupertinoTheme.of(context).primaryColor,
      // borderColor: CupertinoTheme.of(context).primaryColor,
      // pressedColor: CupertinoTheme.of(context).primaryColor.withOpacity(0.2),
    );
  }
}
