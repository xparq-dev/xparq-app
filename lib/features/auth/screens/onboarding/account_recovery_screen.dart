import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/planet_model.dart';
import '../../providers/auth_providers.dart';

class AccountRecoveryScreen extends ConsumerStatefulWidget {
  final PlanetModel profile;

  const AccountRecoveryScreen({super.key, required this.profile});

  @override
  ConsumerState<AccountRecoveryScreen> createState() =>
      _AccountRecoveryScreenState();
}

class _AccountRecoveryScreenState extends ConsumerState<AccountRecoveryScreen> {
  final TextEditingController _otpController = TextEditingController();

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final notifier = ref.read(authNotifierProvider.notifier);
    final isOtpSent = authState.step == AuthStep.otpSent;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background - Cosmic/Dark
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.5),
                  radius: 1.5,
                  colors: [
                    Color(0xFF1D2951), // Dark Navy
                    Colors.black,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.history_rounded,
                    size: 80,
                    color: Color(0xFF1D9BF0),
                  ),
                  const SizedBox(height: 32),

                  Text(
                    'Recover Your Account?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    'Hello ${widget.profile.xparqName}.\nYour account is currently scheduled for deletion.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF71767B),
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B6B).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFFF6B6B).withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Text(
                      'You have a 30-day grace period to restore your data. After 30 days, all data will be permanently wiped.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFFFF6B6B), fontSize: 13),
                    ),
                  ),

                  const SizedBox(height: 48),

                  if (!isOtpSent) ...[
                    // Restore Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: authState.isLoading
                            ? null
                            : () => notifier.sendRecoveryOtp(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1D9BF0),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: authState.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Yes, Restore My Account',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Cancel Button
                    TextButton(
                      onPressed: authState.isLoading
                          ? null
                          : () => notifier.cancelRecovery(),
                      child: const Text(
                        'This isn\'t my account',
                        style: TextStyle(
                          color: Color(0xFF71767B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ] else ...[
                    // OTP Input
                    Text(
                      'Enter the OTP sent to your email',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        letterSpacing: 8,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        hintText: '000000',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: authState.isLoading
                            ? null
                            : () {
                                if (_otpController.text.length == 6) {
                                  notifier.restoreAccount();
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00BA7C),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: authState.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Verify & Restore',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => notifier.cancelRecovery(),
                      child: const Text(
                        'Back',
                        style: TextStyle(color: Color(0xFF71767B)),
                      ),
                    ),
                  ],

                  if (authState.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Text(
                        authState.errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red, fontSize: 14),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
