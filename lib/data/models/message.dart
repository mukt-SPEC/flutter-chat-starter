import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, image, video, audio, system }

MessageType messageTypeFromString(String value) {
  switch (value) {
    case 'image':
      return MessageType.image;
    case 'video':
      return MessageType.video;
    case 'audio':
      return MessageType.audio;
    case 'system':
      return MessageType.system;
    case 'text':
    default:
      return MessageType.text;
  }
}

String messageTypeToString(MessageType value) {
  return switch (value) {
    MessageType.text => 'text',
    MessageType.image => 'image',
    MessageType.video => 'video',
    MessageType.audio => 'audio',
    MessageType.system => 'system',
  };
}

class CompressionMeta {
  final int? originalBytes;
  final int? compressedBytes;
  final String? codec;

  const CompressionMeta({
    this.originalBytes,
    this.compressedBytes,
    this.codec,
  });

  factory CompressionMeta.fromMap(Map<String, dynamic> data) {
    return CompressionMeta(
      originalBytes: data['originalBytes'] as int?,
      compressedBytes: data['compressedBytes'] as int?,
      codec: data['codec'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'originalBytes': originalBytes,
      'compressedBytes': compressedBytes,
      'codec': codec,
    };
  }
}

class Message {
  final String id;
  final String senderId;
  final MessageType type;
  final String? text;
  final String? mediaUrl;
  final String? thumbUrl;
  final int? durationMs;
  final Map<String, String> reactions;
  final Timestamp createdAt;
  final Timestamp? updatedAt;
  final Timestamp? editedAt;
  final bool deletedForEveryone;
  final List<String> deletedFor;
  final CompressionMeta? compression;

  Message({
    required this.id,
    required this.senderId,
    required this.type,
    this.text,
    this.mediaUrl,
    this.thumbUrl,
    this.durationMs,
    this.reactions = const {},
    required this.createdAt,
    this.updatedAt,
    this.editedAt,
    this.deletedForEveryone = false,
    this.deletedFor = const [],
    this.compression,
  });

  factory Message.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawReactions = (data['reactions'] as Map<String, dynamic>?) ?? {};
    final reactions = rawReactions.map(
      (key, value) => MapEntry(key, value.toString()),
    );
    final rawDeletedFor = (data['deletedFor'] as List<dynamic>?) ?? const [];
    final compressionData = data['compression'] as Map<String, dynamic>?;
    final createdAt = data['createdAt'] as Timestamp?;

    return Message(
      id: doc.id,
      senderId: data['senderId'] as String,
      type: messageTypeFromString((data['type'] as String?) ?? 'text'),
      text: data['text'] as String?,
      mediaUrl: data['mediaUrl'] as String?,
      thumbUrl: data['thumbUrl'] as String?,
      durationMs: data['durationMs'] as int?,
      reactions: reactions,
      createdAt: createdAt ?? Timestamp.now(),
      updatedAt: data['updatedAt'] as Timestamp?,
      editedAt: data['editedAt'] as Timestamp?,
      deletedForEveryone: (data['deletedForEveryone'] as bool?) ?? false,
      deletedFor: rawDeletedFor.map((item) => item.toString()).toList(),
      compression: compressionData == null
          ? null
          : CompressionMeta.fromMap(compressionData),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'type': messageTypeToString(type),
      'text': text,
      'mediaUrl': mediaUrl,
      'thumbUrl': thumbUrl,
      'durationMs': durationMs,
      'reactions': reactions,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'editedAt': editedAt,
      'deletedForEveryone': deletedForEveryone,
      'deletedFor': deletedFor,
      'compression': compression?.toMap(),
    };
  }
}
