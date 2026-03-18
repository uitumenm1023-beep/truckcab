import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot>? _userProfileSubscription;

  User? _user;
  UserModel? _currentUserProfile;
  bool _isLoading = false;
  String? _errorMessage;

  AuthProvider() {
    _listenToAuthChanges();
  }

  User? get user => _user;
  UserModel? get currentUserProfile => _currentUserProfile;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _user != null;

  String? get currentUserId => _user?.uid;
  String? get currentUserEmail => _user?.email;
  String? get currentUserRole => _currentUserProfile?.role;
  bool get isCurrentUserOnline => _currentUserProfile?.isOnline ?? false;

  void _listenToAuthChanges() {
    _authSubscription?.cancel();

    _authSubscription = _authService.authStateChanges.listen(
      (User? firebaseUser) async {
        _user = firebaseUser;

        if (firebaseUser == null) {
          await _userProfileSubscription?.cancel();
          _currentUserProfile = null;
          notifyListeners();
          return;
        }

        await _ensureUserDocumentExists(
          uid: firebaseUser.uid,
          email: firebaseUser.email ?? '',
        );

        _listenToUserProfile(firebaseUser.uid);
        await setOnlineStatus(true);
        notifyListeners();
      },
    );
  }

  void _listenToUserProfile(String uid) {
    _userProfileSubscription?.cancel();

    _userProfileSubscription = _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((DocumentSnapshot doc) {
      if (doc.exists) {
        final raw = doc.data();
        final data = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
        _currentUserProfile = UserModel.fromMap(data);
      } else {
        _currentUserProfile = null;
      }

      notifyListeners();
    });
  }

  Future<void> _ensureUserDocumentExists({
    required String uid,
    required String email,
    String? role,
  }) async {
    final docRef = _firestore.collection('users').doc(uid);
    final doc = await docRef.get();

    if (!doc.exists) {
      await docRef.set({
        'userId': uid,
        'email': email,
        'role': role ?? 'user',
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    final existing = doc.data() ?? <String, dynamic>{};

    await docRef.set({
      'userId': uid,
      'email': email,
      'role': role ?? (existing['role'] ?? 'user'),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String role,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final UserCredential userCredential = await _authService.signUpWithEmail(
        email: email,
        password: password,
        role: role,
      );

      _user = userCredential.user;

      if (_user != null) {
        await _ensureUserDocumentExists(
          uid: _user!.uid,
          email: _user!.email ?? email,
          role: role,
        );
        _listenToUserProfile(_user!.uid);
        await setOnlineStatus(true);
      }

      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = e.message ?? 'Signup failed. Please try again.';
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'Something went wrong during signup.';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final UserCredential userCredential = await _authService.loginWithEmail(
        email: email,
        password: password,
      );

      _user = userCredential.user;

      if (_user != null) {
        await _ensureUserDocumentExists(
          uid: _user!.uid,
          email: _user!.email ?? email,
        );
        _listenToUserProfile(_user!.uid);
        await setOnlineStatus(true);
      }

      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = e.message ?? 'Login failed. Please try again.';
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'Something went wrong during login.';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    _setLoading(true);
    _clearError();

    try {
      await setOnlineStatus(false);
      await _authService.logout();
      _user = null;
      _currentUserProfile = null;
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      _errorMessage = e.message ?? 'Logout failed. Please try again.';
      notifyListeners();
    } catch (_) {
      _errorMessage = 'Something went wrong during logout.';
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> setOnlineStatus(bool isOnline) async {
    final uid = currentUserId;
    if (uid == null || uid.isEmpty) return;

    await _firestore.collection('users').doc(uid).set({
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> handleAppLifecycleState(AppLifecycleState state) async {
    if (!isLoggedIn) return;

    if (state == AppLifecycleState.resumed) {
      await setOnlineStatus(true);
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      await setOnlineStatus(false);
    }
  }

  void clearErrorMessage() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _userProfileSubscription?.cancel();
    super.dispose();
  }
}