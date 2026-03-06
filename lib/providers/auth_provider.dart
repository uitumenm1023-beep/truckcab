import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  User? _user;
  bool _isLoading = false;
  String? _errorMessage;

  AuthProvider() {
    _listenToAuthChanges();
  }

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _user != null;

  String? get currentUserId => _user?.uid;
  String? get currentUserEmail => _user?.email;

  void _listenToAuthChanges() {
    _authService.authStateChanges.listen((User? firebaseUser) {
      _user = firebaseUser;
      notifyListeners();
    });
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
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = e.message ?? 'Signup failed. Please try again.';
      notifyListeners();
      return false;
    } catch (e) {
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
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = e.message ?? 'Login failed. Please try again.';
      notifyListeners();
      return false;
    } catch (e) {
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
      await _authService.logout();
      _user = null;
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      _errorMessage = e.message ?? 'Logout failed. Please try again.';
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Something went wrong during logout.';
      notifyListeners();
    } finally {
      _setLoading(false);
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
}