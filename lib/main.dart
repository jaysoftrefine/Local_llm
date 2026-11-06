import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/config/app_env.dart';
import 'core/constants/app_colors.dart';
import 'core/services/supabase_service.dart';
import 'features/auth/controllers/auth_controller.dart';
import 'features/auth/views/login_screen.dart';
import 'features/home/views/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Load environment configuration from .env
  await AppEnv.init();

  // 2. Initialize Supabase if credentials are provided
  await SupabaseService.instance.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthController()..checkExistingSession(),
        ),
      ],
      child: const MailMindApp(),
    ),
  );
}

class MailMindApp extends StatelessWidget {
  const MailMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();

    return MaterialApp(
      title: 'Mail Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.surface,
          error: AppColors.error,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
        ),
      ),
      home: authController.isAuthenticated
          ? const HomeScreen()
          : const LoginScreen(),
    );
  }
}
