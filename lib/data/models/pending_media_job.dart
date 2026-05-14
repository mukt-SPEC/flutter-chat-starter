enum PendingMediaType { image, video, audio }

enum PendingMediaJobStatus { queued, uploading, failed }

PendingMediaType pendingMediaTypeFromString(String value) {
  switch (value) {
    case 'video':
      return PendingMediaType.video;
    case 'audio':
      return PendingMediaType.audio;
    case 'image':
    default:
      return PendingMediaType.image;
  }
}

String pendingMediaTypeToString(PendingMediaType value) {
  return switch (value) {
    PendingMediaType.image => 'image',
    PendingMediaType.video => 'video',
    PendingMediaType.audio => 'audio',
  };
}

PendingMediaJobStatus pendingMediaJobStatusFromString(String value) {
  switch (value) {
    case 'uploading':
      return PendingMediaJobStatus.uploading;
    case 'failed':
      return PendingMediaJobStatus.failed;
    case 'queued':
    default:
      return PendingMediaJobStatus.queued;
  }
}

String pendingMediaJobStatusToString(PendingMediaJobStatus value) {
  return switch (value) {
    PendingMediaJobStatus.queued => 'queued',
    PendingMediaJobStatus.uploading => 'uploading',
    PendingMediaJobStatus.failed => 'failed',
  };
}

class PendingMediaJob {
  final String id;
  final String conversationId;
  final PendingMediaType type;
  final String localPath;
  final String? text;
  final int retryCount;
  final PendingMediaJobStatus status;
  final DateTime createdAt;
  final DateTime? lastAttemptAt;

  const PendingMediaJob({
    required this.id,
    required this.conversationId,
    required this.type,
    required this.localPath,
    this.text,
    this.retryCount = 0,
    this.status = PendingMediaJobStatus.queued,
    required this.createdAt,
    this.lastAttemptAt,
  });

  factory PendingMediaJob.fromMap(Map<String, dynamic> data) {
    return PendingMediaJob(
      id: data['id'] as String,
      conversationId: data['conversationId'] as String,
      type: pendingMediaTypeFromString((data['type'] as String?) ?? 'image'),
      localPath: data['localPath'] as String,
      text: data['text'] as String?,
      retryCount: (data['retryCount'] as int?) ?? 0,
      status: pendingMediaJobStatusFromString(
        (data['status'] as String?) ?? 'queued',
      ),
      createdAt: DateTime.parse(data['createdAt'] as String),
      lastAttemptAt: data['lastAttemptAt'] == null
          ? null
          : DateTime.parse(data['lastAttemptAt'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversationId': conversationId,
      'type': pendingMediaTypeToString(type),
      'localPath': localPath,
      'text': text,
      'retryCount': retryCount,
      'status': pendingMediaJobStatusToString(status),
      'createdAt': createdAt.toIso8601String(),
      'lastAttemptAt': lastAttemptAt?.toIso8601String(),
    };
  }
}
