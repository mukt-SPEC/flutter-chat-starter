import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

import '../../../../core/theme.dart';

// ---------------------------------------------------------------------------
// Quick-pick reaction emojis
// ---------------------------------------------------------------------------

const _quickEmojis = ['ðŸ‘', 'â¤ï¸', 'ðŸ˜‚', 'ðŸ˜®', 'ðŸ˜¢', 'ðŸ”¥'];

// ---------------------------------------------------------------------------
// Reaction row displayed below a message bubble
// ---------------------------------------------------------------------------

class ReactionRow extends StatelessWidget {
  const ReactionRow({
    super.key,
    required this.reactions,
    this.onTap,
  });

  /// Map of userId â†’ emoji
  final Map<String, String> reactions;
  final void Function(String emoji)? onTap;

  @override
  Widget build(BuildContext context) {
    // Group by emoji
    final grouped = <String, int>{};
    for (final emoji in reactions.values) {
      grouped[emoji] = (grouped[emoji] ?? 0) + 1;
    }

    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: grouped.entries.map((entry) {
        return GestureDetector(
          onTap: () => onTap?.call(entry.key),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.greyMedium.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(entry.key, style: const TextStyle(fontSize: 14)),
                if (entry.value > 1) ...[
                  const SizedBox(width: 2),
                  Text(
                    '${entry.value}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.primaryDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Reaction overlay â€” shown on long-press
// ---------------------------------------------------------------------------

class ReactionOverlay extends StatelessWidget {
  const ReactionOverlay({
    super.key,
    required this.isMine,
    required this.messageId,
    required this.onEmojiSelected,
    required this.onAction,
  });

  final bool isMine;
  final String messageId;
  final void Function(String emoji) onEmojiSelected;

  /// Action keys: 'copy', 'edit', 'deleteForMe', 'deleteForEveryone', 'share'
  final void Function(String action) onAction;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Quick emoji bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ..._quickEmojis.map((emoji) => _EmojiButton(
                      emoji: emoji,
                      onTap: () => onEmojiSelected(emoji),
                    )),
                const SizedBox(width: 4),
                _CircleIconButton(
                  icon: Icons.add,
                  onTap: () => _openFullPicker(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Action buttons
          Container(
            constraints: const BoxConstraints(minWidth: 180),
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                _ActionTile(
                  icon: Icons.copy,
                  label: 'Copy',
                  onTap: () => onAction('copy'),
                ),
                if (isMine)
                  _ActionTile(
                    icon: Icons.edit,
                    label: 'Edit',
                    onTap: () => onAction('edit'),
                  ),
                _ActionTile(
                  icon: Icons.share,
                  label: 'Share',
                  onTap: () => onAction('share'),
                ),
                const Divider(height: 1),
                _ActionTile(
                  icon: Icons.delete_outline,
                  label: 'Delete for me',
                  onTap: () => onAction('deleteForMe'),
                  isDestructive: true,
                ),
                if (isMine)
                  _ActionTile(
                    icon: Icons.delete_forever,
                    label: 'Delete for everyone',
                    onTap: () => onAction('deleteForEveryone'),
                    isDestructive: true,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openFullPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SizedBox(
        height: 300,
        child: EmojiPicker(
          onEmojiSelected: (_, emoji) {
            Navigator.pop(context);
            onEmojiSelected(emoji.emoji);
          },
          config: const Config(
            height: 300,
            checkPlatformCompatibility: true,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper widgets
// ---------------------------------------------------------------------------

class _EmojiButton extends StatelessWidget {
  const _EmojiButton({required this.emoji, required this.onTap});
  final String emoji;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(emoji, style: const TextStyle(fontSize: 24)),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.surfaceLight,
        ),
        child: Icon(icon, size: 18, color: AppTheme.primaryDark),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.red.shade600 : AppTheme.primaryDark;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
