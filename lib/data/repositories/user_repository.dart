import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_chat_starter/core/exceptions/app_exception.dart';
import 'package:flutter_chat_starter/core/firebase_providers.dart';
import 'package:flutter_chat_starter/data/models/user_profile.dart';

class UserRepository {
  UserRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Future<void> upsertFromFirebaseUser(User user) async {
    try {
      final profile = UserProfile.fromFirebaseUser(user);
      final displayName = profile.displayName.trim();
      final email = profile.email.trim();
      await _users.doc(user.uid).set({
        ...profile.toMap(),
        'displayNameLower': displayName.toLowerCase(),
        'emailLower': email.toLowerCase(),
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeenAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (error, stackTrace) {
      throw AppExceptionMapper.from(
        error,
        stackTrace: stackTrace,
        fallbackMessage: 'Could not save your profile.',
      );
    }
  }

  Future<void> updateLastSeen(String uid) async {
    try {
      await _users.doc(uid).set({
        'lastSeenAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (error, stackTrace) {
      throw AppExceptionMapper.from(
        error,
        stackTrace: stackTrace,
        fallbackMessage: 'Could not update last seen.',
      );
    }
  }

  Future<UserProfile?> getById(String uid) async {
    try {
      final doc = await _users.doc(uid).get();
      if (!doc.exists) {
        return null;
      }
      return UserProfile.fromDoc(doc);
    } catch (error, stackTrace) {
      throw AppExceptionMapper.from(
        error,
        stackTrace: stackTrace,
        fallbackMessage: 'Could not load user profile.',
      );
    }
  }

  Future<List<UserProfile>> searchByEmailOrDisplayName({
    required String query,
    required String excludeUid,
    int limit = 15,
  }) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const [];
    }

    try {
      final displayFuture = _users
          .orderBy('displayNameLower')
          .startAt([normalized])
          .endAt(['$normalized\uf8ff'])
          .limit(limit)
          .get();

      final emailFuture = _users
          .orderBy('emailLower')
          .startAt([normalized])
          .endAt(['$normalized\uf8ff'])
          .limit(limit)
          .get();

      final results = await Future.wait([displayFuture, emailFuture]);
      final byUid = <String, UserProfile>{};

      for (final querySnapshot in results) {
        for (final doc in querySnapshot.docs) {
          final profile = UserProfile.fromDoc(doc);
          if (profile.uid == excludeUid) {
            continue;
          }
          byUid[profile.uid] = profile;
        }
      }

      final users = byUid.values.toList()
        ..sort((a, b) => a.displayName.compareTo(b.displayName));
      return users;
    } catch (error, stackTrace) {
      throw AppExceptionMapper.from(
        error,
        stackTrace: stackTrace,
        fallbackMessage: 'Could not search users.',
      );
    }
  }
}

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.watch(firestoreProvider));
});
