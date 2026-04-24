import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/features/auth/providers/auth_providers.dart';
import 'package:xparq_app/features/chat/domain/models/chat_model.dart';
import 'package:xparq_app/features/chat/data/repositories/chat_repository.dart';
import 'package:xparq_app/features/auth/models/planet_model.dart';
import 'package:xparq_app/features/chat/data/services/message_encryption_service.dart';
import 'package:xparq_app/features/offline/services/offline_chat_database.dart';
import 'package:xparq_app/features/chat/presentation/providers/identity_providers.dart';
import 'package:xparq_app/features/chat/data/services/signal/signal_session_manager.dart';

// ── Pending Messages (Optimistic UI) ────────────────────────────────────────

class PendingMessagesNotifier
    extends StateNotifier<Map<String, List<MessageModel>>> {
  PendingMessagesNotifier() : super({});

  void addPendingMessage(String chatId, MessageModel message) {
    var msgs = state[chatId] ?? [];
    msgs = List.from(msgs)..add(message);
    state = {...state, chatId: msgs};
  }

  void removePendingMessage(String chatId, String messageId) {
    final msgs = state[chatId] ?? [];
    state = {
      ...state,
      chatId: msgs.where((m) => m.messageId != messageId).toList(),
    };
  }

  void removePendingMessages(String chatId, Iterable<String> messageIds) {
    final ids = messageIds.toSet();
    if (ids.isEmpty) return;
    final msgs = state[chatId] ?? [];
    state = {
      ...state,
      chatId: msgs.where((m) => !ids.contains(m.messageId)).toList(),
    };
  }
}

final pendingMessagesProvider = StateNotifierProvider<PendingMessagesNotifier,
    Map<String, List<MessageModel>>>((ref) {
  return PendingMessagesNotifier();
});

// ── Repository ────────────────────────────────────────────────────────────────

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(),
);

// ── Legacy Aliases (Fixes for refactored repository) ─────────────────────────
final chatBaseRepositoryProvider = chatRepositoryProvider;
final chatSearchRepositoryProvider = chatRepositoryProvider;
final chatSettingsRepositoryProvider = chatRepositoryProvider;
final contactRequestRepositoryProvider = chatRepositoryProvider;

// ── Profile Cache (for chat list / chat screen AppBar) ───────────────────────

/// Fetches and caches a profile by UID for use in the chat list and chat
/// screen AppBar. Uses .autoDispose so entries are released when no longer
/// watched, preventing unbounded memory growth.
final chatProfileProvider =
    StreamProvider.autoDispose.family<PlanetModel?, String>((ref, uid) {
  if (uid.isEmpty) return Stream.value(null);
  // ignore: deprecated_member_use
  // .stream will be removed in 3.0.0
  return ref.watch(planetProfileByUidProvider(uid).future).asStream();
});

// ── My Chats List ─────────────────────────────────────────────────────────────

final rawChatsProvider = StreamProvider<List<ChatModel>>((ref) {
  final uid = ref.watch(authRepositoryProvider).currentUser?.id;
  if (uid == null) return const Stream.empty();
  return ref.watch(chatRepositoryProvider).watchMyChats(uid);
});

final unreadCountsProvider = StreamProvider<Map<String, int>>((ref) {
  final uid = ref.watch(authRepositoryProvider).currentUser?.id;
  if (uid == null) return Stream.value(const {});

  return ref.watch(chatRepositoryProvider).watchUnreadCounts(uid);
});

final chatSettingsProvider = StreamProvider<Map<String, Map<String, dynamic>>>((
  ref,
) {
  final uid = ref.watch(authRepositoryProvider).currentUser?.id;
  if (uid == null) return Stream.value({});
  return ref.watch(chatRepositoryProvider).watchChatSettings(uid);
});

final totalUnreadCountProvider = Provider<int>((ref) {
  final countsAsync = ref.watch(unreadCountsProvider);
  final counts = countsAsync.valueOrNull ?? {};
  return counts.values.fold(0, (sum, count) => sum + count);
});

final myChatsProvider = StreamProvider<List<ChatModel>>((ref) {
  final chatsAsync = ref.watch(rawChatsProvider);
  final unreadAsync = ref.watch(unreadCountsProvider);
  final countsMap = unreadAsync.valueOrNull ?? {};
  final settingsMap = ref.watch(chatSettingsProvider).valueOrNull ?? {};

  return chatsAsync.when(
    data: (chats) {
      final merged = chats
          .map((c) {
            final setting = settingsMap[c.chatId] ?? {};
            return c.copyWith(
              unreadCount: countsMap[c.chatId] ?? 0,
              isPinned: setting['is_pinned'] ?? false,
              isArchived: setting['is_archived'] ?? false,
              silencedUntil: setting['silenced_until'] != null
                  ? DateTime.parse(
                      setting['silenced_until'].toString(),
                    ).toLocal()
                  : null,
            );
          })
          .where((c) => !c.isArchived)
          .toList();

      // Sort: Pinned first, then by lastAt/createdAt
      merged.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        return (b.lastAt ?? b.createdAt).compareTo(a.lastAt ?? a.createdAt);
      });

      return Stream.value(merged);
    },
    loading: () => const Stream.empty(),
    error: (err, stack) => Stream.error(err, stack),
  );
});

final archivedChatsProvider = StreamProvider<List<ChatModel>>((ref) {
  final chatsAsync = ref.watch(rawChatsProvider);
  final countsMap = ref.watch(unreadCountsProvider).valueOrNull ?? {};
  final settingsMap = ref.watch(chatSettingsProvider).valueOrNull ?? {};

  return chatsAsync.when(
    data: (chats) {
      final merged = chats
          .map((c) {
            final setting = settingsMap[c.chatId] ?? {};
            return c.copyWith(
              unreadCount: countsMap[c.chatId] ?? 0,
              isPinned: setting['is_pinned'] ?? false,
              isArchived: setting['is_archived'] ?? false,
              silencedUntil: setting['silenced_until'] != null
                  ? DateTime.parse(
                      setting['silenced_until'].toString(),
                    ).toLocal()
                  : null,
            );
          })
          .where((c) => c.isArchived)
          .toList();

      // Sort: Pinned first (though archive usually isn't pinned, let's keep it consistent)
      merged.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        return (b.lastAt ?? b.createdAt).compareTo(a.lastAt ?? a.createdAt);
      });

      return Stream.value(merged);
    },
    loading: () => const Stream.empty(),
    error: (err, stack) => Stream.error(err, stack),
  );
});

final spamChatsProvider = StreamProvider<List<ChatModel>>((ref) {
  final uid = ref.watch(authRepositoryProvider).currentUser?.id;
  if (uid == null) return const Stream.empty();
  return ref.watch(chatRepositoryProvider).watchSpamChats(uid);
});

// ── Messages for a specific chat ──────────────────────────────────────────────

final messagesProvider = StreamProvider.family<List<MessageModel>, String>((
  ref,
  chatId,
) {
  final ageGroup = ref.watch(currentAgeGroupProvider);
  final myUid = ref.watch(authRepositoryProvider).currentUser?.id;
  final repo = ref.watch(chatRepositoryProvider);
  final decryptedCacheById = <String, String>{};
  final ciphertextCacheById = <String, String>{};

  return repo
      .watchMessages(
    chatId: chatId,
    callerAgeGroup: ageGroup,
    callerUid: myUid ?? '',
  )
      .asyncMap((messages) async {
    if (messages.isEmpty) return messages;

    final now = DateTime.now();
    final validMessages = messages.where((m) {
      if (m.expiresAt == null) return true;
      return m.expiresAt!.isAfter(now);
    }).toList();

    final visibleMessages =
        validMessages.where((m) => m.metadata['xparq_call'] == null).toList();

    if (visibleMessages.isEmpty && messages.isNotEmpty) {
      return <MessageModel>[];
    }

    // 1) Fetch all cached plaintexts pre-emptively
    final messageIds = visibleMessages.map((m) => m.messageId).toList();
    final persistentCache =
        await OfflineChatDatabase.instance.getSignalMessageCache(messageIds);

    // 2) SYNC-FIRST RESOLUTION: Resolve everything we already know (O(N) sync)
    // This is key for 0ms confirming of rapid bursts.
    final syncProcessed = visibleMessages.map((message) {
      final messageId = message.messageId;
      final rawCiphertext = message.content;

      // A. Memory Cache
      if (ciphertextCacheById[messageId] == rawCiphertext &&
          decryptedCacheById[messageId] != null) {
        return message.copyWith(
            decryptedContent: decryptedCacheById[messageId]);
      }

      // B. Database Cache
      final cachedData = persistentCache[messageId];
      if (cachedData != null && cachedData['ciphertext'] == rawCiphertext) {
        final dbPlaintext = cachedData['plaintext']!;
        ciphertextCacheById[messageId] = rawCiphertext;
        decryptedCacheById[messageId] = dbPlaintext;
        return message.copyWith(decryptedContent: dbPlaintext);
      }

      // C. Local Optimistic Send
      if (myUid != null && message.senderUid == myUid) {
        final pendingId = message.metadata['client_pending_id']?.toString();
        final localPlaintext =
            MessageEncryptionService.resolveOutgoingPlaintext(
          ciphertext: rawCiphertext,
          pendingId: pendingId,
        );
        if (localPlaintext != null) {
          ciphertextCacheById[messageId] = rawCiphertext;
          decryptedCacheById[messageId] = localPlaintext;
          return message.copyWith(decryptedContent: localPlaintext);
        }
      }

      // D. Signal Bypass (System Broken)
      if (SignalSessionManager.isBroken) {
        if (myUid != null && message.senderUid == myUid) {
          // Ours: Try resolution from local send history
          final pendingId = message.metadata['client_pending_id']?.toString();
          final plaintext = MessageEncryptionService.resolveOutgoingPlaintext(
                ciphertext: rawCiphertext,
                pendingId: pendingId,
              ) ??
              rawCiphertext; // Still raw, but at least we tried
          ciphertextCacheById[messageId] = rawCiphertext;
          decryptedCacheById[messageId] = plaintext;
          return message.copyWith(decryptedContent: plaintext);
        } else {
          // Theirs: Use human-readable placeholder (Don't show raw syntax)
          const placeholder =
              '🔒 Encrypted message (Signal service unavailable)';
          ciphertextCacheById[messageId] = rawCiphertext;
          decryptedCacheById[messageId] = placeholder;
          return message.copyWith(decryptedContent: placeholder);
        }
      }

      return message;
    }).toList();

    // If everything is already resolved (typical for bursts/confirmations),
    // return IMMEDIATELY without entering the async machinery.
    final needsAsync = syncProcessed.any((m) => m.decryptedContent == null);
    if (!needsAsync) return syncProcessed;

    // 3) Background Async Decryption for remaining placeholders (rare)
    final processed = await Future.wait(syncProcessed.map((message) async {
      if (message.decryptedContent != null) return message;

      final messageId = message.messageId;
      final rawCiphertext = message.content;
      String plaintext;
      try {
        plaintext =
            await MessageEncryptionService.decrypt(rawCiphertext, chatId);
      } catch (e) {
        if (e.toString().contains('UnsatisfiedLinkError') ||
            e.toString().contains('Dynamic library') ||
            e.toString().contains('Failed to load') ||
            e.toString().contains('Cannot open shared object')) {
          SignalSessionManager.instance.markBroken();
        }
        final pendingId = message.metadata['client_pending_id']?.toString();
        plaintext = MessageEncryptionService.resolveOutgoingPlaintext(
              ciphertext: rawCiphertext,
              pendingId: pendingId,
            ) ??
            rawCiphertext;
      }

      ciphertextCacheById[messageId] = rawCiphertext;
      decryptedCacheById[messageId] = plaintext;
      if (plaintext != rawCiphertext && plaintext.isNotEmpty) {
        await OfflineChatDatabase.instance
            .cacheSignalMessage(messageId, plaintext, rawCiphertext);
      }
      return message.copyWith(decryptedContent: plaintext);
    }));

    return processed;
  });
});

final displayMessagesProvider =
    Provider.family<AsyncValue<List<MessageModel>>, String>((ref, chatId) {
  final dbAsync = ref.watch(messagesProvider(chatId));
  final pendingMap = ref.watch(pendingMessagesProvider);
  // Use ref.read (not ref.watch) to avoid a feedback loop:
  // Writing to messageIdentityMapperProvider inside this provider's
  // microtask would re-trigger this provider if we used watch here.
  final idMap = ref.read(messageIdentityMapperProvider);
  final pendingForChat = pendingMap[chatId] ?? const <MessageModel>[];

  return dbAsync.when(
    skipLoadingOnReload: true,
    loading: () => const AsyncValue.loading(),
    error: (err, st) => AsyncValue.error(err, st),
    data: (messages) {
      // 1. Identity Locking: Map DB UUIDs to their original pending IDs for session-long key stability.
      final mappedMessages = messages.map((m) {
        final stableId = idMap[m.messageId];
        return stableId != null ? m.copyWith(messageId: stableId) : m;
      }).toList();

      if (pendingForChat.isEmpty) return AsyncValue.data(mappedMessages);

      // 2. O(N) Reconciliation with Map-based lookups
      final merged = List<MessageModel>.from(mappedMessages);
      final pendingToRemove = <String>[];
      final identityMapUpdates = <String, String>{};

      // A. Create index of DB records by their 'client_pending_id' metadata
      final dbByPendingId = <String, MessageModel>{};
      // B. Create index of DB records by fuzzy key (sender + text + timestamp-window)
      final dbByFuzzyKey = <String, MessageModel>{};

      for (final m in mappedMessages) {
        final pId = m.metadata['client_pending_id']?.toString();
        if (pId != null) dbByPendingId[pId] = m;

        final text = m.decryptedContent ?? m.content;
        if (text.isNotEmpty) {
          // Keys are sender+text+timestamp rounded to 15s to allow for network jitter
          final fuzzyKey =
              '${m.senderUid}_${text}_${m.timestamp.millisecondsSinceEpoch ~/ 15000}';
          dbByFuzzyKey[fuzzyKey] = m;
        }
      }

      final pendingSorted = List<MessageModel>.from(pendingForChat)
        ..sort(
          (a, b) => a.timestamp.compareTo(b.timestamp),
        );

      for (final pm in pendingSorted) {
        final text = pm.decryptedContent ?? pm.content;
        final fuzzyKey =
            '${pm.senderUid}_${text}_${pm.timestamp.millisecondsSinceEpoch ~/ 15000}';

        // Check for direct ID match first, then fuzzy
        var match = dbByPendingId[pm.messageId] ?? dbByFuzzyKey[fuzzyKey];

        if (match != null) {
          // Identity Anchor Frame (Locks the ID for the entire app session)
          identityMapUpdates[match.messageId] = pm.messageId;

          final idx = merged.indexWhere(
            (m) =>
                m.messageId == match.messageId || m.messageId == pm.messageId,
          );

          if (idx != -1) {
            final currentText = merged[idx].decryptedContent ?? '';
            final isPlaceholder =
                currentText.isEmpty || currentText.startsWith('🔒');

            if (!isPlaceholder) {
              pendingToRemove.add(pm.messageId);
            }

            merged[idx] = merged[idx].copyWith(
              messageId: pm.messageId, // Identity Anchor
              decryptedContent:
                  isPlaceholder ? (pm.decryptedContent ?? pm.content) : null,
              timestamp: pm.timestamp, // Position Anchor
              metadata: {
                ...merged[idx].metadata,
                'server_id': match.messageId, // Real Database ID
              },
            );
          }
        } else {
          // Ghost message cleanup (60s)
          final age = DateTime.now().difference(pm.timestamp).inSeconds;
          if (age > 60) {
            pendingToRemove.add(pm.messageId);
          } else {
            merged.add(pm);
          }
        }
      }

      if (pendingToRemove.isNotEmpty || identityMapUpdates.isNotEmpty) {
        Future.microtask(() {
          // Guard: only update if the entries are actually new (prevents repeated microtasks).
          if (identityMapUpdates.isNotEmpty) {
            final notifier = ref.read(messageIdentityMapperProvider.notifier);
            final currentMap = ref.read(messageIdentityMapperProvider);
            final newEntries = identityMapUpdates.entries
                .where((e) => currentMap[e.key] != e.value)
                .toList();
            for (final e in newEntries) {
              notifier.mapIdentity(e.key, e.value);
            }
          }
          if (pendingToRemove.isNotEmpty) {
            ref
                .read(pendingMessagesProvider.notifier)
                .removePendingMessages(chatId, pendingToRemove);
          }
        });
      }

      merged.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return AsyncValue.data(merged);
    },
  );
});

final pinnedMessagesProvider =
    StreamProvider.family<List<MessageModel>, String>((ref, chatId) {
  final repo = ref.watch(chatRepositoryProvider);
  return repo.watchPinnedMessages(chatId);
});

// ── Send Message State ────────────────────────────────────────────────────────

// ... (SendMessageNotifier was removed previously)

// ── Typing Indicator State ──────────────────────────────────────────────────

class TypingStateNotifier extends StateNotifier<Set<String>> {
  TypingStateNotifier() : super({});

  void addTypingUser(String uid) {
    if (!state.contains(uid)) {
      state = {...state, uid};
    }
  }

  void removeTypingUser(String uid) {
    if (state.contains(uid)) {
      final newState = Set<String>.from(state);
      newState.remove(uid);
      state = newState;
    }
  }

  void setTypingUsers(Set<String> uids) {
    state = uids;
  }
}

final typingStateProvider =
    StateNotifierProvider.family<TypingStateNotifier, Set<String>, String>((
  ref,
  chatId,
) {
  return TypingStateNotifier();
});
