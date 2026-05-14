import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app/app.dart';
import 'data/repositories/offline_queue_repository.dart';
import 'features/media_queue/presentation/providers/media_queue_provider.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize Hive for offline queue
  await Hive.initFlutter();
  final offlineBox = await openOfflineQueueBox();

  runApp(
    ProviderScope(
      overrides: [
        offlineQueueBoxProvider.overrideWithValue(offlineBox),
      ],
      child: const _EagerInitializer(child: App()),
    ),
  );
}

/// Eagerly initializes providers that need to run at startup.
class _EagerInitializer extends ConsumerWidget {
  const _EagerInitializer({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Start the media queue worker so offline messages are synced
    ref.watch(mediaQueueProvider);
    return child;
  }
}
