import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Riyadh'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: android),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> scheduleExamReminder({
    required int id,
    required String courseName,
    required DateTime examDate,
  }) async {
    final reminderDate = examDate.subtract(const Duration(days: 1));
    final now = DateTime.now();
    if (reminderDate.isBefore(now)) return;

    final scheduledTime = tz.TZDateTime(
      tz.local,
      reminderDate.year,
      reminderDate.month,
      reminderDate.day,
      8, 16,
    );

    await _plugin.zonedSchedule(
      id,
      "⏰ Exam Reminder",
      "Your $courseName exam is tomorrow. Review your notes and get some rest! 📚",
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'exam_reminders',
          'Exam Reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: 
          UILocalNotificationDateInterpretation.absoluteTime, 
    );
  }

  static Future<void> cancelAll() async => await _plugin.cancelAll();
}