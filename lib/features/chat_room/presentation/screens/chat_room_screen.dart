
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../core/exceptions/app_exception.dart';
import '../../../../core/firebase_providers.dart';
import '../../../../core/theme.dart';
import '../../../../core/ui_states.dart';
import '../../../../data/models/message.dart';
import '../../../../data/models/user_profile.dart';
import '../../../../data/repositories/message_repository.dart';

import '../../../chat_list/presentation/controllers/chat_list_controller.dart';
import '../controllers/chat_room_controller.dart';
import '../widgets/message_bubble.dart';
import '../widgets/reaction_bar.dart';
import '../widgets/typing_indicator.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  const ChatScreen({super.key, required this.conversationId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with WidgetsBindingObserver {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _picker = ImagePicker();

  // Audio recording
  AudioRecorder? _recorder;
  bool _isRecording = false;
  DateTime? _recordStartTime;
  Timer? _recordTimer;
  String _recordDuration = '00:00';

  // Edit mode
  String? _editingMessageId;
  String? _editingOriginalText;

  String get _conversationId => widget.conversationId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _recorder = AudioRecorder();

    // Mark messages as delivered when entering
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markLatestAsDelivered();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _textController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _recorder?.dispose();
    _recordTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _markLatestAsSeen();
    }
  }

  void _markLatestAsDelivered() {
    final messages =
        ref.read(messagesProvider(_conversationId)).valueOrNull ?? [];
    if (messages.isEmpty) return;
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;
    // Find latest message not from us
    for (final m in messages) {
      if (m.senderId != uid) {
        ref
            .read(chatRoomControllerProvider(_conversationId).notifier)
            .markAsDelivered(m.createdAt);
        break;
      }
    }
  }

  void _markLatestAsSeen() {
    final messages =
        ref.read(messagesProvider(_conversationId)).valueOrNull ?? [];
    if (messages.isEmpty) return;
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;
    for (final m in messages) {
      if (m.senderId != uid) {
        ref
            .read(chatRoomControllerProvider(_conversationId).notifier)
            .markAsSeen(m.createdAt);
        break;
      }
    }
  }

  // ------------------------------------------------------------------
  // Build
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesProvider(_conversationId));
    final isTyping = ref.watch(otherUserTypingProvider(_conversationId));
    final searchActive =
        ref.watch(chatSearchActiveProvider(_conversationId));
    final otherMember =
        ref.watch(otherMemberStateProvider(_conversationId));

    // Get the other user's profile
    final currentUid = ref.watch(currentUserProvider)?.uid ?? '';
    final conversationsAsync = ref.watch(filteredConversationsProvider);
    String otherUid = '';
    conversationsAsync.whenData((convos) {
      final match = convos.where((c) => c.id == _conversationId).firstOrNull;
      if (match != null) {
        otherUid = match.participants.firstWhere(
          (p) => p != currentUid,
          orElse: () => '',
        );
      }
    });
    // Fallback: derive from messages
    if (otherUid.isEmpty) {
      messagesAsync.whenData((msgs) {
        for (final m in msgs) {
          if (m.senderId != currentUid) {
            otherUid = m.senderId;
            break;
          }
        }
      });
    }

    final otherUserAsync = otherUid.isNotEmpty
        ? ref.watch(userProfileByIdProvider(otherUid))
        : const AsyncData<UserProfile?>(null);

    final otherUser = otherUserAsync.valueOrNull;
    final displayName = otherUser?.displayName ?? otherUser?.email ?? 'Chat';

    // Mark as seen whenever messages update
    ref.listen(messagesProvider(_conversationId), (prev, next) {
      next.whenData((_) => _markLatestAsSeen());
    });

    return Scaffold(
      appBar: searchActive
          ? _buildSearchAppBar(context)
          : _buildNormalAppBar(context, displayName, otherUser),
      body: Column(
        children: [
          // Message list
          Expanded(
            child: messagesAsync.when(
              loading: () =>
                  const AppLoadingState(message: 'Loading messages...'),
              error: (error, _) => AppErrorState(
                message: _readableError(error),
                onRetry: () => ref.refresh(messagesProvider(_conversationId)),
              ),
              data: (messages) {
                if (messages.isEmpty) {
                  return const AppEmptyState(
                    title: 'No messages yet',
                    subtitle: 'Send a message to start the conversation.',
                    icon: Icons.chat_bubble_outline,
                  );
                }

                final searchQuery = ref.watch(
                    inChatSearchQueryProvider(_conversationId));
                final searchResults = ref.watch(
                    chatSearchResultsProvider(_conversationId));
                final searchIndex = ref.watch(
                    chatSearchIndexProvider(_conversationId));

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
                  itemCount: messages.length + 1, // +1 for typing indicator
                  itemBuilder: (context, index) {
                    // Typing indicator at position 0 (bottom of reversed list)
                    if (index == 0) {
                      return TypingIndicator(
                        isVisible: isTyping,
                        userName: otherUser?.displayName,
                      );
                    }

                    final msgIndex = index - 1;
                    final message = messages[msgIndex];
                    final isMine = message.senderId == currentUid;

                    final bool showDateSeparator = msgIndex == messages.length - 1 ||
                        !_isSameDay(
                          messages[msgIndex].createdAt.toDate(),
                          messages[msgIndex + 1].createdAt.toDate(),
                        );

                    // Search highlight
                    final isSearchMatch =
                        searchActive && searchResults.contains(msgIndex);
                    final isFocused = searchActive &&
                        searchResults.isNotEmpty &&
                        searchIndex < searchResults.length &&
                        searchResults[searchIndex] == msgIndex;

                    return Column(
                      children: [
                        if (showDateSeparator)
                          _DateSeparator(date: message.createdAt.toDate()),
                        Container(
                          color: isFocused
                              ? const Color(0x22FFD54F)
                              : null,
                          child: MessageBubble(
                            message: message,
                            isMine: isMine,
                            otherMemberState: isMine ? otherMember : null,
                            searchHighlight:
                                isSearchMatch ? searchQuery : null,
                            onLongPress: () =>
                                _showReactionOverlay(context, message, isMine),
                            onReactionTap: (emoji) {
                              ref
                                  .read(chatRoomControllerProvider(
                                          _conversationId)
                                      .notifier)
                                  .toggleReaction(message.id, emoji);
                            },
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          // Input bar
          _buildInputBar(context),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // App bar variants
  // ------------------------------------------------------------------

  PreferredSizeWidget _buildNormalAppBar(
    BuildContext context,
    String displayName,
    UserProfile? otherUser,
  ) {
    final lastSeen = otherUser?.lastSeenAt?.toDate();
    final subtitle = lastSeen != null
        ? 'last seen ${timeago.format(lastSeen)}'
        : null;

    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(displayName, style: const TextStyle(fontSize: 17)),
          if (subtitle != null)
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Search in chat',
          onPressed: () {
            ref.read(chatSearchActiveProvider(_conversationId).notifier).state =
                true;
          },
        ),
      ],
    );
  }

  PreferredSizeWidget _buildSearchAppBar(BuildContext context) {
    final results =
        ref.watch(chatSearchResultsProvider(_conversationId));
    final index =
        ref.watch(chatSearchIndexProvider(_conversationId));

    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () {
          ref.read(chatSearchActiveProvider(_conversationId).notifier).state =
              false;
          ref.read(inChatSearchQueryProvider(_conversationId).notifier).state =
              '';
          _searchController.clear();
        },
      ),
      title: TextField(
        controller: _searchController,
        autofocus: true,
        style: const TextStyle(color: AppTheme.white),
        decoration: const InputDecoration(
          hintText: 'Search messages...',
          hintStyle: TextStyle(color: Colors.white54),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
        ),
        onChanged: (value) {
          ref
              .read(inChatSearchQueryProvider(_conversationId).notifier)
              .state = value;
          ref
              .read(chatSearchIndexProvider(_conversationId).notifier)
              .state = 0;
        },
      ),
      actions: [
        if (results.isNotEmpty)
          Text(
            '${index + 1}/${results.length}',
            style: const TextStyle(fontSize: 13),
          ),
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_up),
          onPressed: results.isEmpty
              ? null
              : () {
                  final newIndex =
                      (index - 1).clamp(0, results.length - 1);
                  ref
                      .read(chatSearchIndexProvider(_conversationId)
                          .notifier)
                      .state = newIndex;
                  _scrollToIndex(results[newIndex]);
                },
        ),
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: results.isEmpty
              ? null
              : () {
                  final newIndex =
                      (index + 1).clamp(0, results.length - 1);
                  ref
                      .read(chatSearchIndexProvider(_conversationId)
                          .notifier)
                      .state = newIndex;
                  _scrollToIndex(results[newIndex]);
                },
        ),
      ],
    );
  }

  void _scrollToIndex(int msgIndex) {
    // Approximate scroll â€” in a reversed list, index 0 is at the bottom.
    // We add 1 because index 0 is the typing indicator.
    final targetIndex = msgIndex + 1;
    // Simple approach: animate to estimated position.
    // For a production app, use ScrollablePositionedList.
    _scrollController.animateTo(
      targetIndex * 80.0, // rough estimate
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  // ------------------------------------------------------------------
  // Input bar
  // ------------------------------------------------------------------

  Widget _buildInputBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Edit mode banner
            if (_editingMessageId != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppTheme.surfaceLight,
                child: Row(
                  children: [
                    const Icon(Icons.edit, size: 16, color: AppTheme.greyMedium),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Editing: ${_editingOriginalText ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.greyMedium,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: _cancelEdit,
                      child: const Icon(
                          Icons.close, size: 18, color: AppTheme.greyMedium),
                    ),
                  ],
                ),
              ),
            // Recording indicator
            if (_isRecording)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: Colors.red.shade50,
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Recording $_recordDuration',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _cancelRecording,
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            // Input row
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Attachment button
                  IconButton(
                    icon: const Icon(Icons.attach_file),
                    color: AppTheme.greyMedium,
                    onPressed: _isRecording ? null : _showAttachmentOptions,
                  ),
                  // Text field
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      maxLines: 5,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Type a message',
                        hintStyle:
                            TextStyle(color: AppTheme.greyMedium.withValues(alpha: 0.7)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide:
                              BorderSide(color: AppTheme.greyMedium.withValues(alpha: 0.4)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide:
                              BorderSide(color: AppTheme.greyMedium.withValues(alpha: 0.4)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide:
                              const BorderSide(color: AppTheme.primaryDark, width: 1.5),
                        ),
                        filled: true,
                        fillColor: AppTheme.surfaceLight,
                      ),
                      onChanged: (text) {
                        ref
                            .read(chatRoomControllerProvider(_conversationId)
                                .notifier)
                            .onTextChanged(text);
                        setState(() {}); // Rebuild for send/mic toggle
                      },
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Send or Record button
                  _textController.text.trim().isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.send),
                          color: AppTheme.primaryDark,
                          onPressed: _sendOrEdit,
                        )
                      : GestureDetector(
                          onLongPressStart: (_) => _startRecording(),
                          onLongPressEnd: (_) => _stopRecording(),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _isRecording
                                  ? Colors.red
                                  : AppTheme.primaryDark,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isRecording ? Icons.stop : Icons.mic,
                              color: AppTheme.white,
                              size: 22,
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Actions
  // ------------------------------------------------------------------

  void _sendOrEdit() {
    final text = _textController.text;
    if (text.trim().isEmpty) return;

    if (_editingMessageId != null) {
      ref
          .read(chatRoomControllerProvider(_conversationId).notifier)
          .editMessage(_editingMessageId!, text);
      _cancelEdit();
    } else {
      ref
          .read(chatRoomControllerProvider(_conversationId).notifier)
          .sendTextMessage(text);
    }
    _textController.clear();
    setState(() {});
  }

  void _cancelEdit() {
    setState(() {
      _editingMessageId = null;
      _editingOriginalText = null;
      _textController.clear();
    });
  }

  void _startEditing(Message message) {
    setState(() {
      _editingMessageId = message.id;
      _editingOriginalText = message.text;
      _textController.text = message.text ?? '';
    });
  }

  // ------------------------------------------------------------------
  // Recording
  // ------------------------------------------------------------------

  Future<void> _startRecording() async {
    try {
        if (await _recorder!.hasPermission()) {
          final dir = await getTemporaryDirectory();
          final path =
              '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
          await _recorder!.start(const RecordConfig(), path: path);
          setState(() {
            _isRecording = true;
            _recordStartTime = DateTime.now();
          });
          _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
            if (!_isRecording) return;
            final elapsed = DateTime.now().difference(_recordStartTime!);
            setState(() {
              _recordDuration = _formatDuration(elapsed);
            });
          });
        } else {
          _showSnack('Microphone permission denied.');
        }
    } catch (e) {
      _showSnack('Could not start recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;
    _recordTimer?.cancel();
    try {
      final path = await _recorder!.stop();
      setState(() {
        _isRecording = false;
        _recordDuration = '00:00';
      });
      if (path != null) {
        final durationMs =
            DateTime.now().difference(_recordStartTime!).inMilliseconds;
        ref
            .read(chatRoomControllerProvider(_conversationId).notifier)
            .sendAudioMessage(localPath: path, durationMs: durationMs);
      }
    } catch (e) {
      setState(() {
        _isRecording = false;
        _recordDuration = '00:00';
      });
      _showSnack('Recording failed: $e');
    }
  }

  void _cancelRecording() async {
    _recordTimer?.cancel();
    try {
      await _recorder!.stop();
    } catch (_) {}
    setState(() {
      _isRecording = false;
      _recordDuration = '00:00';
    });
  }

  // ------------------------------------------------------------------
  // Attachments
  // ------------------------------------------------------------------

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo, color: AppTheme.primaryDark),
              title: const Text('Photo from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickMedia(ImageSource.gallery, MessageType.image);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppTheme.primaryDark),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickMedia(ImageSource.camera, MessageType.image);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: AppTheme.primaryDark),
              title: const Text('Video from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickMedia(ImageSource.gallery, MessageType.video);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickMedia(ImageSource source, MessageType type) async {
    try {
      XFile? file;
      if (type == MessageType.image) {
        file = await _picker.pickImage(
          source: source,
          maxWidth: 1080,
          maxHeight: 1080,
          imageQuality: 80,
        );
      } else {
        file = await _picker.pickVideo(
          source: source,
          maxDuration: const Duration(seconds: 30),
        );
      }
      if (file == null) return;

      ref
          .read(chatRoomControllerProvider(_conversationId).notifier)
          .sendMediaMessage(localPath: file.path, type: type);
    } catch (e) {
      _showSnack('Could not pick media: $e');
    }
  }

  // ------------------------------------------------------------------
  // Reaction overlay
  // ------------------------------------------------------------------

  void _showReactionOverlay(
      BuildContext context, Message message, bool isMine) {
    showDialog(
      context: context,
      barrierColor: Colors.black38,
      builder: (ctx) {
        return GestureDetector(
          onTap: () => Navigator.pop(ctx),
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: ReactionOverlay(
              isMine: isMine,
              messageId: message.id,
              onEmojiSelected: (emoji) {
                Navigator.pop(ctx);
                ref
                    .read(chatRoomControllerProvider(_conversationId).notifier)
                    .toggleReaction(message.id, emoji);
              },
              onAction: (action) {
                Navigator.pop(ctx);
                _handleAction(action, message);
              },
            ),
          ),
        );
      },
    );
  }

  void _handleAction(String action, Message message) {
    switch (action) {
      case 'copy':
        if (message.text != null) {
          Clipboard.setData(ClipboardData(text: message.text!));
          _showSnack('Copied to clipboard');
        }
      case 'edit':
        _startEditing(message);
      case 'share':
        if (message.text != null) {
          Share.share(message.text!);
        } else if (message.mediaUrl != null) {
          Share.share(message.mediaUrl!);
        }
      case 'deleteForMe':
        ref
            .read(chatRoomControllerProvider(_conversationId).notifier)
            .deleteForMe(message.id);
      case 'deleteForEveryone':
        ref
            .read(chatRoomControllerProvider(_conversationId).notifier)
            .deleteForEveryone(message.id);
    }
  }

  // ------------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------------

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _readableError(Object error) {
    if (error is AppException) return error.message;
    return error.toString();
  }
}

// ---------------------------------------------------------------------------
// Date separator
// ---------------------------------------------------------------------------

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    String label;
    if (_isSameDay(date, now)) {
      label = 'Today';
    } else if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      label = 'Yesterday';
    } else {
      label = DateFormat.yMMMd().format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.greyMedium.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: AppTheme.greyMedium,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
