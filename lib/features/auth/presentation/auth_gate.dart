import 'package:flutter/material.dart';
import '../../home/presentation/home_screen.dart';
import '../data/auth_repository.dart';
import '../domain/user_entity.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  final IAuthRepository authRepository;

  const AuthGate({super.key, required this.authRepository});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserEntity?>(
      stream: authRepository.authStateChanges,
      initialData: authRepository.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user != null) {
          return HomeScreen(
            user: user,
            authRepository: authRepository,
          );
        }

        return LoginScreen(authRepository: authRepository);
      },
    );
  }
}
