import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import '../../../../data/models/message.dart';
import '../screens/full_screen_media_viewer.dart';

/// Renders image and video message content inside a bubble.
class MediaMessageTile extends StatelessWidget {
  const MediaMessageTile({
    super.key,
    required this.message,
    required this.isMine,
  });

  final Message message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final url = message.mediaUrl;
    if (url == null || url.isEmpty) {
      return const SizedBox(
        width: 200,
        height: 120,
        child: Center(child: Icon(Icons.broken_image, size: 32)),
      );
    }

    final isVideo = message.type == MessageType.video;
    final displayUrl = isVideo ? (message.thumbUrl ?? url) : url;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FullScreenMediaViewer(
              mediaUrl: url,
              isVideo: isVideo,
              heroTag: 'media_${message.id}',
            ),
          ),
        );
      },
      child: Hero(
        tag: 'media_${message.id}',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 240,
                  maxHeight: 300,
                  minHeight: 80,
                ),
                child: CachedNetworkImage(
                  imageUrl: displayUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 240,
                    height: 160,
                    color: AppTheme.greyMedium.withValues(alpha: 0.2),
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 240,
                    height: 160,
                    color: AppTheme.greyMedium.withValues(alpha: 0.2),
                    child: const Icon(Icons.broken_image, size: 32),
                  ),
                ),
              ),
              // Video play overlay
              if (isVideo)
                Positioned.fill(
                  child: Container(
                    color: Colors.black26,
                    child: const Center(
                      child: Icon(
                        Icons.play_circle_outline,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              // Compression badge
              if (message.compression != null)
                Positioned(
                  bottom: 4,
                  left: 4,
                  child: _CompressionBadge(
                      compression: message.compression!),
                ),
              // Caption
              if (message.text != null && message.text!.trim().isNotEmpty)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.6),
                        ],
                      ),
                    ),
                    child: Text(
                      message.text!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompressionBadge extends StatelessWidget {
  const _CompressionBadge({required this.compression});
  final CompressionMeta compression;

  @override
  Widget build(BuildContext context) {
    final original = compression.originalBytes;
    final compressed = compression.compressedBytes;
    if (original == null || compressed == null || original == compressed) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${_formatSize(original)} â†’ ${_formatSize(compressed)}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}
