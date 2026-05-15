import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/exceptions/app_exception.dart';
import '../../core/firebase_providers.dart';
import '../models/message.dart';

const _uuid = Uuid();

class MessageRepository {
  MessageRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _messages(String conversationId) =>
      _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages');

  DocumentReference<Map<String, dynamic>> _conversation(
          String conversationId) =>
      _firestore.collection('conversations').doc(conversationId);

  /// Real-time stream of messages, excluding those deleted by [currentUid].
  Stream<List<Message>> watchMessages({
    required String conversationId,
    required String currentUid,
  }) {
    return _messages(conversationId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map(Message.fromDoc)
          .where((m) => !m.deletedFor.contains(currentUid))
          .toList();
    }).handleError((error, stackTrace) {
      throw AppExceptionMapper.from(
        error,
        stackTrace: stackTrace,
        fallbackMessage: 'Could not load messages.',
      );
    });
  }

  /// Send a new message and update the conversation preview.
  Future<String> sendMessage({
    required String conversationId,
    required String senderId,
    MessageType type = MessageType.text,
    String? text,
    String? mediaUrl,
    String? thumbUrl,
    int? durationMs,
    CompressionMeta? compression,
  }) async {
    try {
      final messageId = _uuid.v4();
      final messageData = <String, dynamic>{
        'senderId': senderId,
        'type': messageTypeToString(type),
        'text': text,
        'mediaUrl': mediaUrl,
        'thumbUrl': thumbUrl,
        'durationMs': durationMs,
        'reactions': <String, String>{},
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': null,
        'editedAt': null,
        'deletedForEveryone': false,
        'deletedFor': <String>[],
        'compression': compression?.toMap(),
      };

      final batch = _firestore.batch();

      batch.set(_messages(conversationId).doc(messageId), messageData);

      // Build preview text based on type.
      String preview;
      switch (type) {
        case MessageType.image:
          preview = 'Photo';
        case MessageType.video:
          preview = 'Video';
        case MessageType.audio:
          preview = 'Audio';
        case MessageType.system:
          preview = text ?? '';
        case MessageType.text:
          preview = text ?? '';
      }

      batch.update(_conversation(conversationId), {
        'lastMessagePreview': preview,
        'lastMessageType': messageTypeToString(type),
        'lastMessageAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      return messageId;
    } catch (error, stackTrace) {
      throw AppExceptionMapper.from(
        error,
        stackTrace: stackTrace,
        fallbackMessage: 'Could not send message.',
      );
    }
  }

  /// Edit a text message.
  Future<void> editMessage({
    required String conversationId,
    required String messageId,
    required String newText,
  }) async {
    try {
      await _messages(conversationId).doc(messageId).update({
        'text': newText,
        'editedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (error, stackTrace) {
      throw AppExceptionMapper.from(
        error,
        stackTrace: stackTrace,
        fallbackMessage: 'Could not edit message.',
      );
    }
  }

  /// Hide a message for the current user only.
  Future<void> deleteForMe({
    required String conversationId,
    required String messageId,
    required String uid,
  }) async {
    try {
      await _messages(conversationId).doc(messageId).update({
        'deletedFor': FieldValue.arrayUnion([uid]),
      });
    } catch (error, stackTrace) {
      throw AppExceptionMapper.from(
        error,
        stackTrace: stackTrace,
        fallbackMessage: 'Could not delete message.',
      );
    }
  }

  /// Delete a message for everyone.
  Future<void> deleteForEveryone({
    required String conversationId,
    required String messageId,
  }) async {
    try {
      await _messages(conversationId).doc(messageId).update({
        'deletedForEveryone': true,
        'text': null,
        'mediaUrl': null,
        'thumbUrl': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (error, stackTrace) {
      throw AppExceptionMapper.from(
        error,
        stackTrace: stackTrace,
        fallbackMessage: 'Could not delete message.',
      );
    }
  }

  /// Toggle a reaction. If the user already has that emoji, remove it.
  Future<void> toggleReaction({
    required String conversationId,
    required String messageId,
    required String uid,
    required String emoji,
  }) async {
    try {
      final docRef = _messages(conversationId).doc(messageId);
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (!snap.exists) return;
        final data = snap.data()!;
        final reactions =
            Map<String, String>.from((data['reactions'] as Map?) ?? {});

        if (reactions[uid] == emoji) {
          reactions.remove(uid);
        } else {
          reactions[uid] = emoji;
        }

        tx.update(docRef, {'reactions': reactions});
      });
    } catch (error, stackTrace) {
      throw AppExceptionMapper.from(
        error,
        stackTrace: stackTrace,
        fallbackMessage: 'Could not update reaction.',
      );
    }
  }

  /// Client-side search within already-loaded messages.
  List<int> searchMessages({
    required List<Message> messages,
    required String query,
  }) {
    if (query.trim().isEmpty) return [];
    final lower = query.trim().toLowerCase();
    final indices = <int>[];
    for (var i = 0; i < messages.length; i++) {
      final text = messages[i].text?.toLowerCase() ?? '';
      if (text.contains(lower)) {
        indices.add(i);
      }
    }
    return indices;
  }
}

// ---------------------------------------------------------------------------
// Riverpod providers
// ---------------------------------------------------------------------------

final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  return MessageRepository(ref.watch(firestoreProvider));
});

final messagesProvider =
    StreamProvider.autoDispose.family<List<Message>, String>((
  ref,
  conversationId,
) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(const []);
  return ref.watch(messageRepositoryProvider).watchMessages(
        conversationId: conversationId,
        currentUid: user.uid,
      );
});
