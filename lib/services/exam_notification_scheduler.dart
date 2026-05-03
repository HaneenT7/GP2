import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/services/notification_service.dart';

class ExamNotificationScheduler {
  static Future<void> scheduleAll() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await NotificationService.cancelAll();

    final snapshot = await FirebaseFirestore.instance
        .collection('revisionPlans')
        .where('userId', isEqualTo: user.uid)
        .get();

    int id = 1000;
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final courseName = data['folderName'] as String? ?? 'Course';

      DateTime? examDate;
      final raw = data['examDate'];
      if (raw is Timestamp) {
        examDate = raw.toDate();
      } else if (raw is String) {
        examDate = DateTime.tryParse(raw);
      }

      if (examDate == null) continue;

      await NotificationService.scheduleExamReminder(
        id: id++,
        courseName: courseName,
        examDate: examDate,
      );
    }
  }
}