import 'package:firebase_core/firebase_core.dart';
import 'core/utils/crash_reporter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Route all Flutter framework errors safely FIRST
  FlutterError.onError = AppCrashReporter.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    AppCrashReporter.recordError(error, stack, fatal: true);
    return true;
  };

  // Firebase — guarded so web/network failures do not crash the app before runApp
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e, stack) {
    debugPrint('[main] Firebase initialization error: $e');
    AppCrashReporter.recordError(e, stack, reason: 'Firebase initialization failed');
  }

  // Supabase — guarded so placeholder or invalid credentials do not crash the app
  try {
    await Supabase.initialize(
      url: const String.fromEnvironment(
        'SUPABASE_URL',
        defaultValue: 'https://your-project.supabase.co',
      ),
      publishableKey: const String.fromEnvironment(
        'SUPABASE_ANON_KEY',
        defaultValue: 'your-anon-key',
      ),
    );
  } catch (e, stack) {
    debugPrint('[main] Supabase initialization error: $e');
    AppCrashReporter.recordError(e, stack, reason: 'Supabase initialization failed');
  }

  runApp(const ProviderScope(child: BleeApp()));
}

class BleeApp extends ConsumerWidget {
  const BleeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Blee',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
