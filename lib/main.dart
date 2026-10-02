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

  // Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Route all Flutter framework errors safely
  FlutterError.onError = AppCrashReporter.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    AppCrashReporter.recordError(error, stack, fatal: true);
    return true;
  };

  // Supabase — replace with your actual URL and anon key via --dart-define or .env
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
