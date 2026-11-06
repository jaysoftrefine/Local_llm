import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/app_env.dart';
import '../../../core/services/secure_storage_service.dart';
import '../../../core/services/supabase_service.dart';
import '../models/app_user.dart';

/// Authentication controller managing Google Sign-In, Supabase link, and token storage
class AuthController extends ChangeNotifier {
  static const List<String> gmailScopes = <String>[
    'email',
    'https://www.googleapis.com/auth/gmail.readonly',
    'https://www.googleapis.com/auth/gmail.compose',
  ];

  final SecureStorageService _storage = SecureStorageService.instance;
  final SupabaseService _supabase = SupabaseService.instance;

  AppUser? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isGoogleInitialized = false;

  String _webClientId = '';
  String _androidClientId = '';
  bool _isCustomConfig = false;

  AppUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  String get webClientId => _webClientId;
  String get androidClientId => _androidClientId;
  bool get isUsingCustomClientIds => _isCustomConfig;
  bool get isGoogleConfigured => _webClientId.trim().isNotEmpty;

  /// Initializes or updates Google Sign-In with current effective client IDs
  Future<void> _applyGoogleClientIds() async {
    try {
      final webId = _webClientId.trim();
      final androidId = _androidClientId.trim();

      if (!_isGoogleInitialized) {
        await GoogleSignIn.instance.initialize(
          serverClientId: webId.isNotEmpty ? webId : null,
          clientId: androidId.isNotEmpty ? androidId : null,
        );
        _isGoogleInitialized = true;
      } else {
        await GoogleSignInPlatform.instance.init(
          InitParameters(
            serverClientId: webId.isNotEmpty ? webId : null,
            clientId: androidId.isNotEmpty ? androidId : null,
          ),
        );
      }
    } catch (e) {
      debugPrint('[AuthController] GoogleSignIn initialize/update note: $e');
      _isGoogleInitialized = true;
    }
  }

  /// Updates OAuth client IDs from within the app and persists to secure storage
  Future<void> updateGoogleClientIds({
    required String webClientId,
    required String androidClientId,
  }) async {
    final cleanWeb = webClientId.trim();
    final cleanAndroid = androidClientId.trim();

    await _storage.saveOAuthClientIds(
      webClientId: cleanWeb,
      androidClientId: cleanAndroid,
    );

    _webClientId = cleanWeb;
    _androidClientId = cleanAndroid;
    _isCustomConfig = cleanWeb.isNotEmpty || cleanAndroid.isNotEmpty;
    _errorMessage = null;

    await _applyGoogleClientIds();
    notifyListeners();
  }

  /// Resets OAuth client IDs back to .env fallback defaults
  Future<void> resetClientIdsToEnv() async {
    await _storage.clearOAuthClientIds();
    _webClientId = AppEnv.googleWebClientId.trim();
    _androidClientId = AppEnv.googleAndroidClientId.trim();
    _isCustomConfig = false;
    _errorMessage = null;

    await _applyGoogleClientIds();
    notifyListeners();
  }

  /// Checks if there is an existing stored session on app launch
  Future<void> checkExistingSession() async {
    _setLoading(true);
    try {
      // Load saved client IDs or fallback to .env
      final customWeb = await _storage.getCustomWebClientId();
      final customAndroid = await _storage.getCustomAndroidClientId();
      if (customWeb != null && customWeb.trim().isNotEmpty) {
        _webClientId = customWeb.trim();
        _isCustomConfig = true;
      } else {
        _webClientId = AppEnv.googleWebClientId.trim();
        _isCustomConfig = false;
      }
      if (customAndroid != null && customAndroid.trim().isNotEmpty) {
        _androidClientId = customAndroid.trim();
      } else {
        _androidClientId = AppEnv.googleAndroidClientId.trim();
      }

      await _applyGoogleClientIds();

      // Check stored user email in secure storage
      final storedEmail = await _storage.getUserEmail();
      final storedAccessToken = await _storage.getGoogleAccessToken();
      final storedName = await _storage.getUserName();
      final storedPhoto = await _storage.getUserPhotoUrl();

      if (storedEmail != null && storedAccessToken != null) {
        _currentUser = AppUser(
          email: storedEmail,
          displayName: storedName,
          photoUrl: storedPhoto,
          accessToken: storedAccessToken,
        );
        debugPrint('[AuthController] Restored session from secure storage: $storedEmail');
      }

      // Try lightweight sign in to refresh tokens if possible
      try {
        // Silent sign-in is optional. Do not block the login screen if the
        // Google SDK cannot complete this check (for example, offline).
        final lightweightAuth = GoogleSignIn.instance.attemptLightweightAuthentication();
        final lightweightAccount = lightweightAuth == null
            ? null
            : await lightweightAuth.timeout(const Duration(seconds: 8));
        if (lightweightAccount != null) {
          await _handleAuthenticatedAccount(lightweightAccount);
        }
      } catch (e) {
        debugPrint('[AuthController] Lightweight auth skipped or timed out: $e');
      }
    } catch (e) {
      debugPrint('[AuthController] Error checking existing session: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Initiates interactive Google Sign-In with Gmail readonly and compose scopes
  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    _errorMessage = null;

    try {
      if (_webClientId.trim().isEmpty) {
        _errorMessage = 'Google Web Client ID is not configured. Please tap "Configure Client IDs" below to set it up.';
        _setLoading(false);
        return false;
      }

      await _applyGoogleClientIds();

      // 1. Authenticate with Google
      final GoogleSignInAccount account = await GoogleSignIn.instance
          .authenticate(scopeHint: gmailScopes)
          .timeout(const Duration(seconds: 90));

      // 2. Authorize Gmail scopes
      final GoogleSignInClientAuthorization authorization =
          await account.authorizationClient
              .authorizeScopes(gmailScopes)
              .timeout(const Duration(seconds: 90));

      final accessToken = authorization.accessToken;
      final idToken = account.authentication.idToken;

      debugPrint('[AuthController] Google auth successful for: ${account.email}');

      // 3. Persist tokens and profile to flutter_secure_storage
      await _storage.saveGoogleTokens(
        accessToken: accessToken,
        idToken: idToken,
      );
      await _storage.saveUserProfile(
        email: account.email,
        name: account.displayName,
        photoUrl: account.photoUrl,
      );

      // 4. Optionally sign into Supabase with ID Token if Supabase is configured
      if (_supabase.isInitialized && _supabase.client != null && idToken != null) {
        try {
          await _supabase.client!.auth.signInWithIdToken(
            provider: OAuthProvider.google,
            idToken: idToken,
            accessToken: accessToken,
          );
          debugPrint('[AuthController] Supabase signInWithIdToken successful');
        } catch (supabaseAuthError) {
          debugPrint('[AuthController] Supabase Auth link note: $supabaseAuthError');
          // Non-fatal: Local Gmail flow and tables continue to work
        }
      }

      _currentUser = AppUser(
        email: account.email,
        displayName: account.displayName,
        photoUrl: account.photoUrl,
        accessToken: accessToken,
        idToken: idToken,
      );

      notifyListeners();
      return true;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        _errorMessage = 'Sign in was cancelled.';
      } else {
        _errorMessage = 'Google Sign In failed: ${e.description ?? e.code.name}';
      }
      debugPrint('[AuthController] GoogleSignInException: $_errorMessage');
      return false;
    } on TimeoutException {
      _errorMessage =
          'Google sign-in timed out. Check your internet connection and Google OAuth setup, then try again.';
      debugPrint('[AuthController] Google sign-in timed out');
      return false;
    } catch (e) {
      _errorMessage = 'An error occurred during sign in: $e';
      debugPrint('[AuthController] Sign in error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Internal handler to refresh tokens and set state
  Future<void> _handleAuthenticatedAccount(GoogleSignInAccount account) async {
    try {
      final authz = await account.authorizationClient.authorizationForScopes(gmailScopes) ??
          await account.authorizationClient.authorizeScopes(gmailScopes);

      final accessToken = authz.accessToken;
      final idToken = account.authentication.idToken;

      await _storage.saveGoogleTokens(accessToken: accessToken, idToken: idToken);
      await _storage.saveUserProfile(
        email: account.email,
        name: account.displayName,
        photoUrl: account.photoUrl,
      );

      _currentUser = AppUser(
        email: account.email,
        displayName: account.displayName,
        photoUrl: account.photoUrl,
        accessToken: accessToken,
        idToken: idToken,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('[AuthController] Refresh error: $e');
    }
  }

  /// Signs the user out from Google, Supabase, and clears secure storage
  Future<void> signOut() async {
    _setLoading(true);
    try {
      await GoogleSignIn.instance.signOut();
      if (_supabase.isInitialized && _supabase.client != null) {
        await _supabase.client!.auth.signOut();
      }
      await _storage.clearSession();
      _currentUser = null;
      _errorMessage = null;
    } catch (e) {
      debugPrint('[AuthController] Sign out error: $e');
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}

