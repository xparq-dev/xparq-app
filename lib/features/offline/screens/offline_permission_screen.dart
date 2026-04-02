import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xparq_app/features/offline/services/bluetooth_permission_manager.dart';
import 'package:xparq_app/core/widgets/galaxy_button.dart';
import 'package:xparq_app/features/offline/providers/offline_state_provider.dart';
import 'package:xparq_app/core/router/app_router.dart';
import 'package:xparq_app/l10n/app_localizations.dart';

class OfflinePermissionScreen extends ConsumerStatefulWidget {
  const OfflinePermissionScreen({super.key});

  @override
  ConsumerState<OfflinePermissionScreen> createState() =>
      _OfflinePermissionScreenState();
}

class _OfflinePermissionScreenState
    extends ConsumerState<OfflinePermissionScreen> {
  bool _isLoading = false;

  Future<void> _requestPermissions() async {
    setState(() => _isLoading = true);

    final granted = await BluetoothPermissionManager.requestOfflinePermissions(
      context,
    );

    setState(() => _isLoading = false);

    if (granted) {
      ref.read(isOfflineModeProvider.notifier).state = true;
      if (mounted) {
        // Go to dashboard. Router will redirect to onboarding if account is not set up.
        context.go(AppRoutes.offlineRadar);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.offlinePermissionRequired,
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.close,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.bluetooth_searching_rounded,
                size: 80,
                color: Colors.blueAccent,
              ),
              const SizedBox(height: 24),
              Text(
                AppLocalizations.of(context)!.offlinePermissionTitle,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.offlinePermissionDesc,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.8),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 48),
              GalaxyButton(
                label: AppLocalizations.of(context)!.offlineAccessContinue,
                isLoading: _isLoading,
                isPrimary: true,
                onTap: _requestPermissions,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.pop(),
                child: Text(
                  AppLocalizations.of(context)!.offlineCancel,
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.54),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
