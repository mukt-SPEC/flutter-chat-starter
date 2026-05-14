import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../core/theme.dart';
import '../../../../data/models/message.dart';

/// Audio message tile with waveform-style playback, speed toggle.
class AudioMessageTile extends StatefulWidget {
  const AudioMessageTile({
    super.key,
    required this.message,
    required this.isMine,
  });

  final Message message;
  final bool isMine;

  @override
  State<AudioMessageTile> createState() => _AudioMessageTileState();
}

class _AudioMessageTileState extends State<AudioMessageTile> {
  late final AudioPlayer _player;
  bool _isLoading = true;
  bool _hasError = false;
  double _speedIndex = 0; // 0 = 1x, 1 = 1.5x, 2 = 2x
  static const _speeds = [1.0, 1.5, 2.0];
  static const _speedLabels = ['1x', '1.5x', '2x'];

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      final url = widget.message.mediaUrl;
      if (url != null && url.isNotEmpty) {
        await _player.setUrl(url);
      }
      if (mounted) setState(() => _isLoading = false);
    } catch (_) {
      if (mounted) setState(() { _isLoading = false; _hasError = true; });
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_player.playing) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  void _cycleSpeed() {
    setState(() {
      _speedIndex = (_speedIndex + 1) % _speeds.length;
      _player.setSpeed(_speeds[_speedIndex.toInt()]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final fgColor = widget.isMine ? AppTheme.white : AppTheme.primaryDark;
    final fadedColor = fgColor.withValues(alpha: 0.5);

    if (_hasError) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 20, color: fadedColor),
          const SizedBox(width: 8),
          Text('Audio unavailable',
              style: TextStyle(color: fadedColor, fontSize: 13)),
        ],
      );
    }

    if (_isLoading) {
      return SizedBox(
        width: 200,
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: fadedColor,
              ),
            ),
            const SizedBox(width: 12),
            Text('Loading audio...', style: TextStyle(color: fadedColor, fontSize: 13)),
          ],
        ),
      );
    }

    return SizedBox(
      width: 220,
      child: StreamBuilder<PlayerState>(
        stream: _player.playerStateStream,
        builder: (context, snapshot) {
          final playerState = snapshot.data;
          final playing = playerState?.playing ?? false;
          final completed =
              playerState?.processingState == ProcessingState.completed;

          if (completed) {
            _player.seek(Duration.zero);
            _player.pause();
          }

          return Row(
            children: [
              // Play/pause button
              InkWell(
                onTap: _togglePlayPause,
                borderRadius: BorderRadius.circular(20),
                child: Icon(
                  playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
                  size: 36,
                  color: fgColor,
                ),
              ),
              const SizedBox(width: 8),
              // Waveform progress
              Expanded(
                child: StreamBuilder<Duration>(
                  stream: _player.positionStream,
                  builder: (context, posSnap) {
                    final position = posSnap.data ?? Duration.zero;
                    final total = _player.duration ?? Duration.zero;
                    final progress = total.inMilliseconds > 0
                        ? position.inMilliseconds / total.inMilliseconds
                        : 0.0;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Simulated waveform bars
                        _WaveformProgress(
                          progress: progress,
                          activeColor: fgColor,
                          inactiveColor: fadedColor,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(position),
                              style: TextStyle(
                                  color: fadedColor, fontSize: 11),
                            ),
                            Text(
                              _formatDuration(total),
                              style: TextStyle(
                                  color: fadedColor, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(width: 6),
              // Speed toggle
              InkWell(
                onTap: _cycleSpeed,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: fadedColor),
                  ),
                  child: Text(
                    _speedLabels[_speedIndex.toInt()],
                    style: TextStyle(
                      color: fgColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ---------------------------------------------------------------------------
// Waveform-style progress visualization
// ---------------------------------------------------------------------------

class _WaveformProgress extends StatelessWidget {
  const _WaveformProgress({
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  final double progress;
  final Color activeColor;
  final Color inactiveColor;

  // Predefined bar heights to simulate a waveform
  static const _barHeights = [
    0.3, 0.6, 0.9, 0.5, 1.0, 0.4, 0.8, 0.6, 0.3, 0.7,
    0.5, 0.9, 0.4, 0.6, 0.8, 1.0, 0.5, 0.3, 0.7, 0.6,
    0.4, 0.8, 0.5, 0.9, 0.3, 0.7, 0.6, 1.0, 0.4, 0.8,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final barCount = _barHeights.length;
          final barWidth = (constraints.maxWidth - (barCount - 1) * 1.5) / barCount;
          final activeIdx = (progress * barCount).floor();

          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(barCount, (i) {
              final isActive = i <= activeIdx;
              return Container(
                width: barWidth.clamp(1.0, 6.0),
                height: 22 * _barHeights[i],
                margin: const EdgeInsets.only(right: 1.5),
                decoration: BoxDecoration(
                  color: isActive ? activeColor : inactiveColor,
                  borderRadius: BorderRadius.circular(1),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
