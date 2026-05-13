import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/exceptions/app_exception.dart';
import '../../core/firebase_providers.dart';

class AuthRepository {
  AuthRepository(this._auth);

  final FirebaseAuth _auth;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (error, stackTrace) {
      throw AppExceptionMapper.from(
        error,
        stackTrace: stackTrace,
        fallbackMessage: 'Sign in failed. Check your details and try again.',
      );
    }
  }

  Future<UserCredential> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (error, stackTrace) {
      throw AppExceptionMapper.from(
        error,
        stackTrace: stackTrace,
        fallbackMessage: 'Sign up failed. Please try again.',
      );
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (error, stackTrace) {
      throw AppExceptionMapper.from(
        error,
        stackTrace: stackTrace,
        fallbackMessage: 'Could not sign out.',
      );
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(firebaseAuthProvider));
});
