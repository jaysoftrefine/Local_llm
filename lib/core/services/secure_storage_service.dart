import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure token & session storage using `flutter_secure_storage`
class SecureStorageService {
  static final SecureStorageService instance = SecureStorageService._internal();
  SecureStorageService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: true,
    ),
  );

  static const String _keyGoogleAccessToken = 'google_access_token';
  static const String _keyGoogleIdToken = 'google_id_token';
  static const String _keyUserEmail = 'user_email';
  static const String _keyUserName = 'user_name';
  static const String _keyUserPhotoUrl = 'user_photo_url';
  static const String _keyCustomWebClientId = 'custom_google_web_client_id';
  static const String _keyCustomAndroidClientId = 'custom_google_android_client_id';

  // --- Custom Google OAuth Client IDs ---
  Future<void> saveOAuthClientIds({
    required String webClientId,
    required String androidClientId,
  }) async {
    await _storage.write(key: _keyCustomWebClientId, value: webClientId.trim());
    await _storage.write(key: _keyCustomAndroidClientId, value: androidClientId.trim());
  }

  Future<String?> getCustomWebClientId() async {
    return await _storage.read(key: _keyCustomWebClientId);
  }

  Future<String?> getCustomAndroidClientId() async {
    return await _storage.read(key: _keyCustomAndroidClientId);
  }

  Future<void> clearOAuthClientIds() async {
    await _storage.delete(key: _keyCustomWebClientId);
    await _storage.delete(key: _keyCustomAndroidClientId);
  }

  // --- Google Tokens ---
  Future<void> saveGoogleTokens({
    required String accessToken,
    String? idToken,
  }) async {
    await _storage.write(key: _keyGoogleAccessToken, value: accessToken);
    if (idToken != null) {
      await _storage.write(key: _keyGoogleIdToken, value: idToken);
    }
  }

  Future<String?> getGoogleAccessToken() async {
    return await _storage.read(key: _keyGoogleAccessToken);
  }

  Future<String?> getGoogleIdToken() async {
    return await _storage.read(key: _keyGoogleIdToken);
  }

  // --- User Profile ---
  Future<void> saveUserProfile({
    required String email,
    String? name,
    String? photoUrl,
  }) async {
    await _storage.write(key: _keyUserEmail, value: email);
    if (name != null) await _storage.write(key: _keyUserName, value: name);
    if (photoUrl != null) await _storage.write(key: _keyUserPhotoUrl, value: photoUrl);
  }

  Future<String?> getUserEmail() async {
    return await _storage.read(key: _keyUserEmail);
  }

  Future<String?> getUserName() async {
    return await _storage.read(key: _keyUserName);
  }

  Future<String?> getUserPhotoUrl() async {
    return await _storage.read(key: _keyUserPhotoUrl);
  }

  // --- Clear Session ---
  Future<void> clearSession() async {
    await _storage.delete(key: _keyGoogleAccessToken);
    await _storage.delete(key: _keyGoogleIdToken);
    await _storage.delete(key: _keyUserEmail);
    await _storage.delete(key: _keyUserName);
    await _storage.delete(key: _keyUserPhotoUrl);
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
