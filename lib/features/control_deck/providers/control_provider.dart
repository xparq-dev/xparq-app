import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/core/errors/app_exception.dart';
import 'package:xparq_app/features/control_deck/models/dashboard_model.dart';
import 'package:xparq_app/features/control_deck/repositories/control_repository.dart';
import 'package:xparq_app/features/control_deck/services/control_service.dart';

final controlRepositoryProvider = Provider<ControlRepository>((ref) {
  return ControlRepository();
});

final controlServiceProvider = Provider<ControlService>((ref) {
  return ControlService(ref.read(controlRepositoryProvider));
});

@immutable
class ControlState {
  final Dashboard? dashboard;
  final bool isLoading;
  final String? errorMessage;

  const ControlState({
    this.dashboard,
    this.isLoading = false,
    this.errorMessage,
  });

  ControlState copyWith({
    Dashboard? dashboard,
    bool clearDashboard = false,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ControlState(
      dashboard: clearDashboard ? null : (dashboard ?? this.dashboard),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class ControlProvider extends StateNotifier<ControlState> {
  ControlProvider(this._service) : super(const ControlState());

  final ControlService _service;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final dashboard = await _service.getDashboard();
      state = state.copyWith(
        dashboard: dashboard,
        isLoading: false,
        clearError: true,
      );
    } on AppException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to load the dashboard.',
      );
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

final controlProvider =
    StateNotifierProvider.autoDispose<ControlProvider, ControlState>((ref) {
      return ControlProvider(ref.read(controlServiceProvider));
    });
