import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_localizations.dart';
import '../services/alarm_feedback_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';

class CountdownScreen extends StatefulWidget {
  const CountdownScreen({super.key});

  @override
  State<CountdownScreen> createState() => _CountdownScreenState();
}

class _CountdownScreenState extends State<CountdownScreen> {
  final FixedExtentScrollController _hourController =
      FixedExtentScrollController();
  final FixedExtentScrollController _minuteController =
      FixedExtentScrollController();
  final FixedExtentScrollController _secondController =
      FixedExtentScrollController();

  Duration _remaining = const Duration();
  Timer? _timer;
  bool _isRunning = false;
  bool _isPaused = false;

  @override
  void dispose() {
    _timer?.cancel();
    _hourController.dispose();
    _minuteController.dispose();
    _secondController.dispose();
    super.dispose();
  }

  void _start() {
    _isPaused = false;
    final hours = _hourController.selectedItem;
    final minutes = _minuteController.selectedItem;
    final seconds = _secondController.selectedItem;
    final total = Duration(hours: hours, minutes: minutes, seconds: seconds);
    setState(() {
      _remaining = total;
    });
    if (_remaining.inSeconds <= 0) return;
    _timer?.cancel();
    setState(() {
      _isRunning = true;
    });
    _syncControllersFromRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remaining.inSeconds <= 1) {
        _finishCountdown();
      } else {
        setState(() {
          _remaining -= const Duration(seconds: 1);
        });
        _syncControllersFromRemaining();
      }
    });
  }

  void _pause() {
    _timer?.cancel();
    setState(() {
      _isPaused = true;
    });
  }

  void _resume() {
    if (_remaining.inSeconds <= 0) {
      _isRunning = false;
      _isPaused = false;
      setState(() {});
      return;
    }
    _timer?.cancel();
    setState(() {
      _isRunning = true;
      _isPaused = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remaining.inSeconds <= 1) {
        _finishCountdown();
      } else {
        setState(() {
          _remaining -= const Duration(seconds: 1);
        });
        _syncControllersFromRemaining();
      }
    });
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _isPaused = false;
      _remaining = const Duration();
    });
    _hourController.jumpToItem(0);
    _minuteController.jumpToItem(0);
    _secondController.jumpToItem(0);
  }

  String _format(Duration d) {
    final hours = d.inHours.remainder(100).toString().padLeft(2, '0');
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$hours:$minutes:$seconds";
  }

  void _syncControllersFromRemaining() {
    final h = _remaining.inHours.clamp(0, 23);
    final m = _remaining.inMinutes.remainder(60).clamp(0, 59);
    final s = _remaining.inSeconds.remainder(60).clamp(0, 59);
    _hourController.jumpToItem(h);
    _minuteController.jumpToItem(m);
    _secondController.jumpToItem(s);
  }

  void _finishCountdown() {
    if (!mounted) return;
    _timer?.cancel();
    setState(() {
      _remaining = Duration.zero;
      _isRunning = false;
      _isPaused = false;
    });
    _syncControllersFromRemaining();
    _notifyCountdownComplete();
  }

  void _notifyCountdownComplete() {
    if (!mounted) return;
    final strings = AppLocalizations.of(context)!;
    unawaited(AlarmFeedbackService.instance.playAlertAndVibrate());
    unawaited(
      NotificationService.instance.showTimerDoneNotification(
        title: strings.t('timer_done_title'),
        body: strings.t('timer_done_body'),
      ),
    );

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          strings.t('timer_done_title'),
          style: GoogleFonts.poppins(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          strings.t('timer_done_body'),
          style: GoogleFonts.poppins(
            color: AppColors.primary.withOpacity(0.8),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              strings.t('common_ok'),
              style: GoogleFonts.poppins(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        title: Text(
          strings.t('timer'),
          style: GoogleFonts.poppins(
            color: AppColors.primary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            if (!_isRunning)
              _WheelTimeDisplay(
                hourController: _hourController,
                minuteController: _minuteController,
                secondController: _secondController,
              )
            else
              Text(
                _format(_remaining),
                style: GoogleFonts.poppins(
                  color: AppColors.primary,
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _isRunning
                      ? ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: AppColors.primary,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _isPaused ? _resume : _pause,
                          child: Text(
                            _isPaused ? strings.t('resume') : strings.t('pause'),
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.background,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _start,
                          child: Text(
                            strings.t('start'),
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                ),
                if (_isRunning) const SizedBox(width: 12),
                if (_isRunning)
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        foregroundColor: AppColors.primary,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _reset,
                      child: Text(
                        strings.t('reset'),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (!_isRunning)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary),
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _reset,
                  child: Text(
                    strings.t('reset'),
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
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

class _WheelPicker extends StatelessWidget {
  final FixedExtentScrollController controller;
  final int max;

  const _WheelPicker({
    required this.controller,
    required this.max,
  });

  @override
  Widget build(BuildContext context) {
    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: 48,
      physics: const FixedExtentScrollPhysics(),
      childDelegate: ListWheelChildBuilderDelegate(
        builder: (context, index) {
          if (index < 0 || index >= max) return null;
          return Center(
            child: Text(
              index.toString().padLeft(2, '0'),
              style: GoogleFonts.poppins(
                fontSize: 36,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WheelTimeDisplay extends StatelessWidget {
  final FixedExtentScrollController hourController;
  final FixedExtentScrollController minuteController;
  final FixedExtentScrollController secondController;

  const _WheelTimeDisplay({
    required this.hourController,
    required this.minuteController,
    required this.secondController,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(child: _WheelPicker(controller: hourController, max: 24)),
          Text(
            ":",
            style: GoogleFonts.poppins(
              color: AppColors.primary,
              fontSize: 32,
              fontWeight: FontWeight.w700,
            ),
          ),
          Expanded(child: _WheelPicker(controller: minuteController, max: 60)),
          Text(
            ":",
            style: GoogleFonts.poppins(
              color: AppColors.primary,
              fontSize: 32,
              fontWeight: FontWeight.w700,
            ),
          ),
          Expanded(child: _WheelPicker(controller: secondController, max: 60)),
        ],
      ),
    );
  }
}
