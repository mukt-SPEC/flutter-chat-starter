import 'package:flutter/material.dart';

import 'package:intl/intl.dart';

import '../../../../core/theme.dart';
import '../../../../data/models/member_state.dart' as ms;
import '../../../../data/models/message.dart';
import 'audio_message_tile.dart';
import 'media_message_tile.dart';
import 'reaction_bar.dart';
import 'read_receipt_badge.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.onLongPress,
    this.otherMemberState,
    this.searchHighlight,
    this.onReactionTap,
  });

  final Message message;
  final bool isMine;
  final VoidCallback onLongPress;
  final ms.MemberState? otherMemberState;
  final String? searchHighlight;
  final void Function(String emoji)? onReactionTap;

  @override
  Widget build(BuildContext context) {
    // Deleted message placeholder
    if (message.deletedForEveryone) {
      return _DeletedBubble(isMine: isMine);
    }


    final bubbleColor = isMine ? AppTheme.primaryDark : AppTheme.white;
    final textColor = isMine ? AppTheme.white : AppTheme.primaryDark;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: EdgeInsets.only(
            left: isMine ? 60 : 12,
            right: isMine ? 12 : 60,
            top: 3,
            bottom: 3,
          ),
          child: Column(
            crossAxisAlignment:
                isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                padding: _contentPadding,
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMine ? 16 : 4),
                    bottomRight: Radius.circular(isMine ? 4 : 16),
                  ),
                  border: isMine
                      ? null
                      : Border.all(
                          color: AppTheme.greyMedium.withValues(alpha: 0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildContent(context, textColor),
                    const SizedBox(height: 4),
                    _buildFooter(context, textColor),
                  ],
                ),
              ),
              // Reactions row
              if (message.reactions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: ReactionRow(
                    reactions: message.reactions,
                    onTap: onReactionTap,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  EdgeInsets get _contentPadding {
    if (message.type == MessageType.image ||
        message.type == MessageType.video) {
      return const EdgeInsets.all(4);
    }
    return const EdgeInsets.symmetric(horizontal: 14, vertical: 10);
  }

  Widget _buildContent(BuildContext context, Color textColor) {
    switch (message.type) {
      case MessageType.image:
      case MessageType.video:
        return MediaMessageTile(
          message: message,
          isMine: isMine,
        );
      case MessageType.audio:
        return AudioMessageTile(
          message: message,
          isMine: isMine,
        );
      case MessageType.text:
      case MessageType.system:
        return _buildTextContent(context, textColor);
    }
  }

  Widget _buildTextContent(BuildContext context, Color textColor) {
    final text = message.text ?? '';
    if (searchHighlight != null && searchHighlight!.isNotEmpty) {
      return _HighlightedText(
        text: text,
        highlight: searchHighlight!,
        style: TextStyle(color: textColor, fontSize: 15),
      );
    }
    return Text(
      text,
      style: TextStyle(color: textColor, fontSize: 15),
    );
  }

  Widget _buildFooter(BuildContext context, Color textColor) {
    final time = _formatTime(message.createdAt.toDate());
    final fadedColor = textColor.withValues(alpha: 0.5);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (message.editedAt != null)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(
              'edited',
              style: TextStyle(
                color: fadedColor,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        Text(
          time,
          style: TextStyle(color: fadedColor, fontSize: 11),
        ),
        if (isMine) ...[
          const SizedBox(width: 4),
          ReadReceiptBadge(
            message: message,
            otherMemberState: otherMemberState,
            color: isMine ? Colors.white70 : AppTheme.greyMedium,
          ),
        ],
      ],
    );
  }

  String _formatTime(DateTime dt) {
    return DateFormat.Hm().format(dt);
  }
}

// ---------------------------------------------------------------------------
// Deleted message placeholder
// ---------------------------------------------------------------------------

class _DeletedBubble extends StatelessWidget {
  const _DeletedBubble({required this.isMine});
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          left: isMine ? 60 : 12,
          right: isMine ? 12 : 60,
          top: 3,
          bottom: 3,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block, size: 14, color: Colors.grey.shade500),
            const SizedBox(width: 6),
            Text(
              'This message was deleted',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Highlighted text for search
// ---------------------------------------------------------------------------

class _HighlightedText extends StatelessWidget {
  const _HighlightedText({
    required this.text,
    required this.highlight,
    required this.style,
  });

  final String text;
  final String highlight;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    if (highlight.isEmpty) {
      return Text(text, style: style);
    }

    final lowerText = text.toLowerCase();
    final lowerHighlight = highlight.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;

    while (true) {
      final idx = lowerText.indexOf(lowerHighlight, start);
      if (idx == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (idx > start) {
        spans.add(TextSpan(text: text.substring(start, idx)));
      }
      spans.add(TextSpan(
        text: text.substring(idx, idx + highlight.length),
        style: const TextStyle(
          backgroundColor: Color(0x44FFD54F),
          fontWeight: FontWeight.w600,
        ),
      ));
      start = idx + highlight.length;
    }

    return RichText(text: TextSpan(style: style, children: spans));
  }
}
