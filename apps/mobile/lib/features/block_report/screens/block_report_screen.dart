import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/features/block_report/models/report_model.dart';
import 'package:xparq_app/features/block_report/providers/block_provider.dart';
import 'package:xparq_app/features/block_report/providers/report_provider.dart';
import 'package:xparq_app/features/block_report/widgets/block_report_form.dart';

class BlockReportScreen extends ConsumerStatefulWidget {
  const BlockReportScreen({
    super.key,
    required this.currentUserId,
    required this.targetUserId,
    this.targetDisplayName = 'this user',
  });

  final String currentUserId;
  final String targetUserId;
  final String targetDisplayName;

  @override
  ConsumerState<BlockReportScreen> createState() => _BlockReportScreenState();
}

class _BlockReportScreenState extends ConsumerState<BlockReportScreen> {
  late final TextEditingController _reasonController;

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _blockUser() async {
    FocusScope.of(context).unfocus();
    await ref
        .read(blockProvider(widget.currentUserId).notifier)
        .blockUser(widget.targetUserId);
  }

  Future<void> _reportUser() async {
    FocusScope.of(context).unfocus();
    await ref
        .read(reportProvider(widget.currentUserId).notifier)
        .reportUser(
          Report(userId: widget.targetUserId, reason: _reasonController.text),
        );

    final reportState = ref.read(reportProvider(widget.currentUserId));
    if (reportState.errorMessage == null) {
      _reasonController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<BlockState>(blockProvider(widget.currentUserId), (
      previous,
      next,
    ) {
      if (previous?.errorMessage != next.errorMessage &&
          next.errorMessage != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(next.errorMessage!)));
      }

      if (previous?.successMessage != next.successMessage &&
          next.successMessage != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(next.successMessage!)));
      }
    });

    ref.listen<ReportState>(reportProvider(widget.currentUserId), (
      previous,
      next,
    ) {
      if (previous?.errorMessage != next.errorMessage &&
          next.errorMessage != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(next.errorMessage!)));
      }

      if (previous?.successMessage != next.successMessage &&
          next.successMessage != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(next.successMessage!)));
      }
    });

    final blockState = ref.watch(blockProvider(widget.currentUserId));
    final reportState = ref.watch(reportProvider(widget.currentUserId));

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Block & Report')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: BlockReportForm(
                  reasonController: _reasonController,
                  isBlocking: blockState.isLoading,
                  isReporting: reportState.isLoading,
                  onBlock: _blockUser,
                  onReport: _reportUser,
                  targetDisplayName: widget.targetDisplayName,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
