// lib/features/chat/presentation/providers/active_chat_provider.dart
//
// Tracks the ID of the chat currently being viewed by the user.
// Used to suppress push notifications for the active conversation.
// Moved from core/providers/ — this is chat-specific state, not global infrastructure.

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The chatId of the conversation currently open on screen.
/// Null when no chat is active (e.g. on the chat list or other screens).
/// NotificationService reads this to skip showing a notification for the active chat.
final activeChatIdProvider = StateProvider<String?>((ref) => null);
