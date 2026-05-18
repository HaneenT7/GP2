import 'package:flutter/material.dart';
import 'package:gp2_watad/services/health_connect_service.dart';
import 'package:gp2_watad/services/notification_service.dart';

/// Alerts when recent heart rate is at or above [thresholdBpm].
class HeartRateAlertService {
  HeartRateAlertService._();

  static const double thresholdBpm = 100;
  static const Duration cooldown = Duration(minutes: 15);
  static const Duration recentWindow = Duration(minutes: 20);

  static DateTime? _lastAlertAt;

  /// Set from [DashBoard] to switch to Brain Games (index 5).
  static VoidCallback? onGoToBrainGames;

  static Future<void> evaluateReadings(
    List<HeartRateReading> readings, {
    BuildContext? context,
  }) async {
    if (readings.isEmpty) return;

    final now = DateTime.now();
    final cutoff = now.subtract(recentWindow);
    final highReadings = readings
        .where((r) => r.bpm >= thresholdBpm && r.recordedAt.isAfter(cutoff))
        .toList();
    if (highReadings.isEmpty) return;

    highReadings.sort((a, b) => b.bpm.compareTo(a.bpm));
    final peak = highReadings.first;

    if (_lastAlertAt != null && now.difference(_lastAlertAt!) < cooldown) {
      return;
    }
    _lastAlertAt = now;

    final inForeground =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

    if (inForeground && context != null && context.mounted) {
      await _showInAppDialog(context, peak.bpm);
      return;
    }

    await NotificationService.showHeartRateAlert(bpm: peak.bpm);
  }

  static Future<void> _showInAppDialog(BuildContext context, double bpm) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.favorite, color: Color(0xFFE91E63), size: 36),
        title: const Text('High heart rate'),
        content: Text(
          'Your heart rate reached ${bpm.round()} bpm (100+). '
          "You've exerted yourself — take a break or try Brain Games to cool down.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Take a break'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              onGoToBrainGames?.call();
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF7C4DFF),
            ),
            child: const Text('Brain Games'),
          ),
        ],
      ),
    );
  }
}

/// Brain Games tab index in [DashBoard] sidebar / [IndexedStack].
const int kBrainGamesTabIndex = 5;
