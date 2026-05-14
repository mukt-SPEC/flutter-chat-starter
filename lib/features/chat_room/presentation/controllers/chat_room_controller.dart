import 'dart:async';


import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'package:uuid/uuid.dart';

import '../../../../core/firebase_providers.dart';
import '../../../../data/models/member_state.dart';
import '../../../../data/models/message.dart';
import '../../../../data/models/pending_media_job.dart';
import '../../../../data/repositories/media_repository.dart';
import '../../../../data/repositories/message_repository.dart';
import '../../../../data/repositories/offline_queue_repository.dart';
import '../../../../data/repositories/presence_repository.dart';
import '../../../../core/network_provider.dart';

const _uuid = Uuid();

// ---------------------------------------------------------------------------
// Chat Room Controller
// ---------------------------------------------------------------------------

final chatRoomControllerProvider = AutoDisposeAsyncNotifierProviderFamily<
    ChatRoomController, void, String>(ChatRoomController.new);

class ChatRoomController
    extends AutoDisposeFamilyAsyncNotifier<void, String> {
  Timer? _typingDebounce;

  String get _conversationId => arg;

  @override
  Future<void> build(String arg) async {
    ref.onDispose(() => _typingDebounce?.cancel());
  }

  String? get _currentUid => ref.read(currentUserProvider)?.uid;

  // ---- Text messages ----

  Future<void> sendTextMessage(String text) async {
    final uid = _currentUid;
    if (uid == null || text.trim().isEmpty) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      // Check connectivity
      final isOnline = ref.read(connectivityProvider).valueOrNull ?? true;

      if (isOnline) {
        await ref.read(messageRepositoryProvider).sendMessage(
              conversationId: _conversationId,
              senderId: uid,
              type: MessageType.text,
              text: text.trim(),
            );
      } else {
        // Queue for offline
        await ref.read(offlineQueueRepositoryProvider).enqueue(
              PendingMediaJob(
                id: _uuid.v4(),
                conversationId: _conversationId,
                type: PendingMediaType.image, // text uses same queue
                localPath: '', // no file
                text: text.trim(),
                createdAt: DateTime.now(),
              ),
            );
      }

      // Stop typing indicator
      _setTypingRaw(false);
    });
  }

  // ---- Media messages ----

  Future<void> sendMediaMessage({
    required String localPath,
    required MessageType type,
    String? text,
  }) async {
    final uid = _currentUid;
    if (uid == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final mediaRepo = ref.read(mediaRepositoryProvider);
      final msgRepo = ref.read(messageRepositoryProvider);
      final ext = p.extension(localPath);

      String compressedPath = localPath;
      CompressionMeta? compression;
      String? thumbUrl;

      // Compress based on type
      if (type == MessageType.image) {
        final result = await mediaRepo.compressImage(localPath);
        compressedPath = result.$1;
        compression = result.$2;
      } else if (type == MessageType.video) {
        final result = await mediaRepo.compressVideo(localPath);
        compressedPath = result.$1;
        compression = result.$2;

        // Generate thumbnail
        final thumbPath =
            await mediaRepo.generateVideoThumbnail(localPath);
        if (thumbPath != null) {
          final thumbStoragePath = mediaRepo.generateStoragePath(
            conversationId: _conversationId,
            extension: '.jpg',
          );
          thumbUrl = await mediaRepo.uploadFile(
            localPath: thumbPath,
            storagePath: thumbStoragePath,
          );
        }
      }

      // Upload compressed file
      final storagePath = mediaRepo.generateStoragePath(
        conversationId: _conversationId,
        extension: ext,
      );
      final mediaUrl = await mediaRepo.uploadFile(
        localPath: compressedPath,
        storagePath: storagePath,
      );

      await msgRepo.sendMessage(
        conversationId: _conversationId,
        senderId: uid,
        type: type,
        text: text,
        mediaUrl: mediaUrl,
        thumbUrl: thumbUrl,
        compression: compression,
      );
    });
  }

  // ---- Audio messages ----

  Future<void> sendAudioMessage({
    required String localPath,
    required int durationMs,
  }) async {
    final uid = _currentUid;
    if (uid == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final mediaRepo = ref.read(mediaRepositoryProvider);
      final msgRepo = ref.read(messageRepositoryProvider);
      final ext = p.extension(localPath);

      final storagePath = mediaRepo.generateStoragePath(
        conversationId: _conversationId,
        extension: ext.isEmpty ? '.m4a' : ext,
      );
      final mediaUrl = await mediaRepo.uploadFile(
        localPath: localPath,
        storagePath: storagePath,
      );

      await msgRepo.sendMessage(
        conversationId: _conversationId,
        senderId: uid,
        type: MessageType.audio,
        mediaUrl: mediaUrl,
        durationMs: durationMs,
      );
    });
  }

  // ---- Edit / Delete ----

  Future<void> editMessage(String messageId, String newText) async {
    if (newText.trim().isEmpty) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(messageRepositoryProvider).editMessage(
            conversationId: _conversationId,
            messageId: messageId,
            newText: newText.trim(),
          );
    });
  }

  Future<void> deleteForMe(String messageId) async {
    final uid = _currentUid;
    if (uid == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(messageRepositoryProvider).deleteForMe(
            conversationId: _conversationId,
            messageId: messageId,
            uid: uid,
          );
    });
  }

  Future<void> deleteForEveryone(String messageId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(messageRepositoryProvider).deleteForEveryone(
            conversationId: _conversationId,
            messageId: messageId,
          );
    });
  }

  // ---- Reactions ----

  Future<void> toggleReaction(String messageId, String emoji) async {
    final uid = _currentUid;
    if (uid == null) return;
    // Fire and forget â€” no loading state for reactions
    ref.read(messageRepositoryProvider).toggleReaction(
          conversationId: _conversationId,
          messageId: messageId,
          uid: uid,
          emoji: emoji,
        );
  }

  // ---- Typing ----

  void onTextChanged(String text) {
    _typingDebounce?.cancel();
    if (text.isNotEmpty) {
      _setTypingRaw(true);
      _typingDebounce = Timer(const Duration(milliseconds: 2000), () {
        _setTypingRaw(false);
      });
    } else {
      _setTypingRaw(false);
    }
  }

  void _setTypingRaw(bool isTyping) {
    final uid = _currentUid;
    if (uid == null) return;
    ref.read(presenceRepositoryProvider).setTyping(
          conversationId: _conversationId,
          uid: uid,
          isTyping: isTyping,
        );
  }

  // ---- Read receipts ----

  Future<void> markAsSeen(Timestamp messageTimestamp) async {
    final uid = _currentUid;
    if (uid == null) return;
    await ref.read(presenceRepositoryProvider).updateSeenUpTo(
          conversationId: _conversationId,
          uid: uid,
          timestamp: messageTimestamp,
        );
  }

  Future<void> markAsDelivered(Timestamp messageTimestamp) async {
    final uid = _currentUid;
    if (uid == null) return;
    await ref.read(presenceRepositoryProvider).updateDeliveredUpTo(
          conversationId: _conversationId,
          uid: uid,
          timestamp: messageTimestamp,
        );
  }


}

// ---------------------------------------------------------------------------
// Derived providers for the chat room UI
// ---------------------------------------------------------------------------

/// Whether the other user is currently typing.
final otherUserTypingProvider =
    Provider.autoDispose.family<bool, String>((ref, conversationId) {
  final uid = ref.watch(currentUserProvider)?.uid;
  final membersAsync = ref.watch(memberStatesProvider(conversationId));

  return membersAsync.maybeWhen(
    data: (members) {
      for (final m in members) {
        if (m.uid != uid && m.typing) {
          // Auto-expire after 5s to handle stale typing flags
          if (m.typingUpdatedAt != null) {
            final age = DateTime.now()
                .difference(m.typingUpdatedAt!.toDate())
                .inSeconds;
            if (age > 5) continue;
          }
          return true;
        }
      }
      return false;
    },
    orElse: () => false,
  );
});

/// The other user's MemberState (for read receipts).
final otherMemberStateProvider =
    Provider.autoDispose.family<MemberState?, String>((ref, conversationId) {
  final uid = ref.watch(currentUserProvider)?.uid;
  final membersAsync = ref.watch(memberStatesProvider(conversationId));

  return membersAsync.maybeWhen(
    data: (members) {
      for (final m in members) {
        if (m.uid != uid) return m;
      }
      return null;
    },
    orElse: () => null,
  );
});

// ---------------------------------------------------------------------------
// In-chat search providers
// ---------------------------------------------------------------------------

final chatSearchActiveProvider =
    StateProvider.autoDispose.family<bool, String>((ref, _) => false);

final inChatSearchQueryProvider =
    StateProvider.autoDispose.family<String, String>((ref, _) => '');

final chatSearchResultsProvider =
    Provider.autoDispose.family<List<int>, String>((ref, conversationId) {
  final query = ref.watch(inChatSearchQueryProvider(conversationId));
  final messagesAsync = ref.watch(messagesProvider(conversationId));

  return messagesAsync.maybeWhen(
    data: (messages) {
      return ref.read(messageRepositoryProvider).searchMessages(
            messages: messages,
            query: query,
          );
    },
    orElse: () => [],
  );
});

final chatSearchIndexProvider =
    StateProvider.autoDispose.family<int, String>((ref, _) => 0);
