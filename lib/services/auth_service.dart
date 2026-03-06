import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  static const String _usersCollection = 'users';

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  User? get currentUser => _firebaseAuth.currentUser;

  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required String role,
  }) async {
    final String cleanedEmail = email.trim().toLowerCase();
    final String cleanedRole = role.trim().toLowerCase();

    if (cleanedEmail.isEmpty) {
      throw FirebaseAuthException(
        code: 'empty-email',
        message: 'Email cannot be empty.',
      );
    }

    if (password.isEmpty) {
      throw FirebaseAuthException(
        code: 'empty-password',
        message: 'Password cannot be empty.',
      );
    }

    if (cleanedRole != 'seller' && cleanedRole != 'driver') {
      throw FirebaseAuthException(
        code: 'invalid-role',
        message: 'Role must be either seller or driver.',
      );
    }

    try {
      final UserCredential userCredential =
          await _firebaseAuth.createUserWithEmailAndPassword(
        email: cleanedEmail,
        password: password,
      );

      final User? user = userCredential.user;

      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-creation-failed',
          message: 'User account was created, but user data is missing.',
        );
      }

      await _createUserDocument(
        userId: user.uid,
        email: cleanedEmail,
        role: cleanedRole,
      );

      return userCredential;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw FirebaseAuthException(
        code: 'signup-failed',
        message: 'Failed to sign up user. Please try again.',
      );
    }
  }

  Future<UserCredential> loginWithEmail({
    required String email,
    required String password,
  }) async {
    final String cleanedEmail = email.trim().toLowerCase();

    if (cleanedEmail.isEmpty) {
      throw FirebaseAuthException(
        code: 'empty-email',
        message: 'Email cannot be empty.',
      );
    }

    if (password.isEmpty) {
      throw FirebaseAuthException(
        code: 'empty-password',
        message: 'Password cannot be empty.',
      );
    }

    try {
      final UserCredential userCredential =
          await _firebaseAuth.signInWithEmailAndPassword(
        email: cleanedEmail,
        password: password,
      );

      return userCredential;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw FirebaseAuthException(
        code: 'login-failed',
        message: 'Failed to log in. Please try again.',
      );
    }
  }

  Future<void> logout() async {
    try {
      await _firebaseAuth.signOut();
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw FirebaseAuthException(
        code: 'logout-failed',
        message: 'Failed to log out. Please try again.',
      );
    }
  }

  Future<void> _createUserDocument({
    required String userId,
    required String email,
    required String role,
  }) async {
    try {
      await _firestore.collection(_usersCollection).doc(userId).set({
        'userId': userId,
        'email': email,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      await _deleteAuthUserIfPossible();

      throw FirebaseAuthException(
        code: 'firestore-user-create-failed',
        message: e.message ?? 'Failed to create user profile in Firestore.',
      );
    } catch (e) {
      await _deleteAuthUserIfPossible();

      throw FirebaseAuthException(
        code: 'firestore-user-create-failed',
        message: 'Failed to create user profile in Firestore.',
      );
    }
  }

  Future<void> _deleteAuthUserIfPossible() async {
    try {
      final User? user = _firebaseAuth.currentUser;
      if (user != null) {
        await user.delete();
      }
    } catch (_) {
      // Intentionally ignored.
      // If delete fails, we still want to surface the original Firestore error.
    }
  }
}