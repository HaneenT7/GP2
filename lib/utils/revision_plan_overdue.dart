import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Helpers for "overdue" revision tasks: scheduled on a day before today and not completed.

List<dynamic> parseRevisionPlanDailyTasks(Map<String, dynamic> planData) {
  final raw = planData['dailyTasks'];
  if (raw is String) {
    try {
      return jsonDecode(raw) as List<dynamic>;
    } catch (_) {
      return [];
    }
  }
  if (raw is List) return List<dynamic>.from(raw);
  return [];
}

/// Same rule as active vs passed plans on [RevPlanPage]: exam is not in the future.
bool isRevisionPlanExamPassed(Map<String, dynamic> plan) {
  final raw = plan['examDate'] ?? plan['exam_date'] ?? plan['examDateIso'];
  if (raw == null) return false;
  final DateTime exam = raw is Timestamp
      ? raw.toDate()
      : DateTime.parse(raw.toString());
  return !exam.isAfter(DateTime.now());
}

/// Overdue count for one plan; returns 0 when the exam date has passed.
int countOverdueTasksForPlan(Map<String, dynamic> plan) {
  if (isRevisionPlanExamPassed(plan)) return 0;
  return countOverdueTasks(parseRevisionPlanDailyTasks(plan));
}

bool _sameCalendarDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

/// True if [dayDate] is strictly before today's calendar date and the task is not completed.
bool isRevisionTaskOverdue(DateTime dayDate, Map<dynamic, dynamic> task) {
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final d = DateTime(dayDate.year, dayDate.month, dayDate.day);
  if (!d.isBefore(todayStart)) return false;
  return task['completed'] != true;
}

/// Counts incomplete tasks on past days (relative to today).
int countOverdueTasks(List<dynamic> dailyTasks) {
  var n = 0;
  for (final day in dailyTasks) {
    if (day is! Map) continue;
    final dateStr = day['date'];
    if (dateStr == null) continue;
    final dayDate = DateTime.parse(dateStr as String);
    final tasks = day['tasks'] as List<dynamic>? ?? [];
    for (final t in tasks) {
      if (t is Map && isRevisionTaskOverdue(dayDate, t)) {
        n++;
      }
    }
  }
  return n;
}

/// Whether [weekDay] has at least one overdue incomplete task.
bool weekDayHasOverdueIncomplete(
  List<dynamic> dailyTasks,
  DateTime weekDay,
) {
  for (final day in dailyTasks) {
    if (day is! Map) continue;
    final dateStr = day['date'];
    if (dateStr == null) continue;
    final dayDate = DateTime.parse(dateStr as String);
    if (!_sameCalendarDay(dayDate, weekDay)) continue;
    final tasks = day['tasks'] as List<dynamic>? ?? [];
    for (final t in tasks) {
      if (t is Map && isRevisionTaskOverdue(dayDate, t)) {
        return true;
      }
    }
  }
  return false;
}

/// Overdue incomplete tasks as plain maps for n8n / reschedule API.
List<Map<String, dynamic>> collectOverdueTasksForReschedule(
  List<dynamic> dailyTasks,
) {
  final out = <Map<String, dynamic>>[];
  for (final day in dailyTasks) {
    if (day is! Map) continue;
    final dateStr = day['date'] as String?;
    if (dateStr == null) continue;
    final dayDate = DateTime.parse(dateStr);
    final tasks = day['tasks'] as List<dynamic>? ?? [];
    for (final t in tasks) {
      if (t is! Map) continue;
      if (!isRevisionTaskOverdue(dayDate, t)) continue;
      out.add({
        'taskId': t['taskId']?.toString() ?? '',
        'scheduledDate': dateStr,
        'title': t['title']?.toString() ?? '',
        'description': t['description']?.toString() ?? '',
        'estimatedMinutes': t['estimatedMinutes'] is num
            ? (t['estimatedMinutes'] as num).toInt()
            : int.tryParse('${t['estimatedMinutes']}') ?? 0,
        'type': t['type']?.toString() ?? 'study',
      });
    }
  }
  return out;
}
