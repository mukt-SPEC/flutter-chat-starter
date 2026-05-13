import 'package:cloud_firestore/cloud_firestore.dart';

class Conversation {
  final String id;
  final List<String> participants;
  final String participantKey;
  final String? lastMessagePreview;
  final String? lastMessageType;
  final Timestamp? lastMessageAt;
  final String createdBy;
  final Timestamp? createdAt;

  Conversation({
    required this.id,
    required this.participants,
    required this.participantKey,
    this.lastMessagePreview,
    this.lastMessageType,
    this.lastMessageAt,
    required this.createdBy,
    this.createdAt,
  });

  factory Conversation.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Conversation(
      id: doc.id,
      participants: List<String>.from(data['participants'] as List),
      participantKey: (data['participantKey'] as String?) ?? '',
      lastMessagePreview:
          (data['lastMessagePreview'] ?? data['lastMessage']) as String?,
      lastMessageType: data['lastMessageType'] as String?,
      lastMessageAt: data['lastMessageAt'] as Timestamp?,
      createdBy: (data['createdBy'] as String?) ?? '',
      createdAt: data['createdAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'participants': participants,
      'participantKey': participantKey,
      'lastMessagePreview': lastMessagePreview,
      'lastMessageType': lastMessageType,
      'lastMessageAt': lastMessageAt,
      'createdBy': createdBy,
      'createdAt': createdAt,
    };
  }
}
