import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import 'chat_thread_page.dart';

/// Opens (creating if needed) the direct chat with [userId] — the "Message"
/// button on profiles and people lists.
Future<void> openDirectChat(BuildContext context, String userId) async {
  final messenger = ScaffoldMessenger.of(context);
  final nav = Navigator.of(context);
  try {
    final token = await AuthManager.instance.getValidToken();
    final conversation = await ApiService().openDirectChat(token, userId);
    await nav.push<void>(MaterialPageRoute(
      builder: (_) => ChatThreadPage(conversationId: conversation.id, initial: conversation),
    ));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
  }
}

/// Opens a conversation by id (inbox rows, push notifications).
Future<void> openConversation(BuildContext context, String conversationId) =>
    Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => ChatThreadPage(conversationId: conversationId),
    ));
