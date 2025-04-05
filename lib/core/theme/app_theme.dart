import 'package:flutter/cupertino.dart';

/// Centralized theme configuration for the app.
class AppTheme {
  // Define core colors, maybe using OKLCH if desired for v4 Tailwind compatibility
  static const CupertinoDynamicColor primaryColor =
      CupertinoColors.systemPurple;
  static const CupertinoDynamicColor secondaryColor =
      CupertinoColors.systemIndigo;
  static const CupertinoDynamicColor destructiveColor =
      CupertinoColors.systemRed;

  // Define other theme elements like text styles if needed

  /// Provides the CupertinoThemeData based on brightness.
  static CupertinoThemeData getThemeData(Brightness brightness) {
    return CupertinoThemeData(
      brightness: brightness,
      primaryColor: primaryColor,
      textTheme: CupertinoTextThemeData(
        textStyle: TextStyle(fontFamily: 'Gidole'),
      ),
    );
  }

  static CupertinoThemeData get lightTheme => getThemeData(Brightness.light);
  static CupertinoThemeData get darkTheme => getThemeData(Brightness.dark);
}
