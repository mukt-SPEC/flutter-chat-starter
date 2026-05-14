import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme.dart';

/// Full-screen viewer for images (PhotoView) and videos (VideoPlayer).
class FullScreenMediaViewer extends StatefulWidget {
  const FullScreenMediaViewer({
    super.key,
    required this.mediaUrl,
    required this.isVideo,
    this.heroTag,
  });

  final String mediaUrl;
  final bool isVideo;
  final String? heroTag;

  @override
  State<FullScreenMediaViewer> createState() => _FullScreenMediaViewerState();
}

class _FullScreenMediaViewerState extends State<FullScreenMediaViewer> {
  VideoPlayerController? _videoController;
  bool _videoInitialized = false;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.mediaUrl),
      )..initialize().then((_) {
          if (mounted) {
            setState(() => _videoInitialized = true);
            _videoController!.play();
          }
        });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              Share.share(widget.mediaUrl);
            },
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: widget.isVideo ? _buildVideo() : _buildImage(),
    );
  }

  Widget _buildImage() {
    final child = PhotoView(
      imageProvider: NetworkImage(widget.mediaUrl),
      minScale: PhotoViewComputedScale.contained,
      maxScale: PhotoViewComputedScale.covered * 3,
      backgroundDecoration: const BoxDecoration(color: Colors.black),
      loadingBuilder: (_, event) => Center(
        child: CircularProgressIndicator(
          value: event?.expectedTotalBytes != null
              ? event!.cumulativeBytesLoaded / event.expectedTotalBytes!
              : null,
          color: Colors.white,
        ),
      ),
    );

    if (widget.heroTag != null) {
      return Hero(tag: widget.heroTag!, child: child);
    }
    return child;
  }

  Widget _buildVideo() {
    if (!_videoInitialized || _videoController == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(_videoController!),
            // Play/pause overlay
            GestureDetector(
              onTap: () {
                setState(() {
                  if (_videoController!.value.isPlaying) {
                    _videoController!.pause();
                  } else {
                    _videoController!.play();
                  }
                });
              },
              child: AnimatedOpacity(
                opacity: _videoController!.value.isPlaying ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black38,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(12),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
            ),
            // Progress bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: VideoProgressIndicator(
                _videoController!,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: AppTheme.white,
                  bufferedColor: AppTheme.greyMedium,
                  backgroundColor: Colors.white24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
