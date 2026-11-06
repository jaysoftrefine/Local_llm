import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../controllers/auth_controller.dart';
import 'oauth_config_dialog.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final supabase = SupabaseService.instance;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // MailMind App Logo & Branding
                Container(
                  width: 90,
                  height: 90,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.accent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withAlpha(75),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.mark_email_unread_rounded,
                    size: 46,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  'Mail Chat',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'On-device AI Email Intelligence',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 36),

                // System Status Indicator Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.surfaceLight),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            supabase.isInitialized
                                ? Icons.cloud_done_rounded
                                : Icons.cloud_off_rounded,
                            size: 20,
                            color: supabase.isInitialized
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              supabase.isInitialized
                                  ? 'Supabase Backend Connected'
                                  : 'Supabase: Waiting for .env credentials',
                              style: TextStyle(
                                fontSize: 13,
                                color: supabase.isInitialized
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            Icons.memory_rounded,
                            size: 20,
                            color: AppColors.secondary,
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'On-device model download is available after sign-in',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: () => OAuthConfigDialog.show(context),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Icon(
                                authController.isGoogleConfigured
                                    ? Icons.key_rounded
                                    : Icons.key_off_rounded,
                                size: 20,
                                color: authController.isGoogleConfigured
                                    ? AppColors.success
                                    : AppColors.warning,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  authController.isGoogleConfigured
                                      ? (authController.isUsingCustomClientIds
                                          ? 'Google OAuth: Custom Client ID configured'
                                          : 'Google OAuth: Client ID loaded from .env')
                                      : 'Google OAuth: Missing Client ID (Tap to configure)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: authController.isGoogleConfigured
                                        ? AppColors.textPrimary
                                        : AppColors.warning,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.settings_outlined,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Error Message Banner (if any)
                if (authController.errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppColors.error.withAlpha(35),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.error.withAlpha(80)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            authController.errorMessage!,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Google Sign-In Action Button
                ElevatedButton(
                  onPressed: authController.isLoading
                      ? null
                      : () => authController.signInWithGoogle(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: authController.isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Google Logo icon
                            Image.network(
                              'https://fonts.gstatic.com/s/i/productlogos/googleg/v6/24px.svg',
                              width: 22,
                              height: 22,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.g_mobiledata_rounded,
                                size: 24,
                                color: Colors.blueAccent,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Sign in with Google',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 12),

                // Configure OAuth Keys Button
                Center(
                  child: TextButton.icon(
                    onPressed: () => OAuthConfigDialog.show(context),
                    icon: Icon(
                      Icons.settings_outlined,
                      size: 16,
                      color: authController.isGoogleConfigured
                          ? AppColors.textSecondary
                          : AppColors.warning,
                    ),
                    label: Text(
                      authController.isGoogleConfigured
                          ? 'Configure Google OAuth Keys'
                          : 'Set Up Google OAuth Keys',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: authController.isGoogleConfigured
                            ? AppColors.textSecondary
                            : AppColors.warning,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Privacy & Permissions Notice
                const Text(
                  'Scopes requested: gmail.readonly & gmail.compose\n'
                  'Mail Chat runs AI locally on your device and will never auto-send emails.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
