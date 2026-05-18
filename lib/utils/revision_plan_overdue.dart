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

bool sameRevisionCalendarDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

bool _sameCalendarDay(DateTime a, DateTime b) => sameRevisionCalendarDay(a, b);

/// Exam date from a revision plan document (date-only).
DateTime? revisionPlanExamDate(Map<String, dynamic> plan) {
  final raw = plan['examDate'] ?? plan['exam_date'] ?? plan['examDateIso'];
  if (raw == null) return null;
  final DateTime parsed = raw is Timestamp
      ? raw.toDate()
      : DateTime.parse(raw.toString());
  return DateTime(parsed.year, parsed.month, parsed.day);
}

/// Whether [day] is the plan's exam calendar day.
bool isRevisionPlanExamDay(DateTime day, Map<String, dynamic> plan) {
  final exam = revisionPlanExamDate(plan);
  if (exam == null) return false;
  final d = DateTime(day.year, day.month, day.day);
  return sameRevisionCalendarDay(d, exam);
}

/// True if [dayDate] is strictly before today's calendar date and the task is not completed.
bool isRevisionTaskOverdue(DateTime dayDate, Map<dynamic, dynamic> task) {
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final d = DateTime(dayDate.year, dayDate.month, dayDate.day);
  if (!d.isBefore(todayStart)) return false;
  return task['completed'] != true;
}

/// First day (chronological) with a task where [rescheduled] is true.
DateTime? firstRevisionPlanRescheduledDay(List<dynamic> dailyTasks) {
  DateTime? first;
  for (final day in dailyTasks) {
    if (day is! Map) continue;
    final dateStr = day['date']?.toString();
    if (dateStr == null) continue;
    final dayDate = DateTime.tryParse(dateStr);
    if (dayDate == null) continue;
    final tasks = day['tasks'] as List<dynamic>? ?? [];
    final hasRescheduled = tasks.any(
      (t) => t is Map && t['rescheduled'] == true,
    );
    if (!hasRescheduled) continue;
    final d = DateTime(dayDate.year, dayDate.month, dayDate.day);
    if (first == null || d.isBefore(first)) first = d;
  }
  return first;
}

/// Earliest calendar day (date-only) that has at least one overdue incomplete task.
DateTime? firstRevisionPlanOverdueDay(List<dynamic> dailyTasks) {
  DateTime? first;
  for (final day in dailyTasks) {
    if (day is! Map) continue;
    final dateStr = day['date']?.toString();
    if (dateStr == null) continue;
    final dayDate = DateTime.tryParse(dateStr);
    if (dayDate == null) continue;
    final tasks = day['tasks'] as List<dynamic>? ?? [];
    final hasOverdue = tasks.any(
      (t) => t is Map && isRevisionTaskOverdue(dayDate, t),
    );
    if (!hasOverdue) continue;
    final d = DateTime(dayDate.year, dayDate.month, dayDate.day);
    if (first == null || d.isBefore(first)) first = d;
  }
  return first;
}

String _overdueDedupeKey(DateTime dayDate, Map<dynamic, dynamic> task) {
  final id = revisionTaskId(task);
  if (id.isNotEmpty) return 'id:$id';
  final title = task['title']?.toString() ?? '';
  return 't:$title@${revisionDayDateKey(dayDate)}';
}

/// All tasks scheduled on [dateKey], merged across duplicate day entries.
List<Map<dynamic, dynamic>> revisionPlanTasksOnDate(
  List<dynamic> dailyTasks,
  String dateKey,
) {
  final merged = <Map<dynamic, dynamic>>[];
  final seen = <String>{};
  for (final day in dailyTasks) {
    if (day is! Map) continue;
    if (revisionDayDateKey(day['date']) != dateKey) continue;
    for (final t in day['tasks'] as List<dynamic>? ?? []) {
      if (t is! Map) continue;
      final map = t;
      final dayDate = DateTime.tryParse(dateKey) ?? DateTime.now();
      final key = _overdueDedupeKey(dayDate, map);
      if (seen.contains(key)) continue;
      seen.add(key);
      merged.add(map);
    }
  }
  return merged;
}

/// First day object for [dateKey] (metadata) with merged unique tasks.
Map<String, dynamic>? revisionPlanDayBucketForDate(
  List<dynamic> dailyTasks,
  String dateKey,
) {
  final tasks = revisionPlanTasksOnDate(dailyTasks, dateKey);
  if (tasks.isEmpty) return null;

  Map<String, dynamic>? shell;
  for (final day in dailyTasks) {
    if (day is! Map) continue;
    if (revisionDayDateKey(day['date']) != dateKey) continue;
    shell ??= Map<String, dynamic>.from(day);
  }
  shell ??= <String, dynamic>{'date': dateKey};
  shell['tasks'] = tasks;
  return shell;
}

/// Overdue incomplete tasks on one calendar date (deduped).
int countOverdueTasksOnDate(List<dynamic> dailyTasks, DateTime dayDate) {
  final dateKey = revisionDayDateKey(dayDate);
  final seen = <String>{};
  var n = 0;
  for (final t in revisionPlanTasksOnDate(dailyTasks, dateKey)) {
    if (!isRevisionTaskOverdue(dayDate, t)) continue;
    final key = _overdueDedupeKey(dayDate, t);
    if (seen.contains(key)) continue;
    seen.add(key);
    n++;
  }
  return n;
}

/// Counts incomplete tasks on past days (relative to today), deduped globally.
int countOverdueTasks(List<dynamic> dailyTasks) {
  final seen = <String>{};
  var n = 0;
  final dateKeys = <String>{};
  for (final day in dailyTasks) {
    if (day is! Map) continue;
    final dk = revisionDayDateKey(day['date']);
    if (dk.isNotEmpty) dateKeys.add(dk);
  }
  for (final dateKey in dateKeys) {
    final dayDate = DateTime.tryParse(dateKey);
    if (dayDate == null) continue;
    for (final t in revisionPlanTasksOnDate(dailyTasks, dateKey)) {
      if (!isRevisionTaskOverdue(dayDate, t)) continue;
      final key = _overdueDedupeKey(dayDate, t);
      if (seen.contains(key)) continue;
      seen.add(key);
      n++;
    }
  }
  return n;
}

/// Whether [weekDay] has at least one overdue incomplete task.
bool weekDayHasOverdueIncomplete(
  List<dynamic> dailyTasks,
  DateTime weekDay,
) {
  return countOverdueTasksOnDate(dailyTasks, weekDay) > 0;
}

/// Stable task id from Firestore / n8n (`taskId` preferred, `id` fallback).
String revisionTaskId(Map<dynamic, dynamic> task) {
  final id = task['taskId']?.toString() ?? task['id']?.toString() ?? '';
  return id.trim();
}

Map<String, dynamic> normalizeRevisionTaskMap(Map<dynamic, dynamic> task) {
  final m = Map<String, dynamic>.from(task);
  final id = revisionTaskId(task);
  if (id.isNotEmpty) {
    m['taskId'] = id;
    m.remove('id');
  }
  return m;
}

String revisionDayDateKey(dynamic raw) {
  if (raw == null) return '';
  final s = raw.toString().trim();
  if (s.isEmpty) return '';
  if (s.contains('T')) return s.split('T').first;
  return s.length >= 10 ? s.substring(0, 10) : s;
}

/// All overdue incomplete task ids in [dailyTasks].
Set<String> collectOverdueTaskIds(List<dynamic> dailyTasks) {
  final ids = <String>{};
  for (final day in dailyTasks) {
    if (day is! Map) continue;
    final dateStr = day['date']?.toString();
    if (dateStr == null) continue;
    final dayDate = DateTime.tryParse(dateStr);
    if (dayDate == null) continue;
    for (final t in day['tasks'] as List<dynamic>? ?? []) {
      if (t is! Map) continue;
      if (!isRevisionTaskOverdue(dayDate, t)) continue;
      final id = revisionTaskId(t);
      if (id.isNotEmpty) ids.add(id);
    }
  }
  return ids;
}

/// True when every id in [taskIds] appears on at least one day in [dailyTasks].
bool dailyTasksContainAllTaskIds(
  List<dynamic> dailyTasks,
  Set<String> taskIds,
) {
  if (taskIds.isEmpty) return true;
  final found = <String>{};
  for (final day in dailyTasks) {
    if (day is! Map) continue;
    for (final t in day['tasks'] as List<dynamic>? ?? []) {
      if (t is! Map) continue;
      final id = revisionTaskId(t);
      if (id.isNotEmpty && taskIds.contains(id)) found.add(id);
    }
  }
  return found.length == taskIds.length;
}

/// Merges n8n reschedule output: locked tasks stay from [beforeDailyTasks],
/// overdue tasks removed from past days and placed per [afterDailyTasks].
List<dynamic> mergeOverdueReschedulePlan({
  required List<dynamic> beforeDailyTasks,
  required List<dynamic> afterDailyTasks,
  required Set<String> overdueTaskIds,
}) {
  if (overdueTaskIds.isEmpty) {
    return List<dynamic>.from(afterDailyTasks);
  }

  final overdueTemplates = <String, Map<String, dynamic>>{};
  for (final day in beforeDailyTasks) {
    if (day is! Map) continue;
    final dateStr = day['date']?.toString();
    if (dateStr == null) continue;
    final dayDate = DateTime.tryParse(dateStr);
    if (dayDate == null) continue;
    for (final t in day['tasks'] as List<dynamic>? ?? []) {
      if (t is! Map) continue;
      final id = revisionTaskId(t);
      if (!overdueTaskIds.contains(id)) continue;
      overdueTemplates[id] = normalizeRevisionTaskMap(t);
    }
  }

  final newDateByOverdueId = <String, String>{};
  for (final day in afterDailyTasks) {
    if (day is! Map) continue;
    final dateKey = revisionDayDateKey(day['date']);
    if (dateKey.isEmpty) continue;
    for (final t in day['tasks'] as List<dynamic>? ?? []) {
      if (t is! Map) continue;
      final id = revisionTaskId(t);
      if (overdueTaskIds.contains(id)) {
        newDateByOverdueId[id] = dateKey;
      }
    }
  }

  final daysByDate = <String, Map<String, dynamic>>{};

  Map<String, dynamic> copyDayShell(Map day, String dateKey) {
    return <String, dynamic>{
      'date': dateKey,
      'dayOfWeek': day['dayOfWeek'],
      'availableMinutes': day['availableMinutes'] ?? 0,
      'tasks': <dynamic>[],
    };
  }

  for (final day in beforeDailyTasks) {
    if (day is! Map) continue;
    final dateKey = revisionDayDateKey(day['date']);
    if (dateKey.isEmpty) continue;
    final kept = <dynamic>[];
    for (final t in day['tasks'] as List<dynamic>? ?? []) {
      if (t is! Map) continue;
      final id = revisionTaskId(t);
      if (overdueTaskIds.contains(id)) continue;
      kept.add(normalizeRevisionTaskMap(t));
    }
    final shell = copyDayShell(day, dateKey);
    shell['tasks'] = kept;
    daysByDate[dateKey] = shell;
  }

  for (final day in afterDailyTasks) {
    if (day is! Map) continue;
    final dateKey = revisionDayDateKey(day['date']);
    if (dateKey.isEmpty) continue;
    if (!daysByDate.containsKey(dateKey)) {
      daysByDate[dateKey] = copyDayShell(day, dateKey);
    } else {
      final existing = daysByDate[dateKey]!;
      final afterAm = day['availableMinutes'];
      if (afterAm != null &&
          (existing['availableMinutes'] == null ||
              existing['availableMinutes'] == 0)) {
        existing['availableMinutes'] = afterAm;
      }
      if (existing['dayOfWeek'] == null && day['dayOfWeek'] != null) {
        existing['dayOfWeek'] = day['dayOfWeek'];
      }
    }
  }

  void placeOverdue(String id, String dateKey) {
    final template = overdueTemplates[id];
    if (template == null || dateKey.isEmpty) return;
    if (!daysByDate.containsKey(dateKey)) {
      daysByDate[dateKey] = <String, dynamic>{
        'date': dateKey,
        'availableMinutes': 0,
        'tasks': <dynamic>[],
      };
    }
    final dayMap = daysByDate[dateKey]!;
    final tasks = List<dynamic>.from(dayMap['tasks'] as List? ?? []);
    tasks.removeWhere(
      (t) => t is Map && revisionTaskId(t) == id,
    );
    final task = Map<String, dynamic>.from(template);
    task['rescheduled'] = true;
    task['completed'] = false;
    tasks.add(task);
    dayMap['tasks'] = tasks;
  }

  for (final entry in newDateByOverdueId.entries) {
    placeOverdue(entry.key, entry.value);
  }

  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final sortedDates = daysByDate.keys.toList()..sort();

  for (final id in overdueTaskIds) {
    if (newDateByOverdueId.containsKey(id)) continue;
    for (final dateKey in sortedDates) {
      final d = DateTime.tryParse(dateKey);
      if (d == null || d.isBefore(todayStart)) continue;
      final dayMap = daysByDate[dateKey]!;
      final am = dayMap['availableMinutes'];
      final minutes = am is num ? am.toInt() : int.tryParse('$am') ?? 0;
      if (minutes <= 0) continue;
      final tasks = dayMap['tasks'] as List? ?? [];
      if (tasks.length >= 4) continue;
      placeOverdue(id, dateKey);
      break;
    }
  }

  return sortedDates.map((k) => daysByDate[k]!).toList();
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
      final id = revisionTaskId(t);
      out.add({
        'taskId': id,
        'scheduledDate': dateStr,
        'title': t['title']?.toString() ?? '',
        'description': t['description']?.toString() ?? '',
        'estimatedMinutes': t['estimatedMinutes'] is num
            ? (t['estimatedMinutes'] as num).toInt()
            : int.tryParse('${t['estimatedMinutes']}') ?? 0,
        'type': t['type']?.toString() ?? 'study',
        if (t['fileName'] != null) 'fileName': t['fileName']?.toString(),
        if (t['pages'] != null) 'pages': t['pages']?.toString(),
      });
    }
  }
  return out;
}
