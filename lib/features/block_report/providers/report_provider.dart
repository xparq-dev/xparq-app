import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/core/errors/app_exception.dart';
import 'package:xparq_app/features/block_report/models/report_model.dart';
import 'package:xparq_app/features/block_report/repositories/report_repository.dart';
import 'package:xparq_app/features/block_report/services/report_service.dart';

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return ReportRepository();
});

final reportServiceProvider = Provider<ReportService>((ref) {
  return ReportService(ref.read(reportRepositoryProvider));
});

@immutable
class ReportState {
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  const ReportState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  ReportState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    String? successMessage,
    bool clearSuccess = false,
  }) {
    return ReportState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess
          ? null
          : (successMessage ?? this.successMessage),
    );
  }
}

class ReportProvider extends StateNotifier<ReportState> {
  ReportProvider({
    required ReportService service,
    required String currentUserId,
  }) : _service = service,
       _currentUserId = currentUserId,
       super(const ReportState());

  final ReportService _service;
  final String _currentUserId;

  Future<void> reportUser(Report report) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSuccess: true,
    );

    try {
      await _service.report(reporterId: _currentUserId, report: report);

      state = state.copyWith(
        isLoading: false,
        successMessage: 'Report saved successfully.',
        clearError: true,
      );
    } on AppException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to submit the report.',
      );
    }
  }

  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }
}

final reportProvider = StateNotifierProvider.autoDispose
    .family<ReportProvider, ReportState, String>((ref, currentUserId) {
      return ReportProvider(
        service: ref.read(reportServiceProvider),
        currentUserId: currentUserId,
      );
    });
