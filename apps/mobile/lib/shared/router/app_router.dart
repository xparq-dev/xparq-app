// lib/core/router/app_router.dart
//
// GoRouter configuration for XPARQ.
//
// Route tree:
//     /shell/orbit        â†’ OrbitScreen
//     /shell/radar        â†’ RadarScreen
//     /shell/signal       â†’ ChatListScreen
//     /shell/profile      â†’ UserProfileScreen
//   /chat/:chatId         â†’ SignalChatScreen  (full-screen over shell)
//   /profile/edit         â†’ EditProfileScreen
//   /settings             â†’ SettingsScreen
//   /settings/blocked     â†’ BlockedUsersScreen
//   /profile/:uid         â†’ UserProfileScreen (viewing someone else's profile)

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:xparq_app/shared/router/app_shell.dart';
import 'package:xparq_app/shared/router/router_providers.dart';
import 'package:xparq_app/shared/router/router_transitions.dart';
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
import 'package:xparq_app/features/call/presentation/screens/call_session_screen.dart';
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
export 'package:xparq_app/shared/router/router_providers.dart';

// â”€â”€ Route Names (use these for named navigation) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
  static const callSession = '/call/session';
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

// â”€â”€ Router Provider â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

      // Use synchronous session check from Supabase client to avoid stale state during logout/redirects
      final isLoggedIn = Supabase.instance.client.auth.currentSession != null;
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
        final uid = state.pathParameters['uid'] ??
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

      // â”€â”€ Offline Routes â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
        builder: (context, state, navigationShell) =>
            OfflineAppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.offlineRadar,
                builder: (__, _) => const OfflineRadarScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.offlineSignal,
                builder: (__, _) => const OfflineSignalScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.offlineProfile,
                builder: (__, _) => const OfflineProfileScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.offlineSettings,
                builder: (__, _) => const OfflineSettingsScreen(),
              ),
            ],
          ),
        ],
      ),

      // â”€â”€ Onboarding â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
      GoRoute(
        path: AppRoutes.welcome,
        pageBuilder: (context, state) =>
            fadeSlidePage(key: state.pageKey, child: const WelcomeScreen()),
        routes: [
          GoRoute(
            path: 'auth/email',
            pageBuilder: (context, state) {
              final isLogin =
                  (state.extra is bool) ? state.extra as bool : true;
              return fadeSlidePage(
                key: state.pageKey,
                child: EmailAuthScreen(isLogin: isLogin),
              );
            },
          ),
          GoRoute(
            path: 'auth/phone',
            pageBuilder: (context, state) {
              final isLogin =
                  (state.extra is bool) ? state.extra as bool : true;
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

      // â”€â”€ Main Shell (Bottom Nav) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
      StatefulShellRoute(
        builder: (context, state, navigationShell) => navigationShell,
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
                builder: (__, _) => const OrbitScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.radar,
                builder: (__, _) => const RadarScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.signal,
                builder: (__, _) => const ChatListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (__, _) => const UserProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // â”€â”€ Full-screen Routes (over shell) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
      GoRoute(
        path: AppRoutes.createPulse,
        name: 'createPulse',
        pageBuilder: (context, state) {
          final data = state.extra as Map<String, dynamic>?;
          return CustomTransitionPage<void>(
            key: state.pageKey,
            opaque: false,
            barrierColor: Colors.transparent,
            transitionDuration: const Duration(milliseconds: 280),
            reverseTransitionDuration: const Duration(milliseconds: 220),
            child: CreatePulseScreen(
              initialImage: data?['image'] as XFile?,
              initialVideo: data?['video'] as XFile?,
              isWarpGear: data?['isWarpGear'] as bool? ?? false,
              isSupernova: data?['isSupernova'] as bool? ?? false,
            ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                ),
                child: child,
              );
            },
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
        builder: (__, _) => const CreateGroupScreen(),
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
        path: AppRoutes.callSession,
        name: AppRoutes.callSession,
        pageBuilder: (context, state) {
          final args = state.extra as CallSessionArgs?;
          if (args == null) {
            return zoomFadePage(
              key: state.pageKey,
              child: const Scaffold(
                body: Center(
                  child: Text('Missing call session details'),
                ),
              ),
            );
          }

          return zoomFadePage(
            key: state.pageKey,
            child: CallSessionScreen(args: args),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.editProfile,
        builder: (__, _) => const EditProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (__, _) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'accounts-center',
            builder: (__, _) => const AccountsCenterScreen(),
            routes: [
              GoRoute(
                path: 'password-security',
                builder: (__, _) => const PasswordAndSecurityScreen(),
              ),
            ],
          ),
          GoRoute(
              path: 'blocked', builder: (__, _) => const BlockedUsersScreen()),
          GoRoute(
              path: 'privacy-safety',
              builder: (__, _) => const PrivacySafetyScreen()),
          GoRoute(
              path: 'quick-login',
              builder: (__, _) => const QuickLoginSettingsScreen()),
          GoRoute(
              path: 'notifications',
              builder: (__, _) => const NotificationsScreen()),
          GoRoute(
              path: 'content-display',
              builder: (__, _) => const ContentDisplayScreen()),
          GoRoute(path: 'media', builder: (__, _) => const MediaScreen()),
          GoRoute(
              path: 'family-center',
              builder: (__, _) => const FamilyCenterScreen()),
          GoRoute(
              path: 'help-support',
              builder: (__, _) => const HelpSupportScreen()),
        ],
      ),
      GoRoute(
        path: AppRoutes.blocked,
        builder: (__, _) => const BlockedUsersScreen(),
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
        builder: (__, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (__, _) => const ResetPasswordScreen(),
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
          'ðŸŒŒ Route not found\n${state.error}',
          style: TextStyle(
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
            backgroundColor:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
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

// â”€â”€ Auth Refresh Listenable â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen(supabaseAuthStateProvider, (__, _) => notifyListeners());
    ref.listen(planetProfileProvider, (__, _) => notifyListeners());
    ref.listen(authNotifierProvider, (__, _) => notifyListeners());
    ref.listen(isOfflineModeProvider, (__, _) => notifyListeners());
    ref.listen(offlineUserProvider, (__, _) => notifyListeners());
  }
}
