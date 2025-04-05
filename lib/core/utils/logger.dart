import 'dart:developer' as developer;

/// Simple logger utility.
class AppLogger {
  void info(String message) {
    developer.log(message, name: 'EchoGhost.Info');
  }

  void warning(String message) {
    developer.log(
      message,
      name: 'EchoGhost.Warning',
      level: 900,
    ); // Warning level
  }

  void error(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log(
      message,
      name: 'EchoGhost.Error',
      level: 1000, // Error level
      error: error,
      stackTrace: stackTrace,
    );
  }
}

// Global instance (or use dependency injection/Riverpod to provide it)
final logger = AppLogger();
