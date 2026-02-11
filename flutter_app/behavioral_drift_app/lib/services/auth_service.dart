import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Wraps Firebase Auth + Google Sign-In.
/// Exposes a stream of auth state and sign-in / sign-out methods.
class AuthService extends ChangeNotifier {
  late final FirebaseAuth _auth;
  GoogleSignIn? _googleSignIn;
  bool _initialized = false;

  // Web-only OAuth client ID (Android uses google-services.json automatically)
  static const String _googleWebClientId =
      '132732288455-74h7eddn0433ar9o9pr9lk9mpnejrgl1.apps.googleusercontent.com';

  AuthService() {
    _initializeAuth();
  }

  void _initializeAuth() {
    try {
      _auth = FirebaseAuth.instance;
      _initialized = true;
    } catch (e) {
      debugPrint('FirebaseAuth initialization error: $e');
      _initialized = false;
    }

    if (kIsWeb) {
      _googleSignIn = GoogleSignIn(
        clientId: _googleWebClientId,
        scopes: ['email', 'profile'],
      );
    } else {
      // Android: do NOT pass clientId – it is resolved from google-services.json
      _googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );
    }
  }

  User? get currentUser {
    if (!_initialized) return null;
    return _auth.currentUser;
  }

  bool get isSignedIn {
    if (!_initialized) return false;
    return _auth.currentUser != null;
  }

  bool get isAvailable => _initialized;

  Stream<User?> get authStateChanges {
    if (!_initialized) return Stream.value(null);
    return _auth.authStateChanges();
  }

  /// Sign in with Google. Returns the [User] or throws.
  Future<User?> signInWithGoogle() async {
    try {
      if (!_initialized) {
        throw Exception('Auth not initialized. Check Firebase setup.');
      }

      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        final userCredential = await _auth.signInWithPopup(provider);
        notifyListeners();
        return userCredential.user;
      }

      // Mobile: Use google_sign_in package
      final googleUser = await _googleSignIn?.signIn();
      if (googleUser == null) return null; // User cancelled

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      notifyListeners();
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase auth error (${e.code}): ${e.message}');
      if (e.code == 'popup-blocked') {
        throw Exception('Sign-in popup was blocked. Please allow popups.');
      } else if (e.code == 'cancelled-popup-request') {
        throw Exception('Sign-in was cancelled.');
      }
      rethrow;
    } on PlatformException catch (e) {
      debugPrint('Platform error (${e.code}): ${e.message}');
      if (e.code == 'sign_in_failed') {
        final msg = e.message ?? '';
        if (msg.contains('ApiException: 10') || msg.contains('DEVELOPER_ERROR')) {
          throw Exception(
            'Google Sign-In failed (error 10 / DEVELOPER_ERROR). '
            'Ensure SHA-1 fingerprint is registered in Firebase Console '
            'and google-services.json is up to date.',
          );
        }
        if (msg.contains('ApiException: 12500')) {
          throw Exception(
            'Google Sign-In failed (12500). Update Google Play Services on your device.',
          );
        }
        if (msg.contains('ApiException: 7')) {
          throw Exception(
            'Google Sign-In failed (network error). Check your internet connection.',
          );
        }
      }
      rethrow;
    } catch (e) {
      debugPrint('Sign-in error: $e');
      rethrow;
    }
  }

  /// Sign out from both Firebase and Google.
  Future<void> signOut() async {
    if (!_initialized) return;

    if (!kIsWeb) {
      await _googleSignIn?.signOut();
    }
    await _auth.signOut();
    notifyListeners();
  }
}
