import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Centralized crash and error reporting.
/// Safely routes errors to Firebase Crashlytics on mobile (iOS/Android)
/// and to console logger on Web, preventing Crashlytics UnsupportedError on web.
class AppCrashReporter {
  static void recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) {
    if (!kIsWeb) {
      FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        reason: reason,
        fatal: fatal,
      );
    } else {
      debugPrint('[AppCrashReporter] $reason: $error');
      if (stack != null) debugPrint(stack.toString());
    }
  }

  static void recordFlutterFatalError(FlutterErrorDetails details) {
    if (!kIsWeb) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    } else {
      FlutterError.dumpErrorToConsole(details);
    }
  }
}
