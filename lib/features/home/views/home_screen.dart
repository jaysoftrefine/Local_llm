import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../auth/views/oauth_config_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isTestingSupabase = false;
  String? _supabaseTestResult;

  Future<void> _testSupabase() async {
    setState(() {
      _isTestingSupabase = true;
      _supabaseTestResult = null;
    });

    final success = await SupabaseService.instance.testConnection();

    if (!mounted) return;
    setState(() {
      _isTestingSupabase = false;
      _supabaseTestResult = success
          ? 'Connected to Supabase successfully! (Tables ready)'
          : 'Could not query Supabase tables. Check your .env URL and keys or run schema.sql in Supabase.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final user = authController.currentUser;
    final supabase = SupabaseService.instance;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.mark_email_unread_rounded, color: AppColors.primary),
            SizedBox(width: 10),
            Text(
              'Mail Chat',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Configure OAuth Keys',
            icon: const Icon(Icons.key_rounded, color: AppColors.textSecondary),
            onPressed: () => OAuthConfigDialog.show(context),
          ),
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout_rounded, color: AppColors.textSecondary),
            onPressed: () => authController.signOut(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User Profile Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.surfaceLight),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primary.withAlpha(50),
                    backgroundImage: user?.photoUrl != null
                        ? NetworkImage(user!.photoUrl!)
                        : null,
                    child: user?.photoUrl == null
                        ? Text(
                            (user?.displayName ?? user?.email ?? 'U')[0].toUpperCase(),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.displayName ?? 'Google User',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.email ?? '',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Phase 1 Verification Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.surfaceLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Phase 1 Active & Ready',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildStatusRow(
                    label: 'Google Sign-In & Gmail Scopes',
                    status: 'Authenticated',
                    isOk: true,
                  ),
                  const Divider(color: AppColors.surfaceLight, height: 20),
                  _buildStatusRow(
                    label: 'Tokens in flutter_secure_storage',
                    status: user?.accessToken != null ? 'Secured' : 'Missing',
                    isOk: user?.accessToken != null,
                  ),
                  const Divider(color: AppColors.surfaceLight, height: 20),
                  _buildStatusRow(
                    label: 'Google OAuth Client ID',
                    status: authController.isUsingCustomClientIds ? 'Custom (App)' : 'Active (.env)',
                    isOk: authController.isGoogleConfigured,
                  ),
                  const Divider(color: AppColors.surfaceLight, height: 20),
                  _buildStatusRow(
                    label: 'Supabase Initialization',
                    status: supabase.isInitialized ? 'Connected' : 'Unconfigured',
                    isOk: supabase.isInitialized,
                  ),
                  const SizedBox(height: 16),
                  // Test Supabase connection button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isTestingSupabase ? null : _testSupabase,
                      icon: _isTestingSupabase
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync_rounded, size: 18),
                      label: Text(_isTestingSupabase ? 'Testing...' : 'Test Supabase Database Ping'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.secondary,
                        side: const BorderSide(color: AppColors.secondary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  if (_supabaseTestResult != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _supabaseTestResult!,
                      style: TextStyle(
                        fontSize: 13,
                        color: _supabaseTestResult!.contains('successfully')
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Next Phase Preview Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.surfaceLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.arrow_forward_rounded, color: AppColors.primary, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Up Next: Phase 2',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Fetch and list emails via Gmail API with pagination, and cache them into Supabase tables for on-device AI search and summarization.',
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow({required String label, required String status, required bool isOk}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: (isOk ? AppColors.success : AppColors.warning).withAlpha(40),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            status,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isOk ? AppColors.success : AppColors.warning,
            ),
          ),
        ),
      ],
    );
  }
}
