import 'package:xparq_app/shared/errors/app_exception.dart';
import 'package:xparq_app/features/control_deck/models/dashboard_model.dart';
import 'package:xparq_app/features/control_deck/repositories/control_repository.dart';

class ControlService {
  const ControlService(this._repository);

  final ControlRepository _repository;

  Future<Dashboard> getDashboard() async {
    try {
      return await _repository.get();
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException('Unable to fetch dashboard data.', cause: error);
    }
  }
}
