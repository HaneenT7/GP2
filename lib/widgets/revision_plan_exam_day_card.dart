import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../utils/revision_plan_overdue.dart';

/// Shown on the calendar day that matches [planData]'s exam date.
class RevisionPlanExamDayCard extends StatelessWidget {
  const RevisionPlanExamDayCard({
    super.key,
    required this.planData,
  });

  final Map<String, dynamic> planData;

  @override
  Widget build(BuildContext context) {
    final exam = revisionPlanExamDate(planData);
    if (exam == null) return const SizedBox.shrink();

    final folderName = planData['folderName']?.toString().trim() ?? '';
    final materialTitle = planData['materialTitle']?.toString().trim() ?? '';
    final subject = materialTitle.isNotEmpty
        ? materialTitle
        : (folderName.isNotEmpty ? folderName : 'Your exam');

    return Card(
      elevation: 0,
      color: const Color(0xFFFFF8E1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.amber.shade600, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school_rounded, size: 56, color: Colors.amber.shade800),
            const SizedBox(height: 12),
            Text(
              'Exam day',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.amber.shade900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subject,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              DateFormat('EEEE, MMMM d, yyyy').format(exam),
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            Text(
              'No study tasks are scheduled today — focus on your exam.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
