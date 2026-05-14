import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_chat_starter/core/firebase_providers.dart';
import 'package:flutter_chat_starter/data/models/conversation.dart';
import 'package:flutter_chat_starter/data/models/user_profile.dart';
import 'package:flutter_chat_starter/data/repositories/conversation_repository.dart';
import 'package:flutter_chat_starter/data/repositories/user_repository.dart';

final chatSearchQueryProvider =
    AutoDisposeNotifierProvider<ChatSearchQueryController, String>(
  ChatSearchQueryController.new,
);

class ChatSearchQueryController extends AutoDisposeNotifier<String> {
  @override
  String build() => '';

  void setQuery(String value) {
    state = value.trim().toLowerCase();
  }

  void clear() {
    state = '';
  }
}

final conversationsProvider = StreamProvider.autoDispose<List<Conversation>>((
  ref,
) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return Stream.value(const []);
  }
  return ref
      .watch(conversationRepositoryProvider)
      .watchConversationsForUser(user.uid);
});

final filteredConversationsProvider =
    Provider.autoDispose<AsyncValue<List<Conversation>>>((ref) {
  final query = ref.watch(chatSearchQueryProvider);
  final conversationsAsync = ref.watch(conversationsProvider);

  return conversationsAsync.whenData((conversations) {
    if (query.isEmpty) {
      return conversations;
    }

    return conversations.where((conversation) {
      final text = (conversation.lastMessagePreview ?? '').toLowerCase();
      return text.contains(query);
    }).toList();
  });
});

final existingChatPartnerIdsProvider = Provider.autoDispose<Set<String>>((ref) {
  final uid = ref.watch(currentUserProvider)?.uid;
  final asyncConversations = ref.watch(conversationsProvider);

  return asyncConversations.maybeWhen(
    data: (conversations) {
      if (uid == null) {
        return <String>{};
      }

      final ids = <String>{};
      for (final conversation in conversations) {
        for (final participant in conversation.participants) {
          if (participant != uid) {
            ids.add(participant);
          }
        }
      }
      return ids;
    },
    orElse: () => <String>{},
  );
});

final userProfileByIdProvider =
    FutureProvider.autoDispose.family<UserProfile?, String>((ref, uid) {
  return ref.watch(userRepositoryProvider).getById(uid);
});
