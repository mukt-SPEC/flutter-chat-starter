import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/exceptions/app_exception.dart';
import '../../../../core/firebase_providers.dart';
import '../../../../core/ui_states.dart';
import '../../../../data/models/conversation.dart';
import '../../../../data/models/user_profile.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../chat_room/presentation/screens/chat_room_screen.dart';
import '../../../new_chat/presentation/controllers/new_chat_controller.dart';
import '../controllers/chat_list_controller.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(filteredConversationsProvider);
    final currentUser = ref.watch(currentUserProvider);
    final searchQuery = ref.watch(chatSearchQueryProvider);

    if (currentUser == null) {
      return const Scaffold(
        body: AppErrorState(
          message: 'You are signed out. Please log in again.',
        ),
      );
    }

    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'chat-search-fab',
            onPressed: () => _showChatSearchDialog(context, ref),
            child: const Icon(Icons.search),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'new-chat-fab',
            onPressed: () => _showNewChatModal(context, ref),
            child: const Icon(Icons.add_comment_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Row(
                children: [
                  Text(
                    'Chats',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Log out',
                    onPressed: () async {
                      try {
                        await ref.read(authControllerProvider.notifier).signOut();
                      } catch (error) {
                        if (!context.mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(_readableError(error))),
                        );
                      }
                    },
                    icon: const Icon(Icons.logout),
                  ),
                ],
              ),
            ),
            if (searchQuery.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Filtering by: "$searchQuery"',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).primaryColor.withValues(alpha: 0.6),
                            ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        ref.read(chatSearchQueryProvider.notifier).clear();
                      },
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: conversationsAsync.when(
                loading: () => const AppLoadingState(message: 'Loading chats...'),
                error: (error, _) => AppErrorState(
                  message: _readableError(error),
                  onRetry: () => ref.refresh(conversationsProvider),
                ),
                data: (conversations) {
                  if (conversations.isEmpty) {
                    return AppEmptyState(
                      title: searchQuery.isEmpty
                          ? 'No chats yet'
                          : 'No matching chats',
                      subtitle: searchQuery.isEmpty
                          ? 'Tap the new chat button to start a conversation.'
                          : 'Try a different search term.',
                      icon: searchQuery.isEmpty
                          ? Icons.chat_bubble_outline
                          : Icons.search_off,
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                    itemCount: conversations.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final conversation = conversations[index];
                      final otherUserId = conversation.participants.firstWhere(
                        (id) => id != currentUser.uid,
                        orElse: () => '',
                      );

                      return _ConversationTile(
                        conversation: conversation,
                        otherUserId: otherUserId,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                conversationId: conversation.id,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  const _ConversationTile({
    required this.conversation,
    required this.otherUserId,
    required this.onTap,
  });

  final Conversation conversation;
  final String otherUserId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = otherUserId.isEmpty
        ? const AsyncData<UserProfile?>(null)
        : ref.watch(userProfileByIdProvider(otherUserId));

    final displayName = userAsync.maybeWhen(
      data: (profile) {
        if (profile == null) {
          return otherUserId.isEmpty ? 'Unknown chat' : otherUserId;
        }
        return profile.displayName.isEmpty ? profile.email : profile.displayName;
      },
      loading: () => 'Loading...',
      orElse: () => otherUserId.isEmpty ? 'Unknown chat' : 'Loading...',
    );

    final subtitle = conversation.lastMessagePreview?.trim().isNotEmpty == true
        ? conversation.lastMessagePreview!.trim()
        : 'No messages yet';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      leading: CircleAvatar(
        child: Text(displayName.isEmpty ? '?' : displayName[0].toUpperCase()),
      ),
      title: Text(
        displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: _TimeLabel(timestamp: conversation.lastMessageAt),
      onTap: onTap,
    );
  }
}

class _TimeLabel extends StatelessWidget {
  const _TimeLabel({required this.timestamp});

  final Timestamp? timestamp;

  @override
  Widget build(BuildContext context) {
    if (timestamp == null) {
      return const SizedBox.shrink();
    }
    final dt = timestamp!.toDate();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return Text('$hh:$mm', style: Theme.of(context).textTheme.bodySmall);
  }
}

Future<void> _showChatSearchDialog(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController(
    text: ref.read(chatSearchQueryProvider),
  );
  final value = await showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Search chats'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Search by last message text',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('Clear'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Apply'),
          ),
        ],
      );
    },
  );

  if (!context.mounted || value == null) {
    return;
  }
  ref.read(chatSearchQueryProvider.notifier).setQuery(value);
}

Future<void> _showNewChatModal(BuildContext context, WidgetRef ref) async {
  final conversationId = await showCupertinoModalPopup<String>(
    context: context,
    builder: (_) => const _NewChatCupertinoModal(),
  );

  if (!context.mounted || conversationId == null) {
    return;
  }

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ChatScreen(conversationId: conversationId),
    ),
  );
}

class _NewChatCupertinoModal extends ConsumerStatefulWidget {
  const _NewChatCupertinoModal();

  @override
  ConsumerState<_NewChatCupertinoModal> createState() =>
      _NewChatCupertinoModalState();
}

class _NewChatCupertinoModalState
    extends ConsumerState<_NewChatCupertinoModal> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(searchedUsersProvider);
    final existingPartners = ref.watch(existingChatPartnerIdsProvider);
    final isCreating = ref.watch(newChatControllerProvider).isLoading;

    return CupertinoActionSheet(
      title: const Text('New chat'),
      message: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            CupertinoSearchTextField(
              controller: _searchController,
              placeholder: 'Search by email or display name',
              onChanged: (value) {
                ref.read(newChatSearchQueryProvider.notifier).state = value;
              },
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 280),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground.resolveFrom(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: usersAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(18),
                  child: CupertinoActivityIndicator(),
                ),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _readableError(error),
                    textAlign: TextAlign.center,
                  ),
                ),
                data: (users) {
                  final query = ref.watch(newChatSearchQueryProvider).trim();
                  if (query.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(14),
                      child: Text('Start typing to search for a user.'),
                    );
                  }
                  if (users.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(14),
                      child: Text('No user found.'),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: users.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final user = users[index];
                      final hasExisting = existingPartners.contains(user.uid);
                      return ListTile(
                        enabled: !isCreating,
                        leading: CircleAvatar(
                          child: Text(
                            user.displayName.isEmpty
                                ? user.email[0].toUpperCase()
                                : user.displayName[0].toUpperCase(),
                          ),
                        ),
                        title: Text(
                          user.displayName.isEmpty ? user.email : user.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          user.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: hasExisting
                            ? const Chip(
                                label: Text('Existing'),
                                visualDensity: VisualDensity.compact,
                              )
                            : null,
                        onTap: () => _onUserSelected(context, user),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      cancelButton: CupertinoActionSheetAction(
        isDefaultAction: true,
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Close'),
      ),
    );
  }

  Future<void> _onUserSelected(BuildContext context, UserProfile user) async {
    try {
      final conversationId = await ref
          .read(newChatControllerProvider.notifier)
          .createOrGetConversation(user.uid);
      if (!context.mounted) {
        return;
      }
      Navigator.of(context).pop(conversationId);
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_readableError(error))),
      );
    }
  }
}

String _readableError(Object error) {
  if (error is AppException) {
    return error.message;
  }
  return error.toString();
}
