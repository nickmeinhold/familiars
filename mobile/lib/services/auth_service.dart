import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../firebase_options.dart';

/// Wraps Firebase Auth + Google Sign-In for the familiars phase 0 client.
///
/// Identical pattern to downstream-mobile (same Firebase project). On
/// successful sign-in the returned [FirebaseAuth.currentUser] yields the
/// JWT used as the bearer token for `/api/*` calls.
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

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // best-effort
    }
    await _auth.signOut();
  }

  /// Get a fresh JWT id-token for the current user, or null if signed out.
  Future<String?> idToken({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return user.getIdToken(forceRefresh);
  }
}
