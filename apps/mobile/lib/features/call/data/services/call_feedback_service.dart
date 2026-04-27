import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter/foundation.dart';

class CallFeedbackService {
  final AudioPlayer _ringtonePlayer = AudioPlayer();
  final AudioPlayer _waitingTonePlayer = AudioPlayer();
  bool _isVibrating = false;

  static const String ringtoneAsset = 'assets/sounds/ringtone.wav';
  static const String waitingToneAsset = 'assets/sounds/waiting_tone.wav';

  CallFeedbackService() {
    _ringtonePlayer.setReleaseMode(ReleaseMode.loop);
    _waitingTonePlayer.setReleaseMode(ReleaseMode.loop);
    _waitingTonePlayer.setVolume(0.2); // 20% volume for waiting tone
  }

  Future<void> startRingtone() async {
    try {
      await stopAll();
      // Ringtone should be loud and on speaker
      await _ringtonePlayer.play(AssetSource('sounds/ringtone.wav'));
      _startVibration();
    } catch (e) {
      debugPrint('CALL: Failed to start ringtone: $e');
    }
  }

  Future<void> startWaitingTone() async {
    try {
      await stopAll();
      // Waiting tone should be on earpiece (receiver)
      await _waitingTonePlayer.setAudioContext(AudioContext(
        android: AudioContextAndroid(
          usageType: AndroidUsageType.voiceCommunication,
          contentType: AndroidContentType.speech,
          audioFocus: AndroidAudioFocus.gainTransient,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playAndRecord,
          options: {
            AVAudioSessionOptions.allowBluetooth,
          },
        ),
      ));
      await _waitingTonePlayer.play(AssetSource('sounds/waiting_tone.wav'));
    } catch (e) {
      debugPrint('CALL: Failed to start waiting tone: $e');
    }
  }

  Future<void> stopAll() async {
    try {
      await _ringtonePlayer.stop();
      await _waitingTonePlayer.stop();
      _stopVibration();
    } catch (e) {
      debugPrint('CALL: Failed to stop feedback: $e');
    }
  }

  void _startVibration() async {
    if (_isVibrating) return;
    final hasVibrator = await Vibration.hasVibrator() ?? false;
    if (hasVibrator) {
      _isVibrating = true;
      Vibration.vibrate(
        pattern: [500, 1000, 500, 1000],
        repeat: 0, // Loop until stop
      );
    }
  }

  void _stopVibration() {
    Vibration.cancel();
    _isVibrating = false;
  }

  void dispose() {
    _ringtonePlayer.dispose();
    _waitingTonePlayer.dispose();
  }
}
