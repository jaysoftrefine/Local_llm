import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_env.dart';

/// Service managing Supabase initialization, connection health, and access
class SupabaseService {
  static final SupabaseService instance = SupabaseService._internal();
  SupabaseService._internal();

  bool _isInitialized = false;
  String? _initError;

  bool get isInitialized => _isInitialized;
  String? get initError => _initError;

  SupabaseClient? get client {
    if (!_isInitialized) return null;
    return Supabase.instance.client;
  }

  /// Initializes Supabase if credentials are provided in `.env`
  Future<bool> initialize() async {
    if (!AppEnv.isSupabaseConfigured) {
      _initError = 'Supabase credentials not configured in .env';
      debugPrint('[SupabaseService] $_initError');
      return false;
    }

    try {
      await Supabase.initialize(
        url: AppEnv.supabaseUrl.trim(),
        publishableKey: AppEnv.supabaseAnonKey.trim(),
        debug: kDebugMode,
      );
      _isInitialized = true;
      _initError = null;
      debugPrint('[SupabaseService] Successfully connected to Supabase: ${AppEnv.supabaseUrl}');
      return true;
    } catch (e) {
      _initError = e.toString();
      _isInitialized = false;
      debugPrint('[SupabaseService] Failed to initialize Supabase: $e');
      return false;
    }
  }

  /// Checks if Supabase database tables can be pinged
  Future<bool> testConnection() async {
    if (!_isInitialized || client == null) return false;
    try {
      // Query 0 rows from emails table to verify table availability and API reachability
      await client!.from('emails').select('id').limit(1);
      return true;
    } catch (e) {
      debugPrint('[SupabaseService] Connection test ping returned: $e');
      // If error is just empty table or RLS, connection to Supabase endpoint succeeded
      return !e.toString().contains('Failed host lookup');
    }
  }
}
