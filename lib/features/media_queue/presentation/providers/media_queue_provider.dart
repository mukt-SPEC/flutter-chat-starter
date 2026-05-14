import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network_provider.dart';
import '../../../../data/repositories/media_repository.dart';
import '../../../../data/repositories/message_repository.dart';
import '../../../../data/repositories/offline_queue_repository.dart';
import '../../domain/workers/media_queue_worker.dart';

/// Provider that initializes and manages the media queue worker.
/// This listens to connectivity changes and processes the offline queue
/// when the device comes online.
final mediaQueueProvider = Provider<MediaQueueWorker>((ref) {
  final worker = MediaQueueWorker(
    offlineQueueRepo: ref.watch(offlineQueueRepositoryProvider),
    mediaRepo: ref.watch(mediaRepositoryProvider),
    messageRepo: ref.watch(messageRepositoryProvider),
  );

  // Listen for connectivity changes
  ref.listen<AsyncValue<bool>>(connectivityProvider, (prev, next) {
    final isOnline = next.valueOrNull == true;

    if (isOnline) {
      // Process queue whenever we come online
      worker.processQueue();
    }
  });

  // Also process on startup
  Future.microtask(() {
    final isOnline = ref.read(connectivityProvider).valueOrNull ?? true;
    if (isOnline) {
      worker.processQueue();
    }
  });

  return worker;
});
