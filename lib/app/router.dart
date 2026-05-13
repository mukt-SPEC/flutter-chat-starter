import 'package:flutter/material.dart';

import '../features/auth/presentation/screens/login_screen.dart';
import '../features/chat_list/presentation/screens/chat_list_screen.dart';

Map<String, WidgetBuilder> buildAppRoutes() {
  return {
    '/login': (_) => const LoginScreen(),
    '/chats': (_) => const ChatListScreen(),
  };
}
