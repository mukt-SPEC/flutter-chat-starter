import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../models/pending_media_job.dart';

const _boxName = 'offline_queue';

class OfflineQueueRepository {
  OfflineQueueRepository(this._box);

  final Box<Map> _box;

  /// Enqueue a new pending job.
  Future<void> enqueue(PendingMediaJob job) async {
    await _box.put(job.id, Map<String, dynamic>.from(job.toMap()));
  }

  /// Remove a completed/cancelled job.
  Future<void> dequeue(String id) async {
    await _box.delete(id);
  }

  /// Get all pending jobs.
  List<PendingMediaJob> getAll() {
    return _box.values.map((raw) {
      final map = Map<String, dynamic>.from(raw);
      return PendingMediaJob.fromMap(map);
    }).toList();
  }

  /// Update the status of a job.
  Future<void> updateStatus(String id, PendingMediaJobStatus status) async {
    final raw = _box.get(id);
    if (raw == null) return;
    final map = Map<String, dynamic>.from(raw);
    map['status'] = pendingMediaJobStatusToString(status);
    map['lastAttemptAt'] = DateTime.now().toIso8601String();
    await _box.put(id, map);
  }

  /// Increment retry count.
  Future<void> incrementRetry(String id) async {
    final raw = _box.get(id);
    if (raw == null) return;
    final map = Map<String, dynamic>.from(raw);
    map['retryCount'] = ((map['retryCount'] as int?) ?? 0) + 1;
    await _box.put(id, map);
  }
}

// ---------------------------------------------------------------------------
// Riverpod provider
// ---------------------------------------------------------------------------

final offlineQueueBoxProvider = Provider<Box<Map>>((ref) {
  // This will be overridden after Hive.openBox in main.dart
  throw UnimplementedError('offlineQueueBoxProvider must be overridden');
});

final offlineQueueRepositoryProvider =
    Provider<OfflineQueueRepository>((ref) {
  return OfflineQueueRepository(ref.watch(offlineQueueBoxProvider));
});

/// Open the Hive box. Call this before runApp.
Future<Box<Map>> openOfflineQueueBox() async {
  return Hive.openBox<Map>(_boxName);
}
