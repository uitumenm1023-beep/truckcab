import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';

class AppAuthProvider extends ChangeNotifier {
  final AuthService _svc = AuthService();
  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot>? _profileSub;

  User?      _user;
  UserModel? _profile;
  bool       _loading = false;
  String?    _error;

  AppAuthProvider() { _listenAuth(); }

  // ── Getters ────────────────────────────────────────────────────────────────
  User?      get user               => _user;
  UserModel? get currentUserProfile => _profile;
  bool       get isLoading          => _loading;
  String?    get errorMessage       => _error;
  bool       get isLoggedIn         => _user != null;

  String? get currentUserId    => _user?.uid;
  String? get currentUserEmail => _user?.email;
  String? get currentUserRole  => _profile?.role;
  bool    get isEmailVerified  => _svc.isEmailVerified;

  // ── Auth state listener ────────────────────────────────────────────────────
  void _listenAuth() {
    _authSub?.cancel();
    _authSub = _svc.authStateChanges.listen((u) async {
      _user = u;
      if (u == null) {
        await _profileSub?.cancel();
        _profile = null;
        notifyListeners();
        return;
      }
      await _ensureDoc(uid: u.uid, email: u.email ?? '');
      _listenProfile(u.uid);
      await setOnlineStatus(true);
      notifyListeners();
    });
  }

  void _listenProfile(String uid) {
    _profileSub?.cancel();
    _profileSub = _fs.collection('users').doc(uid).snapshots().listen((doc) {
      if (doc.exists) {
        final d = doc.data();
        _profile = d is Map<String, dynamic> ? UserModel.fromMap(d) : null;
      } else {
        _profile = null;
      }
      notifyListeners();
    });
  }

  Future<void> _ensureDoc({required String uid, required String email, String? role}) async {
    final ref = _fs.collection('users').doc(uid);
    final doc = await ref.get();

    if (!doc.exists) {
      // Only create the stub if we actually have a role — otherwise wait for
      // signUpWithEmail/_createDoc to write the real document.
      if (role == null) return;
      await ref.set({
        'userId': uid, 'email': email,
        'role': role, 'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    // Doc exists — only merge online status + email. Never downgrade a real role to 'user'.
    final update = <String, dynamic>{
      'userId': uid,
      'email': email,
      'isOnline': true,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (role != null) update['role'] = role; // only override when explicitly given
    await ref.set(update, SetOptions(merge: true));
  }

  // ── Email sign up ──────────────────────────────────────────────────────────
  Future<bool> signUp({
    required String email,
    required String password,
    required String role,
    required String name,
    required DateTime birthdate,
    String vehicleType = '',
    int yearsExperience = 0,
    bool hasCrash = false,
    int crashCount = 0,
    String phoneNumber = '',
  }) async {
    _setLoading(true); _clearError();
    try {
      final cred = await _svc.signUpWithEmail(
        email: email, password: password, role: role, name: name, birthdate: birthdate,
        vehicleType: vehicleType, yearsExperience: yearsExperience,
        hasCrash: hasCrash, crashCount: crashCount, phoneNumber: phoneNumber,
      );
      _user = cred.user;
      await _svc.reloadUser();
      _user = _svc.currentUser;

      // Email not yet verified — start background poll
      if (_user != null && !_svc.isEmailVerified) {
        _error = 'Please verify your email — check your inbox (and spam folder). '
            'The app will sign you in automatically once verified.';
        notifyListeners();
        _pollEmailVerification(role: role);
        return false;
      }

      if (_user != null) {
        await _ensureDoc(uid: _user!.uid, email: _user!.email ?? email, role: role);
        _listenProfile(_user!.uid);
        await setOnlineStatus(true);
      }
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return false;
    } catch (_) {
      _error = 'Something went wrong during signup.';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Polls every 5 s for up to 5 minutes until email is verified
  Future<void> _pollEmailVerification({required String role}) async {
    for (int i = 0; i < 60; i++) {
      await Future.delayed(const Duration(seconds: 5));
      await _svc.reloadUser();
      _user = _svc.currentUser;
      if (_user != null && _svc.isEmailVerified) {
        _error = null;
        await _ensureDoc(uid: _user!.uid, email: _user!.email ?? '', role: role);
        _listenProfile(_user!.uid);
        await setOnlineStatus(true);
        notifyListeners();
        return;
      }
    }
    // Timed out after 5 minutes
    await _svc.logout();
    _user = null;
    _error = 'Verification timed out. Please sign up again.';
    notifyListeners();
  }

  // ── Email login ────────────────────────────────────────────────────────────
  Future<bool> login({required String email, required String password}) async {
    _setLoading(true); _clearError();
    try {
      final cred = await _svc.loginWithEmail(email: email, password: password);
      _user = cred.user;
      if (_user != null) {
        await _ensureDoc(uid: _user!.uid, email: _user!.email ?? email);
        _listenProfile(_user!.uid);
        await setOnlineStatus(true);
      }
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return false;
    } catch (_) {
      _error = 'Something went wrong during login.';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Logout ─────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    _setLoading(true); _clearError();
    try {
      await setOnlineStatus(false);
      await _svc.logout();
      _user = null; _profile = null;
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
    } catch (_) {
      _error = 'Something went wrong during logout.';
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> setOnlineStatus(bool online) async {
    final uid = currentUserId;
    if (uid == null || uid.isEmpty) return;
    await _fs.collection('users').doc(uid).set({
      'isOnline': online,
      'lastSeen': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> handleAppLifecycleState(AppLifecycleState state) async {
    if (!isLoggedIn) return;
    if (state == AppLifecycleState.resumed) { await setOnlineStatus(true); return; }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      await setOnlineStatus(false);
    }
  }

  void clearErrorMessage() { _error = null; notifyListeners(); }

  void _setLoading(bool v) { _loading = v; notifyListeners(); }
  void _clearError()       { _error = null; }

  String _friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':         return 'No account found with this email.';
      case 'wrong-password':         return 'Incorrect password. Please try again.';
      case 'email-already-in-use':   return 'An account already exists with this email.';
      case 'weak-password':          return 'Password is too weak — use at least 6 characters.';
      case 'invalid-email':          return 'Invalid email address.';
      case 'network-request-failed': return 'No internet connection. Please check your network.';
      default:                       return e.message ?? 'Something went wrong. Please try again.';
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }
}