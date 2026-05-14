import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/exceptions/app_exception.dart';
import '../../core/firebase_providers.dart';
import '../models/conversation.dart';

class ConversationRepository {
  ConversationRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _conversations =>
      _firestore.collection('conversations');

  Stream<List<Conversation>> watchConversationsForUser(String uid) {
    return _conversations
        .where('participants', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map(Conversation.fromDoc).toList();
    }).handleError((error, stackTrace) {
      throw AppExceptionMapper.from(
        error,
        stackTrace: stackTrace,
        fallbackMessage: 'Could not load chats.',
      );
    });
  }

  Future<String?> getConversationIdForPair({
    required String currentUid,
    required String otherUid,
  }) async {
    try {
      final sorted = [currentUid, otherUid]..sort();
      final participantKey = '${sorted[0]}_${sorted[1]}';

      final query = await _conversations
          .where('participantKey', isEqualTo: participantKey)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        return null;
      }

      return query.docs.first.id;
    } catch (error, stackTrace) {
      throw AppExceptionMapper.from(
        error,
        stackTrace: stackTrace,
        fallbackMessage: 'Could not check existing chat.',
      );
    }
  }

  Future<String> createOrGetOneToOne({
    required String currentUid,
    required String otherUid,
  }) async {
    if (currentUid == otherUid) {
      throw const AppException(
        code: 'invalid-user',
        message: 'You cannot start a chat with yourself.',
      );
    }

    try {
      final sorted = [currentUid, otherUid]..sort();
      final participantKey = '${sorted[0]}_${sorted[1]}';

      return _firestore.runTransaction((tx) async {
        final existing = await _conversations
            .where('participantKey', isEqualTo: participantKey)
            .limit(1)
            .get();

        if (existing.docs.isNotEmpty) {
          return existing.docs.first.id;
        }

        final conversationDoc = _conversations.doc();
        tx.set(conversationDoc, {
          'participants': sorted,
          'participantKey': participantKey,
          'lastMessagePreview': '',
          'lastMessageType': 'system',
          'lastMessageAt': FieldValue.serverTimestamp(),
          'createdBy': currentUid,
          'createdAt': FieldValue.serverTimestamp(),
        });

        for (final uid in sorted) {
          tx.set(conversationDoc.collection('members').doc(uid), {
            'typing': false,
            'typingUpdatedAt': FieldValue.serverTimestamp(),
            'deliveredUpTo': null,
            'seenUpTo': null,
            'muted': false,
          });
        }

        return conversationDoc.id;
      });
    } catch (error, stackTrace) {
      throw AppExceptionMapper.from(
        error,
        stackTrace: stackTrace,
        fallbackMessage: 'Could not create chat.',
      );
    }
  }
}

final conversationRepositoryProvider = Provider<ConversationRepository>((ref) {
  return ConversationRepository(ref.watch(firestoreProvider));
});
