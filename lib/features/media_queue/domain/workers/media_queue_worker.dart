import 'dart:async';


import '../../../../data/models/message.dart';
import '../../../../data/models/pending_media_job.dart';
import '../../../../data/repositories/media_repository.dart';
import '../../../../data/repositories/message_repository.dart';
import '../../../../data/repositories/offline_queue_repository.dart';
import 'package:path/path.dart' as p;

const _maxRetries = 3;

/// Background worker that processes the offline queue when connectivity returns.
class MediaQueueWorker {
  MediaQueueWorker({
    required this.offlineQueueRepo,
    required this.mediaRepo,
    required this.messageRepo,
  });

  final OfflineQueueRepository offlineQueueRepo;
  final MediaRepository mediaRepo;
  final MessageRepository messageRepo;

  bool _isProcessing = false;

  /// Process all pending jobs in the queue.
  Future<void> processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final jobs = offlineQueueRepo.getAll();
      for (final job in jobs) {
        if (job.status == PendingMediaJobStatus.failed &&
            job.retryCount >= _maxRetries) {
          continue; // Skip permanently failed jobs
        }

        try {
          await offlineQueueRepo.updateStatus(
              job.id, PendingMediaJobStatus.uploading);

          // Text-only message (queued while offline)
          if (job.localPath.isEmpty && job.text != null) {
            await messageRepo.sendMessage(
              conversationId: job.conversationId,
              senderId: '', // Will be overridden by security rules
              type: MessageType.text,
              text: job.text,
            );
            await offlineQueueRepo.dequeue(job.id);
            continue;
          }

          // Media message
          final ext = p.extension(job.localPath);
          CompressionMeta? compression;
          String compressedPath = job.localPath;

          // Compress if needed
          switch (job.type) {
            case PendingMediaType.image:
              final result = await mediaRepo.compressImage(job.localPath);
              compressedPath = result.$1;
              compression = result.$2;
            case PendingMediaType.video:
              final result = await mediaRepo.compressVideo(job.localPath);
              compressedPath = result.$1;
              compression = result.$2;
            case PendingMediaType.audio:
              break; // No compression for audio
          }

          // Upload
          final storagePath = mediaRepo.generateStoragePath(
            conversationId: job.conversationId,
            extension: ext,
          );
          final downloadUrl = await mediaRepo.uploadFile(
            localPath: compressedPath,
            storagePath: storagePath,
          );

          // Send message
          final msgType = switch (job.type) {
            PendingMediaType.image => MessageType.image,
            PendingMediaType.video => MessageType.video,
            PendingMediaType.audio => MessageType.audio,
          };

          await messageRepo.sendMessage(
            conversationId: job.conversationId,
            senderId: '',
            type: msgType,
            text: job.text,
            mediaUrl: downloadUrl,
            compression: compression,
          );

          await offlineQueueRepo.dequeue(job.id);
        } catch (_) {
          await offlineQueueRepo.incrementRetry(job.id);
          if (job.retryCount + 1 >= _maxRetries) {
            await offlineQueueRepo.updateStatus(
                job.id, PendingMediaJobStatus.failed);
          } else {
            await offlineQueueRepo.updateStatus(
                job.id, PendingMediaJobStatus.queued);
          }
        }
      }
    } finally {
      _isProcessing = false;
    }
  }
}
