import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme.dart';

/// Animated typing indicator with three bouncing dots.
class TypingIndicator extends StatelessWidget {
  const TypingIndicator({
    super.key,
    required this.isVisible,
    this.userName,
  });

  final bool isVisible;
  final String? userName;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SizeTransition(
            sizeFactor: animation,
            axisAlignment: -1,
            child: child,
          ),
        );
      },
      child: isVisible
          ? Padding(
              key: const ValueKey('typing'),
              padding: const EdgeInsets.only(left: 16, bottom: 8, top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.white,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                        bottomLeft: Radius.circular(4),
                      ),
                      border: Border.all(
                          color: AppTheme.greyMedium.withValues(alpha: 0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildDot(0),
                        const SizedBox(width: 4),
                        _buildDot(1),
                        const SizedBox(width: 4),
                        _buildDot(2),
                      ],
                    ),
                  ),
                  if (userName != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '$userName is typing',
                      style: TextStyle(
                        color: AppTheme.greyMedium,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            )
          : const SizedBox.shrink(key: ValueKey('idle')),
    );
  }

  Widget _buildDot(int index) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: AppTheme.greyMedium,
        shape: BoxShape.circle,
      ),
    )
        .animate(
          onPlay: (controller) => controller.repeat(),
        )
        .fadeIn(duration: 200.ms, delay: (index * 200).ms)
        .then()
        .moveY(
          begin: 0,
          end: -6,
          duration: 400.ms,
          curve: Curves.easeInOut,
        )
        .then()
        .moveY(
          begin: -6,
          end: 0,
          duration: 400.ms,
          curve: Curves.easeInOut,
        );
  }
}
