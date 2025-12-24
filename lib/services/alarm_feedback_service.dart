
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

/// Plays the alert sound and triggers device vibration when a timer finishes.
class AlarmFeedbackService {
  AlarmFeedbackService._();

  static final AlarmFeedbackService instance = AlarmFeedbackService._();
  final AudioPlayer _player = AudioPlayer();
  bool _alerting = false;

  /// Plays the bundled alert sound and vibrates the device (if supported).
  Future<void> playAlertAndVibrate() async {
    await startAlertLoop();
  }

  /// Starts looping alert sound and vibration until stopped.
  Future<void> startAlertLoop() async {
    if (_alerting) return;
    _alerting = true;

    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.release);
      _runAudioLoop();
    } catch (e) {
      print("ƒsÿ‹,? Failed to play alert sound: $e");
    }

    try {
      final hasVibrator = await Vibration.hasVibrator() ?? false;
      if (!hasVibrator) return;

      final hasCustom = await Vibration.hasCustomVibrationsSupport() ?? false;
      if (hasCustom) {
        await Vibration.vibrate(
          pattern: [0, 350, 150, 350, 500],
          repeat: 0,
        );
      } else {
        await Vibration.vibrate(
          pattern: [0, 350, 150, 350, 500],
          repeat: 0,
        );
      }
    } catch (e) {
      print("ƒsÿ‹,? Failed to vibrate: $e");
    }
  }

  Future<void> _runAudioLoop() async {
    while (_alerting) {
      try {
        await _player.play(AssetSource('sounds/alert.mp3'));
        await _player.onPlayerComplete.first;
      } catch (e) {
        print("ƒsÿ‹,? Failed to play alert sound: $e");
      }
      if (!_alerting) break;
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<void> stopAlert() async {
    if (!_alerting) return;
    _alerting = false;
    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.release);
    } catch (e) {
      print("ƒsÿ‹,? Failed to stop alert sound: $e");
    }
    try {
      await Vibration.cancel();
    } catch (e) {
      print("ƒsÿ‹,? Failed to cancel vibration: $e");
    }
  }

  Future<void> dispose() async {
    await stopAlert();
    await _player.dispose();
  }
}
