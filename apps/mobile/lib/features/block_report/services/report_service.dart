import 'package:xparq_app/shared/errors/app_exception.dart';
import 'package:xparq_app/shared/security/input_validator.dart';
import 'package:xparq_app/features/block_report/models/report_model.dart';
import 'package:xparq_app/features/block_report/repositories/report_repository.dart';

class ReportService {
  const ReportService(this._repository);

  final ReportRepository _repository;

  Future<void> report({
    required String reporterId,
    required Report report,
  }) async {
    final normalizedReporterId = reporterId.trim();
    final normalizedUserId = report.userId.trim();
    final normalizedReason = report.reason.trim();

    if (normalizedReporterId.isEmpty) {
      throw const ValidationException(
        'Reporter id is required.',
        field: 'reporterId',
      );
    }

    if (normalizedUserId.isEmpty) {
      throw const ValidationException(
        'Reported user id is required.',
        field: 'userId',
      );
    }

    if (normalizedReporterId == normalizedUserId) {
      throw const ValidationException(
        'You cannot report yourself.',
        field: 'userId',
      );
    }

    if (normalizedReason.isEmpty) {
      throw const ValidationException(
        'Report reason is required.',
        field: 'reason',
      );
    }

    final detailValidation = InputValidator.reportDetail(normalizedReason);
    if (detailValidation != null) {
      throw ValidationException(detailValidation, field: 'reason');
    }

    try {
      await _repository.report(
        reporterId: normalizedReporterId,
        report: report.copyWith(
          userId: normalizedUserId,
          reason: normalizedReason,
        ),
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException('Unable to submit the report.', cause: error);
    }
  }
}

