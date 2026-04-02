// lib/features/block_report/providers/block_report_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/block_report_models.dart';
import '../repositories/block_report_repository.dart';

final blockReportRepositoryProvider = Provider<BlockReportRepository>(
  (_) => BlockReportRepository(),
);

// ── Blocked UIDs Stream ───────────────────────────────────────────────────────

final blockedUidsProvider = StreamProvider<List<String>>((ref) {
  final uid = ref.watch(authRepositoryProvider).currentUser?.id;
  if (uid == null) return const Stream.empty();
  return ref.watch(blockReportRepositoryProvider).watchBlockedUids(uid);
});

// ── Is Blocked Check ──────────────────────────────────────────────────────────

final isBlockedProvider = FutureProvider.family<bool, String>((
  ref,
  targetUid,
) async {
  final myUid = ref.watch(authRepositoryProvider).currentUser?.id;
  if (myUid == null) return false;
  return ref
      .read(blockReportRepositoryProvider)
      .isBlocked(myUid: myUid, targetUid: targetUid);
});

// ── Block Action Notifier ─────────────────────────────────────────────────────

class BlockNotifier extends StateNotifier<AsyncValue<void>> {
  final BlockReportRepository _repo;
  final String _myUid;

  BlockNotifier(this._repo, this._myUid) : super(const AsyncValue.data(null));

  Future<void> block(String targetUid) async {
    state = const AsyncValue.loading();
    try {
      await _repo.blockUser(myUid: _myUid, targetUid: targetUid);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> unblock(String targetUid) async {
    state = const AsyncValue.loading();
    try {
      await _repo.unblockUser(myUid: _myUid, targetUid: targetUid);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> report({
    required String targetUid,
    required ReportReason reason,
    String? chatId,
    String? detail,
    String context = 'chat',
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.submitReport(
        ReportModel(
          reporterId: _myUid,
          reportedId: targetUid,
          chatId: chatId,
          reason: reason,
          detail: detail,
          createdAt: DateTime.now(),
          context: context,
        ),
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final blockNotifierProvider =
    StateNotifierProvider<BlockNotifier, AsyncValue<void>>((ref) {
      final uid = ref.watch(authRepositoryProvider).currentUser?.id ?? '';
      return BlockNotifier(ref.watch(blockReportRepositoryProvider), uid);
    });
