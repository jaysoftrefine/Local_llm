import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized environment configuration loaded from `.env`.
class AppEnv {
  static Future<void> init() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // In case .env is missing or cannot be loaded, fallback to empty
    }
  }

  static String get supabaseUrl => dotenv.get('SUPABASE_URL', fallback: '');
  static String get supabaseAnonKey => dotenv.get('SUPABASE_ANON_KEY', fallback: '');

  static String get googleWebClientId => dotenv.get('GOOGLE_WEB_CLIENT_ID', fallback: '');
  static String get googleAndroidClientId => dotenv.get('GOOGLE_ANDROID_CLIENT_ID', fallback: '');

  static String get llmModelName => dotenv.get('LLM_MODEL_NAME', fallback: 'Llama-3.2-1B-Instruct-Q4_K_M.gguf');
  static String get llmModelUrl => dotenv.get('LLM_MODEL_URL', fallback: '');

  static String get embeddingModelName => dotenv.get('EMBEDDING_MODEL_NAME', fallback: 'nomic-embed-text-v1.5.Q4_K_M.gguf');
  static String get embeddingModelUrl => dotenv.get('EMBEDDING_MODEL_URL', fallback: '');

  /// Returns true if Supabase URL and Anon Key are set to non-placeholder values
  static bool get isSupabaseConfigured {
    final url = supabaseUrl.trim();
    final key = supabaseAnonKey.trim();
    return url.isNotEmpty &&
        key.isNotEmpty &&
        !url.contains('placeholder') &&
        !url.contains('your-project');
  }
}

