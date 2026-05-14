import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_chat_starter/core/firebase_providers.dart';
import 'package:flutter_chat_starter/data/models/user_profile.dart';
import 'package:flutter_chat_starter/data/repositories/conversation_repository.dart';
import 'package:flutter_chat_starter/data/repositories/user_repository.dart';

final newChatSearchQueryProvider = StateProvider.autoDispose<String>((ref) {
  return '';
});

final searchedUsersProvider = FutureProvider.autoDispose<List<UserProfile>>((
  ref,
) async {
  final currentUser = ref.watch(currentUserProvider);
  final query = ref.watch(newChatSearchQueryProvider).trim();

  if (currentUser == null || query.isEmpty) {
    return const [];
  }

  return ref.watch(userRepositoryProvider).searchByEmailOrDisplayName(
        query: query,
        excludeUid: currentUser.uid,
      );
});

final newChatControllerProvider =
    AutoDisposeAsyncNotifierProvider<NewChatController, void>(
  NewChatController.new,
);

class NewChatController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<String> createOrGetConversation(String otherUserId) async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) {
      throw StateError('You must be signed in.');
    }

    state = const AsyncLoading();
    try {
      final conversationId =
          await ref.read(conversationRepositoryProvider).createOrGetOneToOne(
                currentUid: currentUser.uid,
                otherUid: otherUserId,
              );
      state = const AsyncData(null);
      return conversationId;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}
