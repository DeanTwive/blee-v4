import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with platform-specific options (Android, iOS, Web)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const BleeApp());
}

class BleeApp extends StatefulWidget {
  const BleeApp({super.key});

  @override
  State<BleeApp> createState() => _BleeAppState();
}

class _BleeAppState extends State<BleeApp> {
  late final IAuthRepository _authRepository;

  @override
  void initState() {
    super.initState();
    _authRepository = FirebaseAuthRepository();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Blee',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: AuthGate(authRepository: _authRepository),
    );
  }
}
