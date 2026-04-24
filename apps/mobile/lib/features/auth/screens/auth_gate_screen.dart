// lib/features/auth/screens/auth_gate_screen.dart
//
// Root screen that listens to Firebase auth state and routes accordingly.
// - Not logged in â†’ OnboardingScreen
// - Logged in, no profile â†’ PlanetCreationScreen
// - Logged in, profile exists â†’ ControlDeck (main app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/features/auth/screens/onboarding/welcome_screen.dart';
import 'package:xparq_app/features/auth/screens/onboarding/account_recovery_screen.dart';
import 'package:xparq_app/shared/widgets/branding/xparq_logo.dart';
import 'package:xparq_app/features/control_deck/screens/control_deck_screen.dart';
import 'package:xparq_app/features/auth/models/planet_model.dart';
import 'package:xparq_app/features/auth/providers/auth_providers.dart';

class AuthGateScreen extends ConsumerWidget {
  const AuthGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(supabaseAuthStateProvider);
    final profileAsync = ref.watch(planetProfileProvider);
    final isDeleting = ref.watch(authNotifierProvider).isDeleting;

    if (isDeleting) return const WelcomeScreen();

    return authState.when(
      loading: () => const _GalaxyLoadingScreen(),
      error: (__, _) => const WelcomeScreen(),
      data: (user) {
        if (user == null) {
          debugPrint('AUTH_GATE: No user found. Returning WelcomeScreen.');
          return const WelcomeScreen();
        }



        return profileAsync.when(
          loading: () => const _GalaxyLoadingScreen(),
          error: (__, _) => const WelcomeScreen(),
          data: (profile) {
            if (profile == null) {
              // Always show loading screen for profile-less users at the root route.
              // The GoRouter redirect logic in app_router.dart will push them
              // to the correct onboarding screen (e.g. DobInputScreen).
              debugPrint('AUTH_GATE: Profile is null. Waiting for router redirect...');
              return const _GalaxyLoadingScreen();
            }

            // Check for Pending Deletion (30-day grace period)
            if (profile.isPendingDeletion &&
                profile.deletionRequestedAt != null) {
              final daysSinceRequest = DateTime.now()
                  .difference(profile.deletionRequestedAt!)
                  .inDays;
              if (daysSinceRequest < 30) {
                return AccountRecoveryScreen(profile: profile);
              } else {
                Future.microtask(
                  () => ref
                      .read(authRepositoryProvider)
                      .permanentlyDeleteAccount(profile.id),
                );
                return const WelcomeScreen();
              }
            }

            if (profile.nextBanCheckInAt != null &&
                profile.nextBanCheckInAt!.isBefore(DateTime.now())) {
              return _AnniversaryCheckInScreen(profile: profile);
            }

            return const ControlDeckScreen();
          },
        );
      },
    );
  }
}

class _GalaxyLoadingScreen extends StatelessWidget {
  const _GalaxyLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: XparqLogo(size: 80)),
    );
  }
}

class _AnniversaryCheckInScreen extends ConsumerWidget {
  final PlanetModel profile;
  const _AnniversaryCheckInScreen({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const XparqLogo(size: 80),
            const SizedBox(height: 24),
            const Text(
              'Guardian Check-in',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'As part of the XPARQ safety requirements for restricted accounts, we require an annual check-in to ensure you understand and comply with our community standards.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4FC3F7),
                ),
                onPressed: () async {
                  // Update next check-in to 1 year from now
                  final newDate = DateTime.now().add(const Duration(days: 365));
                  await ref.read(authRepositoryProvider).updatePlanetProfile(
                    profile.id,
                    {'next_ban_check_in_at': newDate.toIso8601String()},
                  );
                },
                child: const Text(
                  'I AGREE & COMPLY',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
