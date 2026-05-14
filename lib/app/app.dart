import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/firebase_providers.dart';
import '../core/theme.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/chat_list/presentation/screens/chat_list_screen.dart';
import 'router.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);

    return MaterialApp(
      title: 'Flutter Chat Starter',
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      routes: buildAppRoutes(),
      home: authState.when(
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => const LoginScreen(),
        data: (user) => user != null ? const ChatListScreen() : const LoginScreen(),
      ),
    );
  }
}
