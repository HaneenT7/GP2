import 'package:flutter/material.dart';

/// Shared colors for revision task cards (normal / overdue / rescheduled).
class RevisionTaskCardStyle {
  RevisionTaskCardStyle._();

  static const Color completedBackground = Color(0xFFE6F7E9);
  static const Color completedCheck = Color(0xFF52C41A);

  static const Color rescheduledBackground = Color(0xFFE3F2FD);
  static const Color rescheduledBorder = Color(0xFF42A5F5);
  static const Color rescheduledTitle = Color(0xFF1565C0);
  static const Color rescheduledBadgeBackground = Color(0xFFBBDEFB);

  static const Color overdueBackground = Color(0xFFFFF3E0);

  static Color background({
    required bool isCompleted,
    required bool isOverdue,
    required bool isRescheduled,
  }) {
    if (isCompleted) return completedBackground;
    if (isOverdue) return overdueBackground;
    if (isRescheduled) return rescheduledBackground;
    return Colors.white;
  }

  static Color border({
    required bool isCompleted,
    required bool isOverdue,
    required bool isRescheduled,
  }) {
    if (isCompleted) return Colors.transparent;
    if (isOverdue) return Colors.deepOrange.shade300;
    if (isRescheduled) return rescheduledBorder;
    return const Color(0xFFE8E8E8);
  }

  static double borderWidth({
    required bool isCompleted,
    required bool isOverdue,
    required bool isRescheduled,
  }) {
    if (isCompleted) return 1;
    if (isOverdue || isRescheduled) return 2;
    return 1;
  }

  static Color title({
    required bool isCompleted,
    required bool isOverdue,
    required bool isRescheduled,
  }) {
    if (isCompleted) return Colors.grey;
    if (isOverdue) return Colors.deepOrange.shade900;
    if (isRescheduled) return rescheduledTitle;
    return Colors.black87;
  }

  static Color? iconAccent({
    required bool isOverdue,
    required bool isRescheduled,
  }) {
    if (isOverdue) return Colors.deepOrange;
    if (isRescheduled) return rescheduledBorder;
    return null;
  }
}
