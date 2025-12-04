import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

/// Plays the alert sound and triggers device vibration when a timer finishes.
class AlarmFeedbackService {
  AlarmFeedbackService._();

  static final AlarmFeedbackService instance = AlarmFeedbackService._();
  final AudioPlayer _player = AudioPlayer();

  /// Plays the bundled alert sound and vibrates the device (if supported).
  Future<void> playAlertAndVibrate() async {
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/alert.mp3'));
    } catch (e) {
      print("⚠️ Failed to play alert sound: $e");
    }

    try {
      final hasVibrator = await Vibration.hasVibrator() ?? false;
      if (!hasVibrator) return;

      final hasCustom = await Vibration.hasCustomVibrationsSupport() ?? false;
      if (hasCustom) {
        await Vibration.vibrate(pattern: [0, 400, 150, 600]);
      } else {
        await Vibration.vibrate(duration: 800);
      }
    } catch (e) {
      print("⚠️ Failed to vibrate: $e");
    }
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
