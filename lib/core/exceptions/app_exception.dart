import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

class AppException implements Exception {
  const AppException({
    required this.code,
    required this.message,
    this.cause,
    this.stackTrace,
  });

  final String code;
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() => 'AppException($code): $message';
}

class AppExceptionMapper {
  static AppException from(
    Object error, {
    StackTrace? stackTrace,
    String fallbackMessage = 'Something went wrong. Please try again.',
  }) {
    if (error is AppException) {
      return error;
    }

    if (error is FirebaseAuthException) {
      return AppException(
        code: error.code,
        message: error.message ?? fallbackMessage,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    if (error is FirebaseException) {
      String message = error.message ?? fallbackMessage;
      if (error.code == 'failed-precondition' &&
          message.contains('index')) {
        message = 'This query requires a Firestore index. '
            'Please check the debug console for the creation link, '
            'or create it manually in the Firebase Console.';
      }

      return AppException(
        code: error.code,
        message: message,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    if (error is TimeoutException) {
      return AppException(
        code: 'timeout',
        message: 'The request timed out. Check your connection and try again.',
        cause: error,
        stackTrace: stackTrace,
      );
    }

    return AppException(
      code: 'unknown',
      message: fallbackMessage,
      cause: error,
      stackTrace: stackTrace,
    );
  }
}
