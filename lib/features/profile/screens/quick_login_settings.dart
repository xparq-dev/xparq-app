// lib/features/profile/screens/quick_login_settings.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xparq_app/features/auth/providers/auth_providers.dart';
import 'package:xparq_app/features/auth/models/quick_account.dart';

class QuickLoginSettingsScreen extends ConsumerStatefulWidget {
  const QuickLoginSettingsScreen({super.key});

  @override
  ConsumerState<QuickLoginSettingsScreen> createState() =>
      _QuickLoginSettingsScreenState();
}

class _QuickLoginSettingsScreenState
    extends ConsumerState<QuickLoginSettingsScreen> {
  bool _isLoading = false;

  Future<void> _toggleQuickLogin(bool enabled) async {
    setState(() => _isLoading = true);
    try {
      final user = ref.read(supabaseAuthStateProvider).value;
      if (user == null) return;

      final quickAuth = await ref.read(quickAuthServiceProvider.future);

      if (enabled) {
        final profile = ref.read(planetProfileProvider).value;
        if (profile == null) throw Exception('Profile not loaded');

        await quickAuth.saveQuickAccount(
          QuickAccount(
            uid: user.id,
            email: user.email ?? '',
            xparqName: profile.xparqName,
            photoUrl: profile.photoUrl,
            lastUsed: DateTime.now(),
            isEnabled: true,
          ),
        );

        // Also save current session
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null && session.refreshToken != null) {
          await quickAuth.saveSession(
            user.id,
            accessToken: session.accessToken,
            refreshToken: session.refreshToken!,
          );
        }
      } else {
        await quickAuth.removeQuickAccount(user.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update Quick Login: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(supabaseAuthStateProvider).value;
    final quickAuthAsync = ref.watch(quickAuthServiceProvider);
    final accounts = ref.watch(quickAccountsProvider);
    final isEnabled = user != null && accounts.any((a) => a.uid == user.id);

    return Scaffold(
      appBar: AppBar(title: const Text('Quick Login Settings')),
      body: quickAuthAsync.when(
        data: (quickAuth) {
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Enable Quick Login to access your account faster on this device. When enabled, your profile will appear on the Welcome screen, allowing you to login by simply entering your account password.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 32),
              SwitchListTile(
                title: const Text(
                  'Quick Login',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  isEnabled ? 'Currently enabled for this device' : 'Disabled',
                  style: TextStyle(
                    color: isEnabled ? Colors.greenAccent : Colors.white54,
                  ),
                ),
                value: isEnabled,
                onChanged: _isLoading ? null : (val) => _toggleQuickLogin(val),
                activeThumbColor: Theme.of(context).colorScheme.primary,
              ),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
