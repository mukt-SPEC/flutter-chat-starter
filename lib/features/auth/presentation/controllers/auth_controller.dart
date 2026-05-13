import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_chat_starter/core/exceptions/app_exception.dart';
import 'package:flutter_chat_starter/data/repositories/auth_repository.dart';
import 'package:flutter_chat_starter/data/repositories/user_repository.dart';

final authControllerProvider =
    AutoDisposeAsyncNotifierProvider<AuthController, void>(AuthController.new);

class AuthController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty || password.isEmpty) {
      state = AsyncError(
        const AppException(
          code: 'validation',
          message: 'Email and password are required.',
        ),
        StackTrace.current,
      );
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final credential = await ref
          .read(authRepositoryProvider)
          .signInWithEmailAndPassword(
            email: normalizedEmail,
            password: password,
          );

      final user = credential.user;
      if (user != null) {
        await ref.read(userRepositoryProvider).upsertFromFirebaseUser(user);
      }
    });
  }

  Future<void> signUp({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty || password.isEmpty) {
      state = AsyncError(
        const AppException(
          code: 'validation',
          message: 'Email and password are required.',
        ),
        StackTrace.current,
      );
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final credential = await ref
          .read(authRepositoryProvider)
          .signUpWithEmailAndPassword(
            email: normalizedEmail,
            password: password,
          );

      final user = credential.user;
      if (user != null) {
        await ref.read(userRepositoryProvider).upsertFromFirebaseUser(user);
      }
    });
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final currentUser = ref.read(authRepositoryProvider).currentUser;
      if (currentUser != null) {
        await ref.read(userRepositoryProvider).updateLastSeen(currentUser.uid);
      }
      await ref.read(authRepositoryProvider).signOut();
    });
  }

  static String toReadableError(Object error) {
    if (error is AppException) {
      return error.message;
    }
    if (error is FirebaseAuthException) {
      return error.message ?? error.code;
    }
    return error.toString();
  }
}
