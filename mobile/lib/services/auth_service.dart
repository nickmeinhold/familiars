import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../firebase_options.dart';

/// Wraps Firebase Auth + provider sign-ins for the familiars phase 0 client.
///
/// Same Firebase project as downstream-mobile (downstream-181e2). Either
/// provider yields a Firebase user whose JWT becomes the bearer token for
/// `/api/*` calls — the server's auth middleware doesn't care which
/// provider authenticated.
///
/// Apple is the iOS-preferred path because Sign in with Apple is OS-native
/// and works on a fresh simulator; Google Sign-In on the iOS simulator
/// requires a SafariViewController flow that is fragile without a real
/// signed-in iCloud-Google session.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  /// Initialize Firebase. Call once from `main` before [runApp].
  static Future<void> initialize() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Returns null on success, or an error message on failure.
  Future<String?> signInWithGoogle() async {
    try {
      await _googleSignIn.initialize();
      final account = await _googleSignIn.authenticate();
      final auth = account.authentication;
      final credential = GoogleAuthProvider.credential(idToken: auth.idToken);
      await _auth.signInWithCredential(credential);
      return null;
    } catch (e) {
      return 'Google sign in failed: $e';
    }
  }

  /// Sign in with Apple. iOS-native flow on simulator + device.
  ///
  /// Generates a cryptographically random nonce, hashes it with SHA-256,
  /// and passes the hashed form to Apple. Apple includes the nonce in the
  /// returned identity token; Firebase verifies it against the raw nonce
  /// we pass through. This protects against replay attacks where a stolen
  /// Apple identity token couldn't be reused without the corresponding
  /// raw nonce.
  ///
  /// Returns null on success, or an error message on failure.
  Future<String?> signInWithApple() async {
    try {
      final rawNonce = _generateNonce();
      final hashedNonce = _sha256(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );
      await _auth.signInWithCredential(oauthCredential);
      return null;
    } on SignInWithAppleAuthorizationException catch (e) {
      // User-cancelled → return null silently? No — surface so the UI can
      // distinguish "I changed my mind" from "the platform returned an
      // error". Loading state needs to clear regardless.
      if (e.code == AuthorizationErrorCode.canceled) {
        return 'Sign in with Apple cancelled.';
      }
      return 'Sign in with Apple failed: ${e.message}';
    } catch (e) {
      return 'Sign in with Apple failed: $e';
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // best-effort
    }
    // Apple has no SDK-side sign-out — Firebase signOut alone is enough.
    await _auth.signOut();
  }

  /// Get a fresh JWT id-token for the current user, or null if signed out.
  Future<String?> idToken({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return user.getIdToken(forceRefresh);
  }

  static String _generateNonce([int length = 32]) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._';
    final random = Random.secure();
    return List.generate(length, (_) => chars[random.nextInt(chars.length)])
        .join();
  }

  static String _sha256(String input) =>
      sha256.convert(utf8.encode(input)).toString();
}
