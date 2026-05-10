import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

import '../utils/revision_plan_overdue.dart';
import '../services/revision_plan_regenerate_client.dart';
import '../services/revision_plan_service.dart' show RevisionPlanResult;

class RevisionPlanCalendarPage extends StatefulWidget {
  final String planId;

  const RevisionPlanCalendarPage({
    required this.planId,
    super.key,
  });

  @override
  State<RevisionPlanCalendarPage> createState() => _RevisionPlanCalendarPageState();
}

class _RevisionPlanCalendarPageState extends State<RevisionPlanCalendarPage> {
  String _viewMode = 'day'; // 'day' or 'week'
  DateTime _selectedDate = DateTime.now();
  final RevisionPlanRegenerateClient _regenerateClient =
      RevisionPlanRegenerateClient();
  bool _regeneratingPlan = false;
  String _regenerateStatus = '';
  List<DateTime> _getWeekDays() {
    final start = _getWeekStart(_selectedDate);
    return List.generate(7, (i) => start.add(Duration(days: i)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Revision Plan'),
        backgroundColor: const Color(0xFF4B3D8E),
        foregroundColor: Colors.white,
        actions: [
          // View mode toggle
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'day',
                label: Text('Day'),
                icon: Icon(Icons.today, size: 16),
              ),
              ButtonSegment(
                value: 'week',
                label: Text('Week'),
                icon: Icon(Icons.view_week, size: 16),
              ),
            ],
            selected: {_viewMode},
            onSelectionChanged: (Set<String> newSelection) {
              setState(() {
                _viewMode = newSelection.first;
              });
            },
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith<Color>(
                (Set<WidgetState> states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.white;
                  }
                  return Colors.transparent;
                },
              ),
              foregroundColor: WidgetStateProperty.resolveWith<Color>(
                (Set<WidgetState> states) {
                  if (states.contains(WidgetState.selected)) {
                    return const Color(0xFF4B3D8E);
                  }
                  return Colors.white;
                },
              ),
            ),
          ),
          IconButton(
            tooltip: 'Regenerate plan',
            icon: const Icon(Icons.auto_fix_high_outlined),
            onPressed: _regeneratingPlan ? null : _openRegenerateOptions,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('revisionPlans')
                .doc(widget.planId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const Center(child: Text('Plan not found'));
              }

              final planData = snapshot.data!.data() as Map<String, dynamic>;
              final rawTasks = planData['dailyTasks'];
              List<dynamic> dailyTasks = [];
              if (rawTasks is String) {
                try {
                  dailyTasks = jsonDecode(rawTasks) as List<dynamic>;
                } catch (e) {
                  dailyTasks = [];
                }
              } else if (rawTasks is List) {
                dailyTasks = rawTasks;
              }
              final overdueCount = countOverdueTasks(dailyTasks);
              return Column(
                children: [
                  _buildWeekNavigation(),
                  if (overdueCount > 0)
                    _buildOverdueBanner(overdueCount, planData),
                  _buildDaysBar(dailyTasks),
                  const Divider(height: 1),
                  Expanded(
                    child: _viewMode == 'day'
                        ? _buildDayView(dailyTasks)
                        : _buildWeekView(dailyTasks),
                  ),
                ],
              );
            },
          ),
          if (_regeneratingPlan) ...[
            Positioned.fill(
              child: ModalBarrier(
                color: Colors.black26,
                dismissible: false,
              ),
            ),
            Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(_regenerateStatus),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openRegenerateOptions() async {
    final doc = await FirebaseFirestore.instance
        .collection('revisionPlans')
        .doc(widget.planId)
        .get();
    if (!doc.exists || !mounted) return;
    final planData = doc.data() as Map<String, dynamic>;
    List<dynamic> dailyTasks = [];
    final rawTasks = planData['dailyTasks'];
    if (rawTasks is String) {
      try {
        dailyTasks = jsonDecode(rawTasks) as List<dynamic>;
      } catch (_) {}
    } else if (rawTasks is List) {
      dailyTasks = rawTasks;
    }
    final overdueCount = countOverdueTasks(dailyTasks);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Regenerate with AI',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose what to rebuild. Completed tasks stay unchanged in both modes.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.event_busy, color: Colors.deepOrange.shade800),
                title: const Text('Reschedule overdue tasks only'),
                subtitle: Text(
                  overdueCount > 0
                      ? 'Moves incomplete tasks from past days into upcoming days.'
                      : 'No overdue tasks right now.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                enabled: overdueCount > 0 && !_regeneratingPlan,
                onTap: overdueCount == 0
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        _rescheduleOverdue(planData);
                      },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_month, color: Color(0xFF4B3D8E)),
                title: const Text('Regenerate full plan'),
                subtitle: Text(
                  'Rebuilds all incomplete work to fit availability and exam date.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmRegenerateFullPlan(planData);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmRegenerateFullPlan(Map<String, dynamic> planData) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Regenerate full plan?'),
        content: const Text(
          'All incomplete tasks will be rescheduled from scratch while keeping '
          'completed tasks as they are. This may change many future dates.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _runRegenerate(
      status: 'Regenerating full plan…',
      action: () => _regenerateClient.regenerateFullPlan(
        planId: widget.planId,
        planData: planData,
      ),
      successMessage: 'Full plan updated.',
    );
  }

  Future<void> _rescheduleOverdue(Map<String, dynamic> planData) async {
    final beforeDailyTasks = _parseDailyTasksFromPlan(planData);
    final wasString = planData['dailyTasks'] is String;
    await _runRegenerate(
      status: 'Rescheduling overdue tasks…',
      action: () => _regenerateClient.rescheduleOverdueTasks(
        planId: widget.planId,
        planData: planData,
      ),
      successMessage: 'Plan updated. Overdue tasks were sent to reschedule.',
      onCompleted: (result) async {
        await _markRescheduledTasks(
          beforeDailyTasks: beforeDailyTasks,
          result: result,
          storeAsString: wasString,
        );
      },
    );
  }

  Future<void> _runRegenerate({
    required String status,
    required Future<RevisionPlanResult> Function() action,
    required String successMessage,
    Future<void> Function(RevisionPlanResult result)? onCompleted,
  }) async {
    setState(() {
      _regeneratingPlan = true;
      _regenerateStatus = status;
    });
    try {
      final result = await action();
      if (!mounted) return;
      if (result.status == 'completed') {
        if (onCompleted != null) {
          await onCompleted(result);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'Regeneration failed'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''),
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _regeneratingPlan = false;
          _regenerateStatus = '';
        });
      }
    }
  }

  List<dynamic> _parseDailyTasksFromPlan(Map<String, dynamic> planData) {
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

  Future<void> _markRescheduledTasks({
    required List<dynamic> beforeDailyTasks,
    required RevisionPlanResult result,
    required bool storeAsString,
  }) async {
    List<dynamic> afterDailyTasks = [];
    if (result.planContent != null && result.planContent!.trim().isNotEmpty) {
      try {
        afterDailyTasks = jsonDecode(result.planContent!) as List<dynamic>;
      } catch (_) {}
    }
    if (afterDailyTasks.isEmpty) {
      final snap = await FirebaseFirestore.instance
          .collection('revisionPlans')
          .doc(widget.planId)
          .get();
      final data = snap.data();
      if (data == null) return;
      afterDailyTasks = _parseDailyTasksFromPlan(data);
    }
    if (afterDailyTasks.isEmpty) return;

    // n8n often omits or zeroes `availableMinutes` on partial updates; restore from the
    // snapshot taken before reschedule so days don't show "0 minutes" / no availability.
    final mergedDays =
        _mergeBaselineDayMetadataOntoAfter(beforeDailyTasks, afterDailyTasks);

    final beforeDateByTaskId = <String, String>{};
    for (final day in beforeDailyTasks) {
      if (day is! Map) continue;
      final dateKey = _revisionDayDateKey(day['date']);
      if (dateKey.isEmpty) continue;
      final tasks = day['tasks'] as List<dynamic>? ?? [];
      for (final t in tasks) {
        if (t is! Map) continue;
        final id = t['taskId']?.toString() ?? '';
        if (id.isEmpty) continue;
        beforeDateByTaskId[id] = dateKey;
      }
    }

    final movedTaskIds = <String>{};
    for (final day in mergedDays) {
      final dateKey = _revisionDayDateKey(day['date']);
      if (dateKey.isEmpty) continue;
      final tasks = day['tasks'] as List<dynamic>? ?? [];
      for (final t in tasks) {
        if (t is! Map) continue;
        final id = t['taskId']?.toString() ?? '';
        if (id.isEmpty) continue;
        final beforeDate = beforeDateByTaskId[id];
        if (beforeDate != null && beforeDate != dateKey) {
          movedTaskIds.add(id);
        }
      }
    }

    final updated = <Map<String, dynamic>>[];
    for (final day in mergedDays) {
      final dayMap = Map<String, dynamic>.from(day);
      final tasks = dayMap['tasks'] as List<dynamic>? ?? [];
      dayMap['tasks'] = tasks.map((task) {
        final t = Map<String, dynamic>.from(task as Map<dynamic, dynamic>);
        final id = t['taskId']?.toString() ?? '';
        if (movedTaskIds.isEmpty) {
          t.remove('rescheduled');
        } else {
          t['rescheduled'] = movedTaskIds.contains(id);
        }
        return t;
      }).toList();
      updated.add(dayMap);
    }

    await FirebaseFirestore.instance
        .collection('revisionPlans')
        .doc(widget.planId)
        .update({
      'dailyTasks': storeAsString ? jsonEncode(updated) : updated,
    });
  }

  /// Normalizes day keys so `2026-05-10` and `2026-05-10T00:00:00.000Z` match.
  String _revisionDayDateKey(dynamic raw) {
    final s = raw?.toString().trim() ?? '';
    if (s.isEmpty) return '';
    try {
      final head = s.contains('T') ? s.substring(0, s.indexOf('T')) : s;
      final d = DateTime.parse(head);
      final y = d.year.toString().padLeft(4, '0');
      final m = d.month.toString().padLeft(2, '0');
      final day = d.day.toString().padLeft(2, '0');
      return '$y-$m-$day';
    } catch (_) {
      return s;
    }
  }

  int? _asIntMinutes(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.round();
    return int.tryParse(v.toString().trim());
  }

  /// Copies `availableMinutes` and weekday `day` from [beforeDailyTasks] when n8n drops them.
  List<Map<String, dynamic>> _mergeBaselineDayMetadataOntoAfter(
    List<dynamic> beforeDailyTasks,
    List<dynamic> afterDailyTasks,
  ) {
    final baseline = <String, Map<String, dynamic>>{};
    for (final day in beforeDailyTasks) {
      if (day is! Map) continue;
      final key = _revisionDayDateKey(day['date']);
      if (key.isEmpty) continue;
      baseline[key] = Map<String, dynamic>.from(day);
    }

    final out = <Map<String, dynamic>>[];
    for (final day in afterDailyTasks) {
      if (day is! Map) continue;
      final dm = Map<String, dynamic>.from(day);
      final key = _revisionDayDateKey(dm['date']);
      final prev = key.isEmpty ? null : baseline[key];
      if (prev != null) {
        final prevAm = _asIntMinutes(prev['availableMinutes']);
        final curRaw = dm['availableMinutes'];
        final curAm = _asIntMinutes(curRaw);

        if (!dm.containsKey('availableMinutes') || curRaw == null) {
          dm['availableMinutes'] = prev['availableMinutes'];
        } else if (curAm != null && curAm <= 0 && prevAm != null && prevAm > 0) {
          dm['availableMinutes'] = prev['availableMinutes'];
        }

        final pd = prev['day']?.toString().trim() ?? '';
        final cd = dm['day']?.toString().trim() ?? '';
        if (cd.isEmpty && pd.isNotEmpty) {
          dm['day'] = prev['day'];
        }
      }
      out.add(dm);
    }
    return out;
  }
  Widget _buildWeekNavigation() {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [

        /// Left arrow
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () {
            setState(() {
              _selectedDate = _selectedDate.subtract(
                const Duration(days: 7),
              );
            });
          },
        ),

        /// Week label
        Text(
          'Week of ${DateFormat('MMM d').format(_getWeekStart(_selectedDate))}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),

        /// Right arrow
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () {
            setState(() {
              _selectedDate = _selectedDate.add(
                const Duration(days: 7),
              );
            });
          },
        ),
      ],
    ),
  );
}
/////////////////////////////////////////////////////////////////////////////////
Widget _buildDaysBar(List<dynamic> dailyTasks) {
  final weekDays = _getWeekDays();

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      children: List.generate(weekDays.length, (index) {
        final day = weekDays[index];
        final isSelected = _isSameDay(day, _selectedDate);
        final dayData = _findDayData(dailyTasks, day);
        final tasks = dayData?['tasks'] as List<dynamic>? ?? [];
        final hasOverdueOnDay = weekDayHasOverdueIncomplete(dailyTasks, day);
        final tileBackground = hasOverdueOnDay
            ? (isSelected ? Colors.deepOrange.shade100 : Colors.deepOrange.shade50)
            : (isSelected ? Colors.grey[300]! : Colors.grey[100]!);
        final tileBorder = hasOverdueOnDay
            ? (isSelected ? Colors.deepOrange.shade700 : Colors.deepOrange.shade300)
            : (isSelected ? Colors.black87 : Colors.grey[300]!);

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index < 6 ? 10 : 0),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                setState(() {
                  _selectedDate = day;
                  _viewMode = 'day';
                });
              },
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  color: tileBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: tileBorder,
                    width: isSelected ? 1.5 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('EEE').format(day),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('MMM d').format(day),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),

                    // Overdue (past day, incomplete) vs scheduled tasks
                    if (hasOverdueOnDay)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.deepOrange,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    else if (tasks.isNotEmpty)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    ),
  );
}
  Widget _buildDayView(List<dynamic> dailyTasks) {
    final dayData = _findDayData(dailyTasks, _selectedDate);

    if (dayData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No tasks scheduled for this day',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    final tasks = dayData['tasks'] as List<dynamic>? ?? [];
    final availableMinutes = dayData['availableMinutes'] ?? 0;
    final dayDate = DateTime.parse(dayData['date'] as String);

    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.free_breakfast, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No study time available',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Rest day',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Day summary
        Card(
          color: const Color(0xFF4B3D8E).withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Study Time',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      '${availableMinutes} minutes',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4B3D8E),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Tasks',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      '${tasks.where((t) => t['completed'] == true).length}/${tasks.length}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4B3D8E),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Tasks list
        ...tasks.asMap().entries.map((entry) {
          final index = entry.key;
          final task = entry.value as Map<dynamic, dynamic>;
          final isOverdue = isRevisionTaskOverdue(dayDate, task);
          final isRescheduled = task['rescheduled'] == true;
          return _buildTaskCard(
            task,
            index,
            isOverdue: isOverdue,
            isRescheduled: isRescheduled,
          );
        }).toList(),
      ],
    );
  }

  Widget _buildWeekView(List<dynamic> dailyTasks) {
    final weekStart = _getWeekStart(_selectedDate);
    final weekDays = List.generate(7, (i) => weekStart.add(Duration(days: i)));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 7,
      itemBuilder: (context, index) {
        final day = weekDays[index];
        final dayData = _findDayData(dailyTasks, day);
        final tasks = dayData?['tasks'] as List<dynamic>? ?? [];
        final isToday = _isSameDay(day, DateTime.now());

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: isToday ? 3 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isToday
                ? const BorderSide(color: Color(0xFF4B3D8E), width: 2)
                : BorderSide.none,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              setState(() {
                _selectedDate = day;
                _viewMode = 'day';
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isToday)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4B3D8E),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'TODAY',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (isToday) const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          DateFormat('EEEE, MMM d').format(day),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (tasks.isNotEmpty)
                        Text(
                          '${tasks.where((t) => t['completed'] == true).length}/${tasks.length}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                  
                  if (tasks.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'No tasks',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    )
                  else
                    ...tasks.take(3).map((task) {
                      final t = task as Map<dynamic, dynamic>;
                      final overdue = isRevisionTaskOverdue(day, t);
                      final isRescheduled = t['rescheduled'] == true;
                      return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Icon(
                            task['completed'] == true
                                ? Icons.check_circle
                                : overdue
                                    ? Icons.warning_amber_rounded
                                    : isRescheduled
                                        ? Icons.schedule
                                    : Icons.radio_button_unchecked,
                            size: 16,
                            color: task['completed'] == true
                                ? Colors.green
                                : overdue
                                    ? Colors.deepOrange
                                    : isRescheduled
                                        ? Colors.indigo
                                    : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              task['title'] ?? '',
                              style: TextStyle(
                                fontSize: 14,
                                decoration: task['completed'] == true
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: task['completed'] == true
                                    ? Colors.grey
                                    : overdue
                                        ? Colors.deepOrange.shade900
                                        : isRescheduled
                                            ? Colors.indigo.shade700
                                        : Colors.black87,
                                fontWeight:
                                    overdue ? FontWeight.w600 : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                    }).toList(),
                  
                  if (tasks.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '+${tasks.length - 3} more',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
Widget _buildOverdueBanner(int count, Map<String, dynamic> planData) {
    final rawTasks = planData['dailyTasks'];
    List<dynamic> dailyTasks = [];
    if (rawTasks is String) {
      try {
        dailyTasks = jsonDecode(rawTasks) as List<dynamic>;
      } catch (_) {}
    } else if (rawTasks is List) {
      dailyTasks = rawTasks;
    }

    return Material(
      color: Colors.deepOrange.shade50,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.schedule, size: 20, color: Colors.deepOrange.shade800),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => _jumpToFirstOverdueDay(dailyTasks),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    count == 1
                        ? '1 overdue task (past days, not completed)'
                        : '$count overdue tasks (past days, not completed)',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.deepOrange.shade900,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: _regeneratingPlan
                  ? null
                  : () => _rescheduleOverdue(planData),
              child: Text(
                _regeneratingPlan ? 'Working…' : 'Reschedule with AI',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.deepOrange.shade900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

DateTime? _firstOverdueDay(List<dynamic> dailyTasks) {
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
    if (first == null || dayDate.isBefore(first)) {
      first = dayDate;
    }
  }
  return first;
}

void _jumpToFirstOverdueDay(List<dynamic> dailyTasks) {
  final overdueDay = _firstOverdueDay(dailyTasks);
  if (overdueDay == null) return;
  setState(() {
    _selectedDate = DateTime(overdueDay.year, overdueDay.month, overdueDay.day);
    _viewMode = 'day';
  });
}

Widget _buildTaskCard(
  Map<dynamic, dynamic> task,
  int index, {
  required bool isOverdue,
  required bool isRescheduled,
}) {
  final isCompleted = task['completed'] == true;
  final title = task['title'] ?? '';
  final course = task['course'] ?? 'Study Task';

  const greenCheck = Color(0xFF52C41A);
  const greenBg = Color(0xFFE6F7E9);
  const greyButtonBg = Color(0xFFF5F5F5);

  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: isCompleted ? greenBg : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted
              ? Colors.transparent
              : isOverdue
                  ? Colors.deepOrange.shade300
                  : isRescheduled
                      ? Colors.indigo.shade200
                  : const Color(0xFFE8E8E8),
          width: (isOverdue || isRescheduled) && !isCompleted ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [

          /// Checkbox
          GestureDetector(
            onTap: () async {
              await _toggleTaskCompletion(index, !isCompleted);
            },
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isCompleted ? greenCheck : Colors.black87,
                  width: isCompleted ? 2 : 1,
                ),
              ),
              child: isCompleted
                  ? const Center(
                      child: Icon(Icons.check, size: 16, color: greenCheck),
                    )
                  : null,
            ),
          ),

          const SizedBox(width: 14),

          /// Task title + course
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isCompleted
                              ? Colors.grey
                              : isOverdue
                                  ? Colors.deepOrange.shade900
                                  : isRescheduled
                                      ? Colors.indigo.shade700
                                  : Colors.black87,
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                    if (isOverdue && !isCompleted)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.deepOrange.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Overdue',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.deepOrange.shade900,
                            ),
                          ),
                        ),
                      ),
                    if (isRescheduled && !isCompleted)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Rescheduled',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.indigo.shade700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  course,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          Tooltip(
            message: 'Move task',
            child: IconButton(
              icon: const Icon(Icons.drive_file_move_outline),
              color: Colors.grey.shade700,
              onPressed: () {
                _pickAndMoveTask(index, title);
              },
            ),
          ),

          const SizedBox(width: 4),

          /// Take Quiz button
          Material(
            color: isCompleted ? greenCheck : greyButtonBg,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: () {
                // TODO connect quiz page later
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Text(
                  'Take Quiz',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isCompleted ? Colors.white : Colors.grey[600],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
Future<void> _toggleTaskCompletion(int taskIndex, bool completed) async {
  try {
    final planDoc = await FirebaseFirestore.instance
        .collection('revisionPlans')
        .doc(widget.planId)
        .get();

    if (!planDoc.exists) return;

    final planData = planDoc.data()!;
    
    // Safe decoding
    final rawTasks = planData['dailyTasks'];
    List<dynamic> dailyTasks = [];
    bool wasString = rawTasks is String;

    if (wasString) {
      dailyTasks = jsonDecode(rawTasks) as List<dynamic>;
    } else {
      dailyTasks = List<dynamic>.from(rawTasks ?? []);
    }

    // Find the day and update the task
    for (var i = 0; i < dailyTasks.length; i++) {
      final day = dailyTasks[i];
      final dayDate = DateTime.parse(day['date']);
      
      if (_isSameDay(dayDate, _selectedDate)) {
        final tasks = List<dynamic>.from(day['tasks']);
        if (taskIndex < tasks.length) {
          tasks[taskIndex]['completed'] = completed;
          dailyTasks[i]['tasks'] = tasks;
          break;
        }
      }
    }

    // Save back in the same format it was found (String or List)
    dynamic dataToSave = wasString ? jsonEncode(dailyTasks) : dailyTasks;

    await FirebaseFirestore.instance
        .collection('revisionPlans')
        .doc(widget.planId)
        .update({'dailyTasks': dataToSave});
        await _checkAndMarkPlanCompleted(dailyTasks, planData);

  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          e.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''),
        ),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }
}


Future<void> _checkAndMarkPlanCompleted(
  List<dynamic> dailyTasks,
  Map<String, dynamic> planData,
) async {
  int totalTasks = 0;
  int completedTasks = 0;

  for (var day in dailyTasks) {
    final tasks = day['tasks'] as List<dynamic>? ?? [];
    totalTasks += tasks.length;
    completedTasks += tasks.where((t) => t['completed'] == true).length;
  }

  if (totalTasks == 0) return;

  final bool isNowComplete = completedTasks == totalTasks;
  final bool wasAlreadyMarked = planData['isCompleted'] == true;

  if (isNowComplete && !wasAlreadyMarked) {
    final userId = planData['userId'] as String?;

    await FirebaseFirestore.instance
        .collection('revisionPlans')
        .doc(widget.planId)
        .update({'isCompleted': true});

    if (userId != null) {
      await FirebaseFirestore.instance
          .collection('students')
          .doc(userId)
          .update({'completedPlans': FieldValue.increment(1)});
    }

    if (!mounted) return;
  
  }

  if (!isNowComplete && wasAlreadyMarked) {
    final userId = planData['userId'] as String?;

    await FirebaseFirestore.instance
        .collection('revisionPlans')
        .doc(widget.planId)
        .update({'isCompleted': false});

    if (userId != null) {
      await FirebaseFirestore.instance
          .collection('students')
          .doc(userId)
          .update({'completedPlans': FieldValue.increment(-1)});
    }
  }
}

Future<void> _pickAndMoveTask(int taskIndex, String taskTitle) async {
  final targetDate = await showDatePicker(
    context: context,
    initialDate: _selectedDate,
    firstDate: DateTime.now().subtract(const Duration(days: 365)),
    lastDate: DateTime.now().add(const Duration(days: 3650)),
    helpText: 'Move task to date',
  );
  if (targetDate == null || !mounted) return;

  if (_isSameDay(targetDate, _selectedDate)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Task is already on this date.')),
    );
    return;
  }

  await _moveTaskToDate(
    taskIndex: taskIndex,
    fromDate: _selectedDate,
    toDate: targetDate,
    taskTitle: taskTitle,
  );
}

String _toIsoDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

Future<void> _moveTaskToDate({
  required int taskIndex,
  required DateTime fromDate,
  required DateTime toDate,
  required String taskTitle,
}) async {
  final planRef = FirebaseFirestore.instance
      .collection('revisionPlans')
      .doc(widget.planId);
  final planDoc = await planRef.get();
  if (!planDoc.exists || !mounted) return;

  final planData = planDoc.data()!;
  final rawTasks = planData['dailyTasks'];
  final wasString = rawTasks is String;

  List<dynamic> dailyTasks = [];
  if (rawTasks is String) {
    dailyTasks = jsonDecode(rawTasks) as List<dynamic>;
  } else {
    dailyTasks = List<dynamic>.from(rawTasks ?? []);
  }

  int sourceDayIndex = -1;
  for (var i = 0; i < dailyTasks.length; i++) {
    final day = dailyTasks[i] as Map<dynamic, dynamic>;
    final dayDate = DateTime.tryParse(day['date']?.toString() ?? '');
    if (dayDate != null && _isSameDay(dayDate, fromDate)) {
      sourceDayIndex = i;
      break;
    }
  }

  if (sourceDayIndex == -1) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not find source day for this task.')),
    );
    return;
  }

  final sourceDay = Map<String, dynamic>.from(
    dailyTasks[sourceDayIndex] as Map<dynamic, dynamic>,
  );
  final sourceTasks = List<dynamic>.from(sourceDay['tasks'] ?? []);
  if (taskIndex < 0 || taskIndex >= sourceTasks.length) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not find selected task.')),
    );
    return;
  }

  final movedTask = Map<String, dynamic>.from(
    sourceTasks.removeAt(taskIndex) as Map<dynamic, dynamic>,
  );
  sourceDay['tasks'] = sourceTasks;
  dailyTasks[sourceDayIndex] = sourceDay;

  int targetDayIndex = -1;
  for (var i = 0; i < dailyTasks.length; i++) {
    final day = dailyTasks[i] as Map<dynamic, dynamic>;
    final dayDate = DateTime.tryParse(day['date']?.toString() ?? '');
    if (dayDate != null && _isSameDay(dayDate, toDate)) {
      targetDayIndex = i;
      break;
    }
  }

  if (targetDayIndex == -1) {
    dailyTasks.add({
      'date': _toIsoDate(toDate),
      'day': DateFormat('EEEE').format(toDate),
      'availableMinutes': 0,
      'tasks': [movedTask],
    });
  } else {
    final targetDay = Map<String, dynamic>.from(
      dailyTasks[targetDayIndex] as Map<dynamic, dynamic>,
    );
    final targetTasks = List<dynamic>.from(targetDay['tasks'] ?? []);
    targetTasks.add(movedTask);
    targetDay['tasks'] = targetTasks;
    dailyTasks[targetDayIndex] = targetDay;
  }

  dailyTasks.sort((a, b) {
    final ad = DateTime.tryParse((a as Map<dynamic, dynamic>)['date']?.toString() ?? '');
    final bd = DateTime.tryParse((b as Map<dynamic, dynamic>)['date']?.toString() ?? '');
    if (ad == null && bd == null) return 0;
    if (ad == null) return 1;
    if (bd == null) return -1;
    return ad.compareTo(bd);
  });

  try {
    final dataToSave = wasString ? jsonEncode(dailyTasks) : dailyTasks;
    await planRef.update({'dailyTasks': dataToSave});

    if (!mounted) return;
    setState(() {
      _selectedDate = DateTime(toDate.year, toDate.month, toDate.day);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Moved "${taskTitle.isEmpty ? 'task' : taskTitle}" to ${DateFormat('MMM d').format(toDate)}.',
        ),
      ),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Could not move task: ${e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '')}',
        ),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }
}

  Map<dynamic, dynamic>? _findDayData(List<dynamic> dailyTasks, DateTime date) {
    for (var day in dailyTasks) {
      final dayDate = DateTime.parse(day['date']);
      if (_isSameDay(dayDate, date)) {
        return day;
      }
    }
    return null;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  DateTime _getWeekStart(DateTime date) {
    return date.subtract(Duration(days: date.weekday % 7));
  }
}