import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xparq_app/features/auth/providers/auth_providers.dart';
import 'package:xparq_app/features/call/data/services/call_signaling_service.dart';
import 'package:xparq_app/features/call/data/services/call_socket_service.dart';
import 'package:xparq_app/shared/config/supabase_config.dart';
import 'package:xparq_app/shared/constants/app_constants.dart';
import 'package:xparq_app/shared/widgets/ui/cards/glass_card.dart';

class CallDiagnosticsScreen extends ConsumerStatefulWidget {
  const CallDiagnosticsScreen({super.key});

  @override
  ConsumerState<CallDiagnosticsScreen> createState() =>
      _CallDiagnosticsScreenState();
}

class _CallDiagnosticsScreenState extends ConsumerState<CallDiagnosticsScreen> {
  final _httpClient = http.Client();
  final _callIdController = TextEditingController(text: 'diag-call');
  final _roomIdController = TextEditingController(text: 'diag-room');
  final _calleeIdController = TextEditingController();

  bool _isRunningChecks = false;
  bool _isSendingInvite = false;
  List<_DiagnosticResult> _results = const [];
  String? _inviteResult;

  @override
  void dispose() {
    _httpClient.close();
    _callIdController.dispose();
    _roomIdController.dispose();
    _calleeIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final textColor = theme.colorScheme.onSurface;
    final subtitleColor = textColor.withValues(alpha: 0.64);
    final fieldFill =
        isLight ? const Color(0xFFF5F8FD) : const Color(0xFF101723);
    final fieldBorder =
        isLight ? const Color(0xFFD6E0EE) : const Color(0xFF263548);
    final session = Supabase.instance.client.auth.currentSession;
    final user = session?.user;
    final profile = ref.watch(planetProfileProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Call Diagnostics'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              isLight ? const Color(0xFFF8FBFF) : const Color(0xFF07101C),
              theme.scaffoldBackgroundColor,
            ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _SectionCard(
              title: 'Environment',
              subtitle:
                  'Inspect the live backend and current signed-in session.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(
                    label: 'Supabase',
                    value: SupabaseConfig.url,
                  ),
                  _InfoRow(
                    label: 'Platform API',
                    value: AppConstants.platformApiBaseUrl,
                  ),
                  _InfoRow(
                    label: 'Session',
                    value: session == null ? 'Not signed in' : 'Signed in',
                    emphasis: session != null,
                  ),
                  if (user != null) ...[
                    _InfoRow(
                      label: 'Email',
                      value: user.email ?? 'No email',
                    ),
                    _InfoRow(
                      label: 'User ID',
                      value: user.id,
                      onCopy: () => _copyToClipboard(context, user.id),
                    ),
                  ],
                  if (profile != null)
                    _InfoRow(
                      label: 'Profile',
                      value: profile.xparqName,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Connectivity Checks',
              subtitle:
                  'Verify Supabase REST, platform API, ICE endpoint, and voice socket from this device.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _callIdController,
                    decoration: InputDecoration(
                      labelText: 'Diagnostic Call ID',
                      filled: true,
                      fillColor: fieldFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: fieldBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: fieldBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _roomIdController,
                    decoration: InputDecoration(
                      labelText: 'Diagnostic Room ID',
                      filled: true,
                      fillColor: fieldFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: fieldBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: fieldBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isRunningChecks ? null : _runChecks,
                      icon: _isRunningChecks
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.health_and_safety_outlined),
                      label: Text(
                        _isRunningChecks ? 'Running Checks...' : 'Run Checks',
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_results.isEmpty)
                    Text(
                      'No diagnostics run yet.',
                      style: TextStyle(color: subtitleColor),
                    )
                  else
                    ..._results.map(_buildResultTile),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Real Invite',
              subtitle:
                  'Send a real invite event through the production signaling API. Use carefully.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _calleeIdController,
                    decoration: InputDecoration(
                      labelText: 'Target Callee User ID',
                      helperText:
                          'This will send a real invite to the target user.',
                      filled: true,
                      fillColor: fieldFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: fieldBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: fieldBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isSendingInvite ? null : _sendRealInvite,
                      icon: _isSendingInvite
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.phone_forwarded_outlined),
                      label: Text(
                        _isSendingInvite
                            ? 'Sending Invite...'
                            : 'Send Real Invite',
                      ),
                    ),
                  ),
                  if (_inviteResult != null) ...[
                    const SizedBox(height: 12),
                    SelectableText(
                      _inviteResult!,
                      style: TextStyle(color: subtitleColor, height: 1.4),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultTile(_DiagnosticResult result) {
    final theme = Theme.of(context);
    final colors = _ResultColors.resolve(theme, result.severity);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                switch (result.severity) {
                  _DiagnosticSeverity.success => Icons.check_circle_rounded,
                  _DiagnosticSeverity.warning => Icons.info_rounded,
                  _DiagnosticSeverity.error => Icons.cancel_rounded,
                },
                color: colors.accent,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  result.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: colors.title,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.badgeBackground,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${result.statusCode ?? '--'}',
                  style: TextStyle(
                    color: colors.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            result.message,
            style: TextStyle(
              color: colors.body,
              height: 1.35,
            ),
          ),
          if (result.detail != null && result.detail!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            SelectableText(
              result.detail!,
              style: TextStyle(
                color: colors.detail,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _runChecks() async {
    if (_isRunningChecks) {
      return;
    }

    setState(() {
      _isRunningChecks = true;
      _results = const [];
    });

    final results = <_DiagnosticResult>[];
    final session = Supabase.instance.client.auth.currentSession;
    final user = session?.user;
    final accessToken = session?.accessToken;
    final callId = _callIdController.text.trim();
    final roomId = _roomIdController.text.trim();

    results.add(
      _DiagnosticResult(
        title: 'Session',
        severity: session != null
            ? _DiagnosticSeverity.success
            : _DiagnosticSeverity.warning,
        message: session != null
            ? 'Signed in as ${user?.email ?? user?.id ?? 'unknown user'}.'
            : 'No active Supabase session on this device.',
      ),
    );

    results.add(await _runPublicOptionsCheck());
    results.add(await _runSocketPollingProbe());
    results.add(await _runSupabaseAuthSettingsProbe());

    if (accessToken != null && user != null) {
      results.add(await _runSupabaseProfilesCheck(accessToken, user.id));
      results.add(await _runSupabaseMessagesCheck(accessToken));
      results.add(await _runPlatformProfileCheck(accessToken));
      results.add(await _runIceServersCheck(accessToken, callId, roomId));
      results.add(await _runVoiceSocketConnectCheck(accessToken));
    } else {
      results.add(
        const _DiagnosticResult(
          title: 'Authenticated Checks',
          severity: _DiagnosticSeverity.warning,
          message: 'Skipped because the device is not signed in.',
        ),
      );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _results = results;
      _isRunningChecks = false;
    });
  }

  Future<void> _sendRealInvite() async {
    if (_isSendingInvite) {
      return;
    }

    final session = Supabase.instance.client.auth.currentSession;
    final currentUserId = session?.user.id;
    final calleeId = _calleeIdController.text.trim();

    if (session == null || currentUserId == null) {
      setState(() {
        _inviteResult =
            'Cannot send invite: no signed-in session on this device.';
      });
      return;
    }

    if (calleeId.isEmpty) {
      setState(() {
        _inviteResult = 'Enter a callee user ID before sending a real invite.';
      });
      return;
    }

    setState(() {
      _isSendingInvite = true;
      _inviteResult = null;
    });

    try {
      final response = await CallSignalingService(client: _httpClient).invite(
        callerId: currentUserId,
        calleeId: calleeId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _inviteResult = const JsonEncoder.withIndent('  ').convert(response);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _inviteResult = 'Invite failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSendingInvite = false;
        });
      }
    }
  }

  Future<_DiagnosticResult> _runPublicOptionsCheck() async {
    try {
      final streamedResponse = await _httpClient.send(
        http.Request(
          'OPTIONS',
          Uri.parse('${AppConstants.platformApiBaseUrl}/events/call_invite'),
        ),
      );

      return _DiagnosticResult(
        title: 'Platform API OPTIONS',
        severity: streamedResponse.statusCode >= 200 &&
                streamedResponse.statusCode < 300
            ? _DiagnosticSeverity.success
            : _DiagnosticSeverity.error,
        statusCode: streamedResponse.statusCode,
        message: 'OPTIONS /events/call_invite responded from the live API.',
      );
    } catch (error) {
      return _DiagnosticResult(
        title: 'Platform API OPTIONS',
        severity: _DiagnosticSeverity.error,
        message: 'OPTIONS /events/call_invite failed.',
        detail: error.toString(),
      );
    }
  }

  Future<_DiagnosticResult> _runSocketPollingProbe() async {
    try {
      final response = await _httpClient.get(
        Uri.parse(
            'https://api.xparq.me/socket.io/?EIO=4&transport=polling&t=diag'),
      );

      final success = response.statusCode == 200 || response.statusCode == 400;
      return _DiagnosticResult(
        title: 'Voice Socket Probe',
        severity:
            success ? _DiagnosticSeverity.success : _DiagnosticSeverity.error,
        statusCode: response.statusCode,
        message: success
            ? 'Socket endpoint is reachable. A 400 response is acceptable for an unauthenticated polling probe.'
            : 'Socket probe returned an unexpected status.',
        detail: _summarizeResponseBody(response.body),
      );
    } catch (error) {
      return _DiagnosticResult(
        title: 'Voice Socket Probe',
        severity: _DiagnosticSeverity.error,
        message: 'Socket probe failed.',
        detail: error.toString(),
      );
    }
  }

  Future<_DiagnosticResult> _runSupabaseAuthSettingsProbe() async {
    try {
      final response = await _httpClient.get(
        Uri.parse('${SupabaseConfig.url}/auth/v1/settings'),
        headers: {
          'apikey': SupabaseConfig.anonKey,
        },
      );

      return _DiagnosticResult(
        title: 'Supabase Auth Settings',
        severity: response.statusCode >= 200 && response.statusCode < 300
            ? _DiagnosticSeverity.success
            : _DiagnosticSeverity.error,
        statusCode: response.statusCode,
        message: 'Supabase auth settings endpoint responded successfully.',
        detail: _summarizeResponseBody(response.body),
      );
    } catch (error) {
      return _DiagnosticResult(
        title: 'Supabase Auth Settings',
        severity: _DiagnosticSeverity.error,
        message: 'Supabase auth settings probe failed.',
        detail: error.toString(),
      );
    }
  }

  Future<_DiagnosticResult> _runSupabaseProfilesCheck(
    String accessToken,
    String userId,
  ) async {
    try {
      final response = await _httpClient.get(
        Uri.parse(
          '${SupabaseConfig.url}/rest/v1/profiles?id=eq.${Uri.encodeComponent(userId)}&select=id,xparq_name,photo_url,account_status',
        ),
        headers: _supabaseHeaders(accessToken),
      );

      return _DiagnosticResult(
        title: 'Supabase Profiles Row',
        severity: response.statusCode >= 200 && response.statusCode < 300
            ? _DiagnosticSeverity.success
            : _DiagnosticSeverity.error,
        statusCode: response.statusCode,
        message: 'Fetched the current user profile row from Supabase REST.',
        detail: _summarizeResponseBody(response.body),
      );
    } catch (error) {
      return _DiagnosticResult(
        title: 'Supabase Profiles Row',
        severity: _DiagnosticSeverity.error,
        message: 'Profiles REST query failed.',
        detail: error.toString(),
      );
    }
  }

  Future<_DiagnosticResult> _runSupabaseMessagesCheck(
      String accessToken) async {
    try {
      final response = await _httpClient.get(
        Uri.parse(
          '${SupabaseConfig.url}/rest/v1/messages?select=id,timestamp&order=timestamp.desc&limit=1',
        ),
        headers: _supabaseHeaders(accessToken),
      );

      return _DiagnosticResult(
        title: 'Supabase Messages Sample',
        severity: response.statusCode >= 200 && response.statusCode < 300
            ? _DiagnosticSeverity.success
            : _DiagnosticSeverity.error,
        statusCode: response.statusCode,
        message: 'Fetched a sample row from messages via Supabase REST.',
        detail: _summarizeResponseBody(response.body),
      );
    } catch (error) {
      return _DiagnosticResult(
        title: 'Supabase Messages Sample',
        severity: _DiagnosticSeverity.error,
        message: 'Messages REST query failed.',
        detail: error.toString(),
      );
    }
  }

  Future<_DiagnosticResult> _runPlatformProfileCheck(String accessToken) async {
    try {
      final response = await _httpClient.get(
        Uri.parse('${AppConstants.platformApiBaseUrl}/profiles/me'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      final summary = _summarizeResponseBody(response.body);
      final exists = response.statusCode >= 200 && response.statusCode < 300;
      final routeMissing = response.statusCode == 404 &&
          summary.toLowerCase().contains('cannot get /api/v1/profiles/me');

      return _DiagnosticResult(
        title: 'Platform /profiles/me',
        severity: exists
            ? _DiagnosticSeverity.success
            : routeMissing
                ? _DiagnosticSeverity.warning
                : _DiagnosticSeverity.error,
        statusCode: response.statusCode,
        message: exists
            ? 'Fetched the current user profile from the central backend.'
            : routeMissing
                ? 'The central backend does not expose /profiles/me on this environment. The app may still rely on Supabase or another fallback path.'
                : 'Central backend profile request failed.',
        detail: summary,
      );
    } catch (error) {
      return _DiagnosticResult(
        title: 'Platform /profiles/me',
        severity: _DiagnosticSeverity.error,
        message: 'Central backend profile request failed.',
        detail: error.toString(),
      );
    }
  }

  Future<_DiagnosticResult> _runIceServersCheck(
    String accessToken,
    String callId,
    String roomId,
  ) async {
    try {
      final response = await _httpClient.get(
        Uri.parse('${AppConstants.platformApiBaseUrl}/ice-servers').replace(
          queryParameters: {
            'callId': callId,
            'roomId': roomId,
            'transportPolicy': 'all',
          },
        ),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      return _DiagnosticResult(
        title: 'Platform /ice-servers',
        severity: response.statusCode >= 200 && response.statusCode < 300
            ? _DiagnosticSeverity.success
            : _DiagnosticSeverity.error,
        statusCode: response.statusCode,
        message: 'Requested ICE server policy from the production backend.',
        detail: _summarizeResponseBody(response.body),
      );
    } catch (error) {
      return _DiagnosticResult(
        title: 'Platform /ice-servers',
        severity: _DiagnosticSeverity.error,
        message: 'ICE server request failed.',
        detail: error.toString(),
      );
    }
  }

  Future<_DiagnosticResult> _runVoiceSocketConnectCheck(
      String accessToken) async {
    final socketService = CallSocketService();

    try {
      await socketService.connect(accessToken: accessToken);
      return _DiagnosticResult(
        title: 'Voice Socket Connect',
        severity: _DiagnosticSeverity.success,
        message: 'Connected to the production voice socket.',
        detail: socketService.currentEndpoint,
      );
    } catch (error) {
      return _DiagnosticResult(
        title: 'Voice Socket Connect',
        severity: _DiagnosticSeverity.error,
        message: 'Voice socket connection failed.',
        detail: error.toString(),
      );
    } finally {
      socketService.disconnect();
    }
  }

  Map<String, String> _supabaseHeaders(String accessToken) {
    return {
      'apikey': SupabaseConfig.anonKey,
      'Authorization': 'Bearer $accessToken',
      'Accept': 'application/json',
    };
  }

  String _truncate(String body, {int maxLength = 360}) {
    final normalized = body.trim();
    if (normalized.isEmpty) {
      return '<empty body>';
    }

    if (normalized.length <= maxLength) {
      return normalized;
    }

    return '${normalized.substring(0, maxLength)}...';
  }

  String _summarizeResponseBody(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return '<empty body>';
    }

    final lower = trimmed.toLowerCase();
    if (lower.startsWith('<!doctype html') || lower.startsWith('<html')) {
      final preMatch =
          RegExp(r'<pre>(.*?)</pre>', caseSensitive: false, dotAll: true)
              .firstMatch(trimmed);
      if (preMatch != null) {
        final preText =
            preMatch.group(1)?.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (preText != null && preText.isNotEmpty) {
          return preText;
        }
      }

      return 'HTML error page returned by server';
    }

    return _truncate(trimmed, maxLength: 180);
  }

  Future<void> _copyToClipboard(BuildContext context, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassCard(
      blur: 20,
      opacity: isDark ? 0.10 : 0.82,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.64),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.emphasis = false,
    this.onCopy,
  });

  final String label;
  final String value;
  final bool emphasis;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.52),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                fontWeight: emphasis ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          if (onCopy != null)
            IconButton(
              onPressed: onCopy,
              icon: const Icon(Icons.copy_rounded, size: 18),
              visualDensity: VisualDensity.compact,
              tooltip: 'Copy',
            ),
        ],
      ),
    );
  }
}

class _DiagnosticResult {
  const _DiagnosticResult({
    required this.title,
    required this.severity,
    required this.message,
    this.statusCode,
    this.detail,
  });

  final String title;
  final _DiagnosticSeverity severity;
  final String message;
  final int? statusCode;
  final String? detail;
}

enum _DiagnosticSeverity {
  success,
  warning,
  error,
}

class _ResultColors {
  const _ResultColors({
    required this.background,
    required this.border,
    required this.accent,
    required this.badgeBackground,
    required this.title,
    required this.body,
    required this.detail,
  });

  final Color background;
  final Color border;
  final Color accent;
  final Color badgeBackground;
  final Color title;
  final Color body;
  final Color detail;

  static _ResultColors resolve(ThemeData theme, _DiagnosticSeverity severity) {
    final isLight = theme.brightness == Brightness.light;

    switch (severity) {
      case _DiagnosticSeverity.success:
        return _ResultColors(
          background:
              isLight ? const Color(0xFFF4FBF8) : const Color(0xFF10211C),
          border: isLight ? const Color(0xFFB9E3D0) : const Color(0xFF1E5A46),
          accent: isLight ? const Color(0xFF12805C) : const Color(0xFF5BE0AF),
          badgeBackground:
              isLight ? const Color(0x1F12805C) : const Color(0x225BE0AF),
          title: isLight ? const Color(0xFF10251E) : const Color(0xFFE7FFF4),
          body: isLight ? const Color(0xFF1D4035) : const Color(0xFFD6F3E8),
          detail: isLight ? const Color(0xFF506E65) : const Color(0xFFA6D2C4),
        );
      case _DiagnosticSeverity.warning:
        return _ResultColors(
          background:
              isLight ? const Color(0xFFFFFAF1) : const Color(0xFF241B0F),
          border: isLight ? const Color(0xFFF2D38B) : const Color(0xFF7B5920),
          accent: isLight ? const Color(0xFFAE6D00) : const Color(0xFFFFC85A),
          badgeBackground:
              isLight ? const Color(0x1FAE6D00) : const Color(0x22FFC85A),
          title: isLight ? const Color(0xFF2F220C) : const Color(0xFFFFF3D4),
          body: isLight ? const Color(0xFF5D4717) : const Color(0xFFF6E1A8),
          detail: isLight ? const Color(0xFF7E6840) : const Color(0xFFD9C089),
        );
      case _DiagnosticSeverity.error:
        return _ResultColors(
          background:
              isLight ? const Color(0xFFFFF3F4) : const Color(0xFF2B1419),
          border: isLight ? const Color(0xFFF0BAC0) : const Color(0xFF8D3241),
          accent: isLight ? const Color(0xFFC43E55) : const Color(0xFFFF8EA1),
          badgeBackground:
              isLight ? const Color(0x1FC43E55) : const Color(0x26FF8EA1),
          title: isLight ? const Color(0xFF301218) : const Color(0xFFFFF2F4),
          body: isLight ? const Color(0xFF6B2B35) : const Color(0xFFF0CAD1),
          detail: isLight ? const Color(0xFF87515A) : const Color(0xFFD7A8B2),
        );
    }
  }
}
