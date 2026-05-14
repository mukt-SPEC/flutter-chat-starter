import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../data/models/member_state.dart' as ms;
import '../../../../data/models/message.dart';

/// Compact read receipt indicator: âœ“ (sent), âœ“âœ“ (delivered), âœ“âœ“ blue (seen).
class ReadReceiptBadge extends StatelessWidget {
  const ReadReceiptBadge({
    super.key,
    required this.message,
    this.otherMemberState,
    this.color,
  });

  final Message message;
  final ms.MemberState? otherMemberState;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final status = _computeStatus();
    return _Badge(status: status, baseColor: color ?? Colors.grey);
  }

  _ReceiptStatus _computeStatus() {
    final other = otherMemberState;
    if (other == null) return _ReceiptStatus.sent;

    final msgTime = message.createdAt;

    // Check "seen"
    if (other.seenUpTo != null &&
        _isAtOrAfter(other.seenUpTo!, msgTime)) {
      return _ReceiptStatus.seen;
    }

    // Check "delivered"
    if (other.deliveredUpTo != null &&
        _isAtOrAfter(other.deliveredUpTo!, msgTime)) {
      return _ReceiptStatus.delivered;
    }

    return _ReceiptStatus.sent;
  }

  bool _isAtOrAfter(Timestamp a, Timestamp b) {
    return a.seconds > b.seconds ||
        (a.seconds == b.seconds && a.nanoseconds >= b.nanoseconds);
  }
}

enum _ReceiptStatus { sent, delivered, seen }

class _Badge extends StatelessWidget {
  const _Badge({required this.status, required this.baseColor});
  final _ReceiptStatus status;
  final Color baseColor;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case _ReceiptStatus.sent:
        return Icon(Icons.check, size: 14, color: baseColor);
      case _ReceiptStatus.delivered:
        return Icon(Icons.done_all, size: 14, color: baseColor);
      case _ReceiptStatus.seen:
        return const Icon(Icons.done_all, size: 14, color: Color(0xFF4FC3F7));
    }
  }
}
