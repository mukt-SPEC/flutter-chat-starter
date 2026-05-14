import 'package:flutter/material.dart';

import '../features/auth/presentation/screens/login_screen.dart';
import '../features/chat_list/presentation/screens/chat_list_screen.dart';
import '../features/chat_room/presentation/screens/chat_room_screen.dart';

Map<String, WidgetBuilder> buildAppRoutes() {
  return {
    '/login': (_) => const LoginScreen(),
    '/chats': (_) => const ChatListScreen(),
  };
}

/// Push the chat room screen with a conversation ID.
void navigateToChatRoom(BuildContext context, String conversationId) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ChatScreen(conversationId: conversationId),
    ),
  );
}
