// lib/core/router/app_router.dart
//
// GoRouter configuration for XPARQ.
//
// Route tree:
//   /                     → AuthGateScreen (redirect logic lives here)
//   /welcome              → WelcomeScreen
//   /auth/phone           → PhoneAuthScreen
//   /auth/email           → EmailAuthScreen
//   /auth/dob             → DobInputScreen
//   /onboarding/planet    → PlanetCreationScreen
//   /shell                → ControlDeckScreen (ShellRoute with bottom nav)
//     /shell/orbit        → OrbitScreen
//     /shell/radar        → RadarScreen
//     /shell/signal       → ChatListScreen
//     /shell/profile      → UserProfileScreen
//   /chat/:chatId         → SignalChatScreen  (full-screen over shell)
//   /profile/edit         → EditProfileScreen
//   /settings             → SettingsScreen
//   /settings/blocked     → BlockedUsersScreen
//   /profile/:uid         → UserProfileScreen (viewing someone else's profile)

import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:xparq_app/core/router/app_shell.dart';
import 'package:xparq_app/core/router/router_providers.dart';
import 'package:xparq_app/core/router/router_transitions.dart';
import 'package:xparq_app/features/auth/providers/auth_providers.dart';
import 'package:xparq_app/features/auth/screens/auth_gate_screen.dart';
import 'package:xparq_app/features/auth/screens/onboarding/dob_input_screen.dart';
import 'package:xparq_app/features/auth/screens/onboarding/email_auth_screen.dart';
import 'package:xparq_app/features/auth/screens/onboarding/forgot_password_screen.dart';
import 'package:xparq_app/features/auth/screens/onboarding/planet_creation_screen.dart';
import 'package:xparq_app/features/auth/screens/onboarding/reset_password_screen.dart';
import 'package:xparq_app/features/auth/screens/onboarding/welcome_screen.dart';
import 'package:xparq_app/features/block_report/screens/blocked_users_screen.dart';
import 'package:xparq_app/features/chat/presentation/screens/chat_list_screen.dart';
import 'package:xparq_app/features/chat/presentation/screens/create_group_screen.dart';
import 'package:xparq_app/features/chat/presentation/screens/signal_chat_screen.dart';
import 'package:xparq_app/features/chat/presentation/screens/archived_list_screen.dart';
import 'package:xparq_app/features/profile/screens/edit_profile_screen.dart';
import 'package:xparq_app/features/profile/screens/settings_screen.dart';
import 'package:xparq_app/features/profile/screens/user_profile_screen.dart';
import 'package:xparq_app/features/profile/screens/quick_login_settings.dart';
import 'package:xparq_app/features/radar/screens/radar_screen.dart';
import 'package:xparq_app/features/social/screens/create_pulse_screen.dart';
import 'package:xparq_app/features/social/screens/orbit_list_screen.dart';
import 'package:xparq_app/features/social/screens/orbit_screen.dart';
import 'package:xparq_app/features/social/screens/scanner_screen.dart';
import 'package:xparq_app/features/profile/screens/settings/accounts_center_screen.dart';
import 'package:xparq_app/features/profile/screens/settings/password_security_screen.dart';
import 'package:xparq_app/features/profile/screens/settings/privacy_safety_screen.dart';
import 'package:xparq_app/features/profile/screens/settings/notifications_screen.dart';
import 'package:xparq_app/features/profile/screens/settings/content_display_screen.dart';
import 'package:xparq_app/features/profile/screens/settings/media_screen.dart';
import 'package:xparq_app/features/profile/screens/settings/family_center_screen.dart';
import 'package:xparq_app/features/profile/screens/settings/help_support_screen.dart';
import 'package:xparq_app/features/offline/screens/offline_permission_screen.dart';
import 'package:xparq_app/features/offline/screens/offline_dashboard_screen.dart';
import 'package:xparq_app/features/offline/screens/offline_radar_screen.dart';
import 'package:xparq_app/features/offline/screens/offline_signal_screen.dart';
import 'package:xparq_app/features/offline/screens/offline_profile_screen.dart';
import 'package:xparq_app/features/offline/screens/offline_settings_screen.dart';
import 'package:xparq_app/features/offline/screens/offline_chat_screen.dart';
import 'package:xparq_app/features/offline/screens/offline_onboarding_screen.dart';
import 'package:xparq_app/features/offline/screens/offline_other_profile_screen.dart';
import 'package:xparq_app/features/offline/providers/offline_state_provider.dart';
import 'package:xparq_app/features/offline/providers/offline_user_provider.dart';
import 'package:xparq_app/features/social/screens/camera_screen.dart';
import 'package:xparq_app/features/social/screens/nebula_picker_screen.dart';
import 'package:xparq_app/features/social/models/pulse_model.dart';
import 'package:xparq_app/features/social/screens/supernova_viewer_screen.dart';

// Re-export router_providers so callers that used to import from app_router still work.
export 'package:xparq_app/core/router/router_providers.dart';

// ── Route Names (use these for named navigation) ──────────────────────────────

class AppRoutes {
  static const welcome = '/welcome';
  static const phoneAuth = '/welcome/auth/phone';
  static const emailAuth = '/welcome/auth/email';
  static const dobInput = '/auth/dob';
  static const planetCreateBase = '/onboarding/planet';
  static const planetCreate = '/onboarding/planet/:dob';
  static const shell = '/shell';
  static const orbit = '/shell/orbit';
  static const radar = '/shell/radar';
  static const signal = '/shell/signal';
  static const profile = '/shell/profile';
  static const createPulse = '/social/create';
  static const chat = '/chat';
  static const editProfile = '/profile/edit';
  static const settings = '/settings';
  static const blocked = '/settings/blocked';
  static const otherProfile = '/profile/view';
  static const orbitList = '/profile/orbit-list';
  static const forgotPassword = '/forgot-password';
  static const accountsCenter = '/settings/accounts-center';
  static const passwordSecurity = '/settings/accounts-center/password-security';
  static const quickLogin = '/settings/quick-login';
  static const privacySafety = '/settings/privacy-safety';
  static const notificationsSettings = '/settings/notifications';
  static const contentDisplay = '/settings/content-display';
  static const mediaSettings = '/settings/media';
  static const familyCenter = '/settings/family-center';
  static const helpSupport = '/settings/help-support';
  static const qrScanner = '/social/scan';
  static const resetPassword = '/reset-password';
  static const camera = '/social/camera';
  static const nebulaPicker = '/social/nebula';
  static const supernovaViewer = '/social/supernova-viewer';

  // Offline Routes
  static const offlinePermission = '/offline/permission';
  static const offlineDashboard = '/offline/dashboard';
  static const offlineRadar = '/offline/dashboard/radar';
  static const offlineSignal = '/offline/dashboard/signal';
  static const offlineProfile = '/offline/dashboard/profile';
  static const offlineSettings = '/offline/dashboard/settings';
  static const offlineChat = '/offline/chat';
  static const offlineOtherProfile = '/offline/profile/view';
  static const offlineOnboarding = '/offline/onboarding';
  static const createGroup = '/chat/new-group';
  static const archivedChats = '/chat/archived';
}

// ── Router Provider ───────────────────────────────────────────────────────────

final appRouterProvider = Provider<GoRouter>((ref) {
  final authNotifier = _AuthListenable(ref);
  final persistence = ref.watch(navigationPersistenceProvider);

  String initialLocation = '/';
  if (persistence.shouldRestore()) {
    final lastLoc = persistence.getLastLocation();
    final restorableRoutes = [
      AppRoutes.orbit,
      AppRoutes.radar,
      AppRoutes.signal,
      AppRoutes.profile,
    ];
    if (lastLoc != null && restorableRoutes.contains(lastLoc)) {
      debugPrint('ROUTER: Restoring session to $lastLoc');
      initialLocation = lastLoc;
    } else if (lastLoc != null && lastLoc != '/') {
      debugPrint('ROUTER: Not restoring non-shell route: $lastLoc');
    }
  }

  final router = GoRouter(
    initialLocation: initialLocation,
    refreshListenable: authNotifier,
    redirect: (context, state) {
      debugPrint('ROUTER: Redirecting from ${state.matchedLocation}');

      final isOffline = ref.read(isOfflineModeProvider);
      if (isOffline) {
        final offlineUser = ref.read(offlineUserProvider);
        if (!offlineUser.isLoaded) return null;

        final bool needsOnboarding = offlineUser.displayName.isEmpty;
        final String currentLoc = state.matchedLocation;

        if (needsOnboarding) {
          if (currentLoc != AppRoutes.offlineOnboarding &&
              currentLoc != AppRoutes.offlinePermission) {
            return AppRoutes.offlineOnboarding;
          }
          return null;
        }

        if (currentLoc == AppRoutes.offlineOnboarding) {
          return AppRoutes.offlineRadar;
        }

        if (currentLoc == AppRoutes.offlineDashboard || currentLoc == '/') {
          return AppRoutes.offlineRadar;
        }

        return null;
      }

      final authNotifierState = ref.read(authNotifierProvider);
      final isDeleting = authNotifierState.isDeleting;

      if (isDeleting) return AppRoutes.welcome;

      if (authNotifierState.step == AuthStep.recovery) {
        debugPrint('ROUTER: Recovery detected, going to ResetPassword');
        return AppRoutes.resetPassword;
      }

      final authState = ref.read(supabaseAuthStateProvider);
      final isLoggedIn = authState.valueOrNull != null;
      final isLoginFlow = ref.read(isLoginFlowProvider);
      final profileAsync = ref.read(planetProfileProvider);
      final hasProfile = profileAsync.valueOrNull != null;
      final isProfileLoading = profileAsync.isLoading;

      final onboarding = [
        AppRoutes.welcome,
        AppRoutes.phoneAuth,
        AppRoutes.emailAuth,
        AppRoutes.dobInput,
        AppRoutes.planetCreate,
        AppRoutes.forgotPassword,
      ];
      final isOnOnboarding =
          (onboarding.any((r) => state.matchedLocation.startsWith(r)) ||
          state.matchedLocation.startsWith(AppRoutes.planetCreateBase));

      if (!isLoggedIn) {
        if (state.matchedLocation == '/') return null;
        final allowedLoggedOut = [
          AppRoutes.welcome,
          AppRoutes.phoneAuth,
          AppRoutes.emailAuth,
          AppRoutes.forgotPassword,
          AppRoutes.offlinePermission,
        ];
        final isAllowed = allowedLoggedOut.any(
          (r) => state.matchedLocation.startsWith(r),
        );
        return isAllowed ? null : AppRoutes.welcome;
      }

      if (isLoggedIn && isProfileLoading) return null;

      if (isLoggedIn && !hasProfile && !isProfileLoading) {
        debugPrint(
          'ROUTER: Logged in, no profile. Location: ${state.matchedLocation}',
        );

        if (state.matchedLocation.startsWith(AppRoutes.welcome) ||
            state.matchedLocation == '/') {
          return null;
        }

        if (isOnOnboarding) {
          debugPrint('ROUTER: On onboarding route, allowing.');
          return null;
        }

        if (isLoginFlow) {
          debugPrint('ROUTER: Login flow detected, refusing to jump to DOB.');
          return null;
        }

        debugPrint(
          'ROUTER: Logged in, no profile, not on onboarding. Redirecting to DOB.',
        );
        return AppRoutes.dobInput;
      }

      if (isLoggedIn && hasProfile && isOnOnboarding && !isDeleting) {
        debugPrint(
          'ROUTER: Logged in, has profile, on onboarding. Redirecting to radar.',
        );
        return AppRoutes.radar;
      }

      if (state.matchedLocation.startsWith('/profile/') &&
          !state.matchedLocation.startsWith('/profile/view') &&
          !state.matchedLocation.startsWith('/profile/edit') &&
          !state.matchedLocation.startsWith('/profile/orbit-list')) {
        final uid =
            state.pathParameters['uid'] ??
            state.matchedLocation.split('/').last;
        if (uid.isNotEmpty && uid != 'profile') {
          debugPrint(
            'ROUTER: Deep link redirect /profile/$uid -> /profile/view/$uid',
          );
          return '${AppRoutes.otherProfile}/$uid';
        }
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const AuthGateScreen()),

      // ── Offline Routes ─────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.offlineOnboarding,
        pageBuilder: (context, state) => fadeSlidePage(
          key: state.pageKey,
          child: const OfflineOnboardingScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.offlinePermission,
        pageBuilder: (context, state) => fadeSlidePage(
          key: state.pageKey,
          child: const OfflinePermissionScreen(),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) =>
            OfflineAppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.offlineRadar,
                builder: (_, _) => const OfflineRadarScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.offlineSignal,
                builder: (_, _) => const OfflineSignalScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.offlineProfile,
                builder: (_, _) => const OfflineProfileScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.offlineSettings,
                builder: (_, _) => const OfflineSettingsScreen(),
              ),
            ],
          ),
        ],
      ),

      // ── Onboarding ─────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.welcome,
        pageBuilder: (context, state) =>
            fadeSlidePage(key: state.pageKey, child: const WelcomeScreen()),
        routes: [
          GoRoute(
            path: 'auth/email',
            pageBuilder: (context, state) {
              final isLogin = (state.extra is bool) ? state.extra as bool : true;
              return fadeSlidePage(
                key: state.pageKey,
                child: EmailAuthScreen(isLogin: isLogin),
              );
            },
          ),
          GoRoute(
            path: 'auth/phone',
            pageBuilder: (context, state) {
              final isLogin = (state.extra is bool) ? state.extra as bool : true;
              return fadeSlidePage(
                key: state.pageKey,
                child: PhoneAuthScreen(isLogin: isLogin),
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.dobInput,
        pageBuilder: (context, state) =>
            fadeSlidePage(key: state.pageKey, child: const DobInputScreen()),
      ),
      GoRoute(
        path: AppRoutes.planetCreate,
        pageBuilder: (context, state) {
          final dobStr = state.pathParameters['dob'];
          DateTime? dob;
          if (dobStr != null && dobStr != 'null') {
            dob = DateTime.tryParse(dobStr);
          }
          dob ??= state.extra as DateTime?;
          return fadeSlidePage(
            key: state.pageKey,
            child: PlanetCreationScreen(dob: dob),
          );
        },
      ),

      // ── Main Shell (Bottom Nav) ────────────────────────────────────────────
      StatefulShellRoute(
        builder: (_, _, navigationShell) => navigationShell,
        navigatorContainerBuilder: (context, navigationShell, children) {
          return AppShell(
            navigationShell: navigationShell,
            children: children,
          );
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.orbit,
                builder: (_, _) => const OrbitScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.radar,
                builder: (_, _) => const RadarScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.signal,
                builder: (_, _) => const ChatListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (_, _) => const UserProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // ── Full-screen Routes (over shell) ────────────────────────────────────
      GoRoute(
        path: AppRoutes.createPulse,
        name: 'createPulse',
        builder: (context, state) {
          final data = state.extra as Map<String, dynamic>?;
          return CreatePulseScreen(
            initialImage: data?['image'] as XFile?,
            initialVideo: data?['video'] as XFile?,
            isWarpGear: data?['isWarpGear'] as bool? ?? false,
            isSupernova: data?['isSupernova'] as bool? ?? false,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.camera,
        name: 'camera',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final mode = extra?['mode'] as String? ?? 'photo';
          return CameraScreen(initialMode: mode);
        },
      ),
      GoRoute(
        path: AppRoutes.nebulaPicker,
        name: 'nebulaPicker',
        builder: (context, state) => const NebulaPickerScreen(),
      ),
      GoRoute(
        path: AppRoutes.supernovaViewer,
        name: 'supernovaViewer',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          final pulses = extra['pulses'] as List<PulseModel>;
          final initialIndex = extra['initialIndex'] as int? ?? 0;
          return SupernovaViewerScreen(
            pulses: pulses,
            initialIndex: initialIndex,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.qrScanner,
        builder: (context, state) => const ScannerScreen(),
      ),
      GoRoute(
        path: AppRoutes.createGroup,
        builder: (_, _) => const CreateGroupScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.chat}/:chatId/:otherUid',
        name: AppRoutes.chat,
        pageBuilder: (context, state) {
          final chatId = state.pathParameters['chatId']!;
          final otherUid = state.pathParameters['otherUid']!;
          final extra = state.extra as Map<String, dynamic>?;
          final isSpamMode = extra?['isSpamMode'] as bool? ?? false;

          return zoomFadePage(
            key: state.pageKey,
            child: SignalChatScreen(
              chatId: chatId,
              otherUid: otherUid,
              isSpamMode: isSpamMode,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.editProfile,
        builder: (_, _) => const EditProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (_, _) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'accounts-center',
            builder: (_, _) => const AccountsCenterScreen(),
            routes: [
              GoRoute(
                path: 'password-security',
                builder: (_, _) => const PasswordAndSecurityScreen(),
              ),
            ],
          ),
          GoRoute(path: 'blocked', builder: (_, _) => const BlockedUsersScreen()),
          GoRoute(path: 'privacy-safety', builder: (_, _) => const PrivacySafetyScreen()),
          GoRoute(path: 'quick-login', builder: (_, _) => const QuickLoginSettingsScreen()),
          GoRoute(path: 'notifications', builder: (_, _) => const NotificationsScreen()),
          GoRoute(path: 'content-display', builder: (_, _) => const ContentDisplayScreen()),
          GoRoute(path: 'media', builder: (_, _) => const MediaScreen()),
          GoRoute(path: 'family-center', builder: (_, _) => const FamilyCenterScreen()),
          GoRoute(path: 'help-support', builder: (_, _) => const HelpSupportScreen()),
        ],
      ),
      GoRoute(
        path: AppRoutes.blocked,
        builder: (_, _) => const BlockedUsersScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.otherProfile}/:uid',
        builder: (_, state) =>
            UserProfileScreen(viewingUid: state.pathParameters['uid']),
      ),
      GoRoute(
        path: AppRoutes.orbitList,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return OrbitListScreen(
            uid: extra['uid'] as String,
            initialTabIndex: (extra['collection'] == 'orbiting') ? 1 : 0,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (_, _) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.offlineChat,
        builder: (context, state) {
          final extras = state.extra as Map<String, dynamic>;
          return OfflineChatScreen(
            peerId: extras['peerId'] as String,
            peerName: extras['peerName'] as String,
            endpointId: extras['endpointId'] as String,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.offlineOtherProfile,
        builder: (context, state) {
          final extras = state.extra as Map<String, dynamic>;
          return OfflineOtherProfileScreen(
            peerId: extras['peerId'] as String,
            displayName: extras['displayName'] as String,
            endpointId: extras['endpointId'] as String,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.archivedChats,
        builder: (context, state) => const ArchivedListScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text(
          '🌌 Route not found\n${state.error}',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54),
            backgroundColor:
                Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
          ),
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );

  router.routerDelegate.addListener(() {
    final String location =
        router.routerDelegate.currentConfiguration.last.matchedLocation;
    if (location != '/' && location != AppRoutes.welcome) {
      persistence.saveLocation(location);
    }
  });

  return router;
});

// ── Auth Refresh Listenable ───────────────────────────────────────────────────

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen(supabaseAuthStateProvider, (_, _) => notifyListeners());
    ref.listen(planetProfileProvider, (_, _) => notifyListeners());
    ref.listen(authNotifierProvider, (_, _) => notifyListeners());
    ref.listen(isOfflineModeProvider, (_, _) => notifyListeners());
    ref.listen(offlineUserProvider, (_, _) => notifyListeners());
  }
}
