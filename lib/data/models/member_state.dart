import 'package:cloud_firestore/cloud_firestore.dart';

class MemberState {
  final String uid;
  final bool typing;
  final Timestamp? typingUpdatedAt;
  final Timestamp? deliveredUpTo;
  final Timestamp? seenUpTo;
  final bool muted;

  const MemberState({
    required this.uid,
    this.typing = false,
    this.typingUpdatedAt,
    this.deliveredUpTo,
    this.seenUpTo,
    this.muted = false,
  });

  factory MemberState.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return MemberState(
      uid: doc.id,
      typing: (data['typing'] as bool?) ?? false,
      typingUpdatedAt: data['typingUpdatedAt'] as Timestamp?,
      deliveredUpTo: data['deliveredUpTo'] as Timestamp?,
      seenUpTo: data['seenUpTo'] as Timestamp?,
      muted: (data['muted'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'typing': typing,
      'typingUpdatedAt': typingUpdatedAt,
      'deliveredUpTo': deliveredUpTo,
      'seenUpTo': seenUpTo,
      'muted': muted,
    };
  }
}
