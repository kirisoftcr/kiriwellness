import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_firebase.dart';

// ---------------------------------------------------------------------------
// Auth repository
// ---------------------------------------------------------------------------

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final FirebaseFirestore _defaultDb;

  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? db,
    FirebaseFirestore? defaultDb,
  })
      : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? AppFirebase.firestore,
        _defaultDb =
            defaultDb ?? FirebaseFirestore.instanceFor(app: Firebase.app());

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// Signs in with email/password and verifies admin role in Firestore.
  /// Throws [AuthException] with a user-friendly message on failure.
  Future<void> signInAdmin(String email, String password) async {
    try {
      if (kIsWeb) {
        await _auth.setPersistence(Persistence.LOCAL);
      }

      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      // Verify admin record exists
      final adminDoc = await _db
          .collection('admins')
          .doc(credential.user!.uid)
          .get();

      if (!adminDoc.exists) {
        final fallbackAdminDoc = await _defaultDb
            .collection('admins')
            .doc(credential.user!.uid)
            .get();

        if (fallbackAdminDoc.exists) return;

        await _auth.signOut();
        throw AuthException(
          'Usuario autenticado pero sin perfil admin. No existe admins/${credential.user!.uid} '
          'en la base ${AppFirebase.firestoreDatabaseId} ni en (default).',
        );
      }
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseError(e.code));
    }
  }

  Future<void> signOut() => _auth.signOut();

  /// Returns the admin data for the current user, or null.
  Future<Map<String, dynamic>?> getAdminData(String uid) async {
    final doc = await _db.collection('admins').doc(uid).get();
    if (!doc.exists) {
      final fallbackDoc = await _defaultDb.collection('admins').doc(uid).get();
      return fallbackDoc.data();
    }
    return doc.data();
  }

  String _mapFirebaseError(String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Correo o contraseña incorrectos.';
      case 'user-disabled':
        return 'Esta cuenta ha sido deshabilitada.';
      case 'too-many-requests':
        return 'Demasiados intentos. Intenta más tarde.';
      case 'invalid-email':
        return 'El correo electrónico no es válido.';
      default:
        return 'Error al iniciar sesión. Intenta de nuevo.';
    }
  }
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(),
);

/// Stream of the current Firebase Auth user.
final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges,
);

/// True only when the user is signed in (auth state resolved).
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).valueOrNull != null;
});
