import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  })  : _auth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  static const String _users = 'users';

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  Future<void> reloadUser() async => _auth.currentUser?.reload();
  Future<void> sendVerificationEmail() async {
    final u = _auth.currentUser;
    if (u != null && !u.emailVerified) await u.sendEmailVerification();
  }

  // ── Email sign-up ──────────────────────────────────────────────────────────
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required String role,
    required String name,
    required DateTime birthdate,
    String vehicleType = '',
    int yearsExperience = 0,
    bool hasCrash = false,
    int crashCount = 0,
  }) async {
    final e = email.trim().toLowerCase();
    final r = role.trim().toLowerCase();
    if (e.isEmpty) throw _ex('empty-email', 'Email cannot be empty.');
    if (password.isEmpty) throw _ex('empty-password', 'Password cannot be empty.');
    if (r != 'seller' && r != 'driver') throw _ex('invalid-role', 'Role must be seller or driver.');

    try {
      final cred = await _auth.createUserWithEmailAndPassword(email: e, password: password);
      final user = cred.user;
      if (user == null) throw _ex('user-creation-failed', 'User data missing after creation.');
      if (name.trim().isNotEmpty) await user.updateDisplayName(name.trim());
      await user.sendEmailVerification();
      await _createDoc(
        userId: user.uid, email: e, role: r, name: name, birthdate: birthdate,
        vehicleType: vehicleType, yearsExperience: yearsExperience,
        hasCrash: hasCrash, crashCount: crashCount,
      );
      return cred;
    } on FirebaseAuthException {
      rethrow;
    } catch (_) {
      throw _ex('signup-failed', 'Failed to sign up. Please try again.');
    }
  }

  // ── Email login ────────────────────────────────────────────────────────────
  Future<UserCredential> loginWithEmail({
    required String email,
    required String password,
  }) async {
    final e = email.trim().toLowerCase();
    if (e.isEmpty) throw _ex('empty-email', 'Email cannot be empty.');
    if (password.isEmpty) throw _ex('empty-password', 'Password cannot be empty.');
    try {
      return await _auth.signInWithEmailAndPassword(email: e, password: password);
    } on FirebaseAuthException {
      rethrow;
    } catch (_) {
      throw _ex('login-failed', 'Failed to log in. Please try again.');
    }
  }

  // ── Logout ─────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    try {
      await _auth.signOut();
    } on FirebaseAuthException {
      rethrow;
    } catch (_) {
      throw _ex('logout-failed', 'Failed to log out. Please try again.');
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  FirebaseAuthException _ex(String code, String message) =>
      FirebaseAuthException(code: code, message: message);

  Future<void> _createDoc({
    required String userId,
    required String email,
    required String role,
    required String name,
    required DateTime birthdate,
    String vehicleType = '',
    int yearsExperience = 0,
    bool hasCrash = false,
    int crashCount = 0,
  }) async {
    try {
      final data = <String, dynamic>{
        'userId': userId,
        'email': email,
        'role': role,
        'name': name.trim(),
        'birthdate': Timestamp.fromDate(birthdate),
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (role == 'driver') {
        data['vehicleType'] = vehicleType;
        data['yearsExperience'] = yearsExperience;
        data['hasCrash'] = hasCrash;
        data['crashCount'] = crashCount;
      }
      await _firestore.collection(_users).doc(userId).set(data);
    } on FirebaseException catch (e) {
      await _tryDeleteAuthUser();
      throw _ex('firestore-user-create-failed',
          e.message ?? 'Failed to create user profile.');
    } catch (_) {
      await _tryDeleteAuthUser();
      throw _ex('firestore-user-create-failed', 'Failed to create user profile.');
    }
  }

  Future<void> _tryDeleteAuthUser() async {
    try { await _auth.currentUser?.delete(); } catch (_) {}
  }
}