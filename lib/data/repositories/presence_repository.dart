import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/exceptions/app_exception.dart';
import '../../core/firebase_providers.dart';
import '../models/member_state.dart';

class PresenceRepository {
  PresenceRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _members(String conversationId) =>
      _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('members');

  /// Watch all member states for a conversation.
  Stream<List<MemberState>> watchMemberStates(String conversationId) {
    return _members(conversationId).snapshots().map((snapshot) {
      return snapshot.docs.map(MemberState.fromDoc).toList();
    }).handleError((error, stackTrace) {
      throw AppExceptionMapper.from(
        error,
        stackTrace: stackTrace,
        fallbackMessage: 'Could not load member states.',
      );
    });
  }

  /// Set typing status with debounce-friendly design.
  Future<void> setTyping({
    required String conversationId,
    required String uid,
    required bool isTyping,
  }) async {
    try {
      await _members(conversationId).doc(uid).set({
        'typing': isTyping,
        'typingUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (error, stackTrace) {
      throw AppExceptionMapper.from(
        error,
        stackTrace: stackTrace,
        fallbackMessage: 'Could not update typing status.',
      );
    }
  }

  /// Update the seen-up-to timestamp for a user.
  Future<void> updateSeenUpTo({
    required String conversationId,
    required String uid,
    required Timestamp timestamp,
  }) async {
    try {
      await _members(conversationId).doc(uid).set({
        'seenUpTo': timestamp,
      }, SetOptions(merge: true));
    } catch (error, stackTrace) {
      throw AppExceptionMapper.from(
        error,
        stackTrace: stackTrace,
        fallbackMessage: 'Could not update seen status.',
      );
    }
  }

  /// Update the delivered-up-to timestamp for a user.
  Future<void> updateDeliveredUpTo({
    required String conversationId,
    required String uid,
    required Timestamp timestamp,
  }) async {
    try {
      await _members(conversationId).doc(uid).set({
        'deliveredUpTo': timestamp,
      }, SetOptions(merge: true));
    } catch (error, stackTrace) {
      throw AppExceptionMapper.from(
        error,
        stackTrace: stackTrace,
        fallbackMessage: 'Could not update delivered status.',
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Riverpod providers
// ---------------------------------------------------------------------------

final presenceRepositoryProvider = Provider<PresenceRepository>((ref) {
  return PresenceRepository(ref.watch(firestoreProvider));
});

final memberStatesProvider =
    StreamProvider.autoDispose.family<List<MemberState>, String>((
  ref,
  conversationId,
) {
  return ref
      .watch(presenceRepositoryProvider)
      .watchMemberStates(conversationId);
});
