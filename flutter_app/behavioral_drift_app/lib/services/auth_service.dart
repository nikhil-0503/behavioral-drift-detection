import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

/// Wraps Firebase Auth + Google Sign-In.
/// Exposes a stream of auth state and sign-in / sign-out methods.
/// On web, skips Firebase for testing.
class AuthService extends ChangeNotifier {
  late final FirebaseAuth _auth;
  late final GoogleSignIn _googleSignIn;
  User? _mockUser; // Mock user for web testing

  AuthService() {
    if (!kIsWeb) {
      _auth = FirebaseAuth.instance;
      _googleSignIn = GoogleSignIn();
    } else {
      // On web: create mock user for testing
      _mockUser = null;
    }
  }

  User? get currentUser {
    if (kIsWeb) return _mockUser;
    return _auth.currentUser;
  }

  bool get isSignedIn {
    if (kIsWeb) return true; // Always signed in on web for testing
    return _auth.currentUser != null;
  }

  Stream<User?> get authStateChanges {
    if (kIsWeb) {
      return Stream.value(_mockUser);
    }
    return _auth.authStateChanges();
  }

  /// Sign in with Google. Returns the [User] or throws.
  /// On web: mocks sign-in for testing.
  Future<User?> signInWithGoogle() async {
    if (kIsWeb) {
      notifyListeners();
      return _mockUser; // Mock user on web
    }
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // user cancelled

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      notifyListeners();
      return userCredential.user;
    } catch (e) {
      debugPrint('Google sign-in error: $e');
      rethrow;
    }
  }

  /// Sign out from both Firebase and Google.
  /// On web: skips actual sign-out for testing.
  Future<void> signOut() async {
    if (kIsWeb) {
      _mockUser = null;
      notifyListeners();
      return;
    }
    await _googleSignIn.signOut();
    await _auth.signOut();
    notifyListeners();
  }
}
