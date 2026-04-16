/// The entry point of the XPARQ application.
///
/// This file initializes core services including Firebase, Supabase,
/// and background services, sets up the application theme and localization,
/// and handles the top-level app lifecycle and security locking.
library;

import 'dart:ui' as ui;
import 'package:firebase_core/firebase_core.dart';
import 'package:xparq_app/firebase_options.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async' as dart_async;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:xparq_app/shared/config/supabase_config.dart';
import 'package:xparq_app/shared/router/app_router.dart';
import 'package:xparq_app/shared/theme/theme_provider.dart';
import 'package:xparq_app/shared/providers/locale_provider.dart';
import 'package:xparq_app/l10n/app_localizations.dart';
import 'package:xparq_app/features/offline/services/offline_chat_database.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:xparq_app/features/chat/data/services/signal/pq_key_service.dart'; // Phase 3: PQ Keys
import 'package:xparq_app/features/chat/data/services/signal/signal_session_manager.dart'; // Phase 2: Signal Protocol
import 'package:xparq_app/features/auth/services/privacy_service.dart';
import 'package:xparq_app/features/auth/providers/auth_providers.dart';
import 'package:xparq_app/features/chat/data/services/notification_service.dart';
import 'package:xparq_app/features/chat/data/services/fcm_token_service.dart';
import 'package:xparq_app/features/chat/data/services/notification_action_handler.dart';
import 'package:xparq_app/features/chat/data/services/background_signal_service.dart';
import 'package:xparq_app/features/chat/presentation/providers/active_chat_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:xparq_app/shared/widgets/backgrounds/galactic_background.dart';
import 'package:path_provider/path_provider.dart';
import 'package:xparq_app/shared/utils/isolate_logger.dart';

/// Global flag to catch the initial password recovery event from Supabase.
///
/// This is used to trigger password recovery UI if the app was launched via
/// a recovery link.
bool initialPasswordRecoveryEvent = false;

/// Main entry point function for the Flutter application.
///
/// It performs critical initialization:
/// 1. Sets up global error handling.
/// 2. Configures image cache limits.
/// 3. Initializes Firebase and Supabase.
/// 4. Loads user preferences for theme and locale.
/// 5. Bootstraps the [ProviderScope] with overridden providers.
void main() async {
  dart_async.runZonedGuarded(
    () async {
      WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
      FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

      bool supabaseReady = false;
      String? initialError;

      // ── Global Error Handlers (prevent SIGKILL from unhandled errors) ──
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        debugPrint('🔴 FLUTTER_ERROR: ${details.exception}');
        debugPrint(details.stack.toString());
      };

      ui.PlatformDispatcher.instance.onError = (error, stack) {
        debugPrint('🔴 PLATFORM_ERROR: $error');
        debugPrint(stack.toString());
        return true; // Prevents the runtime from terminating the process
      };

      // ── Limit image cache to prevent OOM on mid-range devices ──
      PaintingBinding.instance.imageCache.maximumSizeBytes =
          50 * 1024 * 1024; // 50MB
      PaintingBinding.instance.imageCache.maximumSize = 100;

      // 1. Initialize Firebase first (Non-fatal if it fails, but better to await)
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ).timeout(const Duration(seconds: 15));
        debugPrint('MAIN: Firebase initialized.');
      } catch (e) {
        debugPrint('MAIN: Firebase init failed: $e');
      }

      // 2. Initialize Supabase (CRITICAL: Must await before runApp)
      try {
        await Supabase.initialize(
          url: SupabaseConfig.url,
          anonKey: SupabaseConfig.anonKey,
          realtimeClientOptions: const RealtimeClientOptions(
            timeout: Duration(seconds: 40),
          ),
        );
        debugPrint('MAIN: Supabase initialized.');
        supabaseReady = true;
      } catch (e) {
        debugPrint('MAIN: Supabase init error: $e');
        supabaseReady = false;
      }

      // 3. Pre-load prefs for theme/locale consistency to avoid flicker
      final prefs = await SharedPreferences.getInstance();

      // Abort if critical backend services failed to start
      if (!supabaseReady) {
        debugPrint('MAIN: Critical services not ready, setting initial error');
        initialError = 'Unable to connect to backend services';
      }

      // 3.1 Persistence for Background Isolates (fix for 'only be used in the main iso')
      try {
        final docsDir = await getApplicationDocumentsDirectory().timeout(
          const Duration(seconds: 5),
        );
        await prefs.setString('app_docs_path', docsDir.path);

        // Seed IsolateLogger with the path
        IsolateLogger.setPath(docsDir.path);

        debugPrint('MAIN: Persisted app_docs_path: ${docsDir.path}');
      } catch (e) {
        debugPrint('MAIN: Failed to persist app_docs_path: $e');
      }

      final savedLocale = prefs.getString('app_locale');
      final savedThemeLight = prefs.getBool('theme_preference') ?? false;
      final savedThemeMode = savedThemeLight ? ThemeMode.light : ThemeMode.dark;

      // 4. CALL RUNAPP ONLY AFTER CORE SERVICES ARE READY
      runApp(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            if (savedLocale != null)
              localeProvider.overrideWith(
                (ref) => LocaleNotifier(initial: Locale(savedLocale)),
              ),
            themeProvider.overrideWith(
              (ref) => ThemeNotifier(initial: savedThemeMode),
            ),
          ],
          child: XparqApp(initialError: initialError),
        ),
      );
    },
    (error, stack) {
      debugPrint('GLOBAL FATAL ERROR: $error');
      debugPrint(stack.toString());
    },
  );
}

/// The root widget of the XPARQ application.
///
/// It manages the high-level application state, including authentication
/// listeners, background services, and the security lock screen.
class XparqApp extends ConsumerStatefulWidget {
  final String? initialError;
  const XparqApp({super.key, this.initialError});

  @override
  ConsumerState<XparqApp> createState() => _XparqAppState();
}

class _XparqAppState extends ConsumerState<XparqApp>
    with WidgetsBindingObserver {
  bool _initialized = false;
  String? _initError;
  bool _isLocked = false;
  dart_async.Timer? _heartbeatTimer;

  @override
  void initState() {
    super.initState();
    _initError = widget.initialError;
    WidgetsBinding.instance.addObserver(this);
    _performStartup();
  }

  /// Handles the secondary startup phase after [runApp] is called.
  ///
  /// This includes:
  /// - Initializing Signal and Post-Quantum cryptography.
  /// - Setting up authentication change listeners.
  /// - Purging old offline data.
  /// - Starting the background signal service.
  /// - Checking for initial privacy lock.
  Future<void> _performStartup() async {
    bool firebaseReady = false;
    try {
      // Safety Check: Verify if Supabase is already initialized (from main)
      try {
        Supabase.instance.client;
      } catch (e) {
        debugPrint(
          'MAIN: Supabase NOT initialized. Forcing late initialization...',
        );
        await Supabase.initialize(
          url: SupabaseConfig.url,
          anonKey: SupabaseConfig.anonKey,
        );
      }

      // 1. Initialize Signal & PQ Managers
      try {
        await SignalSessionManager.instance.initialize();
        await KyberKeyService.instance.initializeKeys();
        debugPrint('MAIN: Cryptography initialized.');
      } catch (e) {
        debugPrint('MAIN: Crypto init error (non-fatal): $e');
      }

      // 2. Setup Auth Listeners
      try {
        // Just a check, no need to re-initialize
        if (Firebase.apps.isNotEmpty) {
          firebaseReady = true;
          debugPrint('MAIN: Firebase connection verified.');
        }
      } catch (_) {}
      Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        if (data.event == AuthChangeEvent.passwordRecovery) {
          initialPasswordRecoveryEvent = true;
        }
        final userId = data.session?.user.id;
        if (userId != null) {
          if (data.event == AuthChangeEvent.signedIn) {
            SignalSessionManager.instance.initialize().catchError(
                  (e) => debugPrint('Error init Signal: $e'),
                );
            KyberKeyService.instance.initializeKeys().catchError(
                  (e) => debugPrint('Error init Kyber: $e'),
                );
          }
          if (!kIsWeb) {
            debugPrint(
              'MAIN: Invoking updateUser with userId: $userId, event: ${data.event}',
            );
            FlutterBackgroundService().invoke('updateUser', {'userId': userId});
          }

          // Only attempt token upload if Firebase is confirmed ready
          if (firebaseReady && !kIsWeb) {
            FcmTokenService.instance.uploadToken().catchError((e) {
              debugPrint('MAIN: Failed to upload notification token: $e');
            });
          }
        }
      });

      // 5. Purge old data
      if (!kIsWeb) {
        await OfflineChatDatabase.instance.purgeOldMessages().catchError(
              (e) => debugPrint('Purge error: $e'),
            );
      }

      // 6. Initialize Background Service (Delayed for stability)
      if (!kIsWeb) {
        dart_async.Timer(const Duration(seconds: 5), () async {
          try {
            await BackgroundSignalService.initialize();
            final currentUserId = Supabase.instance.client.auth.currentUser?.id;
            debugPrint(
              '🔵 MAIN: Current user ID from Supabase: $currentUserId',
            );
            if (currentUserId != null) {
              debugPrint(
                '🔵 MAIN: BackgroundService started, invoking updateUser with: $currentUserId',
              );
              FlutterBackgroundService().invoke('updateUser', {
                'userId': currentUserId,
              });
              debugPrint(
                '🔵 MAIN: updateUser event sent to background service',
              );
            } else {
              debugPrint(
                '❌ MAIN: BackgroundService started but userId is null',
              );
            }
            debugPrint('🔵 MAIN: BackgroundService active.');
          } catch (e) {
            debugPrint('❌ MAIN: BackgroundService init failed: $e');
          }
        });
      }

      if (mounted) {
        setState(() => _initialized = true);

        // Remove splash screen now that Flutter UI is ready to take over.
        // This ensures the black screen issue is resolved for all routes (Welcome, AuthGate, etc.)
        FlutterNativeSplash.remove();

        _checkInitialLock();
        _startHeartbeat();
        _setupNotifications(firebaseReady);
      }
    } catch (e) {
      debugPrint('MAIN: FATAL STARTUP ERROR: $e');
      if (mounted) setState(() => _initError = e.toString());
    } finally {
      FlutterNativeSplash.remove();
    }
  }

  /// Sets up notification services and tap handlers.
  void _setupNotifications(bool firebaseAvailable) {
    debugPrint(
      'MAIN: _setupNotifications called, firebaseAvailable=$firebaseAvailable',
    );

    // Always initialize NotificationService, even if Firebase is not available
    // Background service will handle notifications via Realtime fallback
    NotificationService.instance
        .initialize(activeChatIdGetter: () => ref.read(activeChatIdProvider))
        .catchError((e) {
      debugPrint('Failed to initialize NotificationService: $e');
    });

    NotificationActionHandler.instance.handleFcmTap(
      onNavigate: (chatId, otherUid) {
        debugPrint('NOTIF: Navigating to chat $chatId with $otherUid');
        final router = ref.read(appRouterProvider);
        router.push('${AppRoutes.chat}/$chatId/$otherUid');
      },
    );
  }

  /// Starts a periodic heartbeat to update the user's online status.
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _updateOnlineStatus(true);
    _heartbeatTimer = dart_async.Timer.periodic(const Duration(minutes: 2), (
      _,
    ) {
      _updateOnlineStatus(true);
    });
  }

  /// Stops the online status heartbeat.
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Updates the user's online status in the backend.
  void _updateOnlineStatus(bool isOnline) {
    final uid = ref.read(authRepositoryProvider).currentUser?.id;
    if (uid != null) {
      ref.read(authRepositoryProvider).updateOnlineStatus(uid, isOnline);
    }
  }

  /// Checks if screen lock is enabled and locks the app if necessary.
  Future<void> _checkInitialLock() async {
    final enabled = await PrivacyService.instance.isScreenLockEnabled();
    if (enabled) {
      setState(() => _isLocked = true);
      _authenticate();
    }
  }

  /// Triggers biometric or system authentication to unlock the app.
  Future<void> _authenticate() async {
    final success = await PrivacyService.instance.authenticate(
      reason: 'Unlock XPARQ',
    );
    if (success) {
      if (mounted) setState(() => _isLocked = false);
    }
  }

  @override
  void dispose() {
    _stopHeartbeat();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final service = FlutterBackgroundService();
    final persistence = ref.read(navigationPersistenceProvider);

    if (state == AppLifecycleState.resumed) {
      debugPrint('APP: Resumed. Reconnecting Supabase Realtime...');
      try {
        // ignore: invalid_use_of_internal_member
        Supabase.instance.client.realtime.connect();
      } catch (e) {
        debugPrint('Failed to connect realtime: $e');
      }
      if (!kIsWeb) {
        service.invoke('setAsForeground');
      }
      persistence.setSessionActive(true);
      _checkInitialLock();
      _startHeartbeat();
    } else if (state == AppLifecycleState.paused) {
      if (!kIsWeb) {
        service.invoke('setAsBackground');
      }
      persistence.setSessionActive(true);
      _lockOnPause();
      _stopHeartbeat();
      _updateOnlineStatus(false);
    } else if (state == AppLifecycleState.detached) {
      persistence.setSessionActive(false);
      _stopHeartbeat();
      _updateOnlineStatus(false);
    }
  }

  /// Locks the app when it is paused if screen lock is enabled.
  Future<void> _lockOnPause() async {
    final enabled = await PrivacyService.instance.isScreenLockEnabled();
    if (enabled) {
      if (mounted) setState(() => _isLocked = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF070A0F),
        ),
        home: Scaffold(
          body: GalacticBackground(
            child: Center(
              child: _initError != null
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Startup Error: $_initError',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70),
                          ),
                          TextButton(
                            onPressed: _performStartup,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : const CircularProgressIndicator(color: Color(0xFF4FC3F7)),
            ),
          ),
        ),
      );
    }

    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'XPARQ',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();

        final overlay = _isLocked
            ? Container(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF070A0F)
                    : Colors.white,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.lock_outline,
                        size: 64,
                        color: Color(0xFF4FC3F7),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'XPARQ is Locked',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: _authenticate,
                        icon: const Icon(Icons.fingerprint),
                        label: const Text('Unlock'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4FC3F7),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : const SizedBox.shrink();

        return GalacticBackground(
          child: Stack(
            children: [
              RepaintBoundary(
                child: child,
              ),
              if (_isLocked) Positioned.fill(child: overlay),
            ],
          ),
        );
      },

      // ── Light Mode: White ──────────────────────────────────────────────
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF1D9BF0),
          secondary: Color(0xFF0D1B2A),
          surface: Colors.white,
          onSurface: Color(0xFF0D1B2A),
          onPrimary: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Color(0xFF0D1B2A),
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          titleTextStyle: TextStyle(
            color: Color(0xFF0D1B2A),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          iconTheme: IconThemeData(color: Color(0xFF0D1B2A)),
        ),
        textTheme: GoogleFonts.outfitTextTheme().copyWith(
          displayLarge: GoogleFonts.kanit(
            textStyle: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0D1B2A),
            ),
          ),
        ),
        cardColor: const Color(0xFFFAFAFA),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Color(0xFF1D9BF0),
          unselectedItemColor: Color(0xFF8B98A5),
          elevation: 0,
        ),
      ),

      // ── Dark Mode: Deep Space ──────────────────────────────────────────
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF070A0F),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF4FC3F7),
          secondary: Color(0xFF7C4DFF),
          surface: Color(0xFF070A0F),
          onSurface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        textTheme: GoogleFonts.outfitTextTheme().copyWith(
          displayLarge: GoogleFonts.kanit(
            textStyle: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        cardColor: const Color(0xFF0D1218),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF070A0F),
          selectedItemColor: Color(0xFF4FC3F7),
          unselectedItemColor: Colors.white60,
          elevation: 0,
        ),
      ),
    );
  }
}
