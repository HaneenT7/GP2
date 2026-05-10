import 'dart:async';
import 'dart:convert';
import 'dart:math' show Random;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../utils/revision_plan_overdue.dart';
import 'revision_plan_service.dart' show RevisionPlanResult;

/// Regenerate / reschedule-overdue flows for [RevisionPlanCalendarPage] only.
/// Does not change [RevisionPlanService] new-plan generation.
class RevisionPlanRegenerateClient {
  RevisionPlanRegenerateClient();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  static const String _collection = 'revisionPlans';
  static const Duration _listenTimeout = Duration(seconds: 120);

  static const List<String> _variationHints = [
    'Spread incomplete work evenly across eligible study days.',
    'When possible, place longer study blocks on higher-capacity days and shorter reviews elsewhere.',
    'Alternate intensive study days with lighter review-focused days across the week.',
    'Group related incomplete topics on adjacent days for coherence, without copying the old calendar.',
    'Interleave review and quiz tasks between study blocks for variety.',
    'Prioritize placing overdue or backlog items earlier in the remaining timeline (still within rules).',
  ];

  String _generateRequestId() {
    final u = _userId ?? 'anon';
    final t = DateTime.now().millisecondsSinceEpoch;
    return '${u.substring(0, u.length > 8 ? 8 : u.length)}_$t';
  }

  Uri _regenerateWebhookUri() {
    final extra = n8nRegenerateRevisionPlanWebhookUrl.trim();
    if (extra.isNotEmpty) return Uri.parse(extra);
    return Uri.parse(n8nRevisionPlanWebhookUrl);
  }

  String _examDateIsoFromPlan(Map<String, dynamic> planData) {
    final e = planData['examDate'];
    if (e is Timestamp) {
      return e.toDate().toIso8601String().split('T').first;
    }
    if (e is String) {
      return e.contains('T') ? e.split('T').first : e;
    }
    return DateTime.now().toIso8601String().split('T').first;
  }

  String _cleanText(dynamic value, {String fallback = ''}) {
    final s = value?.toString().trim() ?? '';
    if (s.isEmpty || s.toLowerCase() == 'undefined' || s.toLowerCase() == 'null') {
      return fallback;
    }
    return s;
  }

  List<dynamic> _parseDailyTasksField(Map<String, dynamic> planData) {
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

  String _todayIsoLocal() {
    final n = DateTime.now();
    final y = n.year.toString().padLeft(4, '0');
    final m = n.month.toString().padLeft(2, '0');
    final d = n.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  int _daysUntilExamFromPlan(Map<String, dynamic> planData) {
    final iso = _examDateIsoFromPlan(planData);
    final parts = iso.split('-');
    if (parts.length != 3) return 0;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return 0;
    final exam = DateTime(y, m, d);
    final now = DateTime.now();
    final t0 = DateTime(now.year, now.month, now.day);
    final e0 = DateTime(exam.year, exam.month, exam.day);
    return e0.difference(t0).inDays;
  }

  Map<String, dynamic> _regenerateBaseFields({
    required String userId,
    required String requestId,
    required String planId,
    required Map<String, dynamic> planData,
  }) {
    final folderName = _cleanText(planData['folderName'], fallback: 'Study Material');
    final materialTitle = _cleanText(
      planData['materialTitle'],
      fallback: folderName,
    );
    final pdfUrl = _cleanText(planData['pdfUrl']);
    final selectedFileNames = (materialTitle.isNotEmpty &&
            materialTitle != 'undefined')
        ? <String>['$materialTitle.pdf']
        : <String>['study_material.pdf'];
    final fileUrls = pdfUrl.isNotEmpty ? <String>[pdfUrl] : <String>[];

    final rng = Random();
    final nonce =
        '${DateTime.now().microsecondsSinceEpoch}_${rng.nextInt(0x3fffffff)}';

    return <String, dynamic>{
      'userId': userId,
      'requestId': requestId,
      'planId': planId,
      'mode': 'regenerate_overdue',
      'folderName': folderName,
      'materialTitle': materialTitle,
      'pdfUrl': pdfUrl,
      'examDate': _examDateIsoFromPlan(planData),
      'daysUntilExam': _daysUntilExamFromPlan(planData),
      'rescheduleFrom': DateTime.now().toIso8601String(),
      'todayIso': _todayIsoLocal(),
      'selectedFileNames': selectedFileNames,
      'fileUrls': fileUrls,
      'regenerationNonce': nonce,
      'variationHint': _variationHints[rng.nextInt(_variationHints.length)],
    };
  }

  Future<RevisionPlanResult> _waitForRegeneratePlan({
    required String planId,
    required String baselineDailyTasksJson,
  }) async {
    final docRef = _firestore.collection(_collection).doc(planId);

    final completer = Completer<RevisionPlanResult>();
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? sub;
    Timer? timeoutTimer;

    void finish(RevisionPlanResult result) {
      if (!completer.isCompleted) {
        sub?.cancel();
        timeoutTimer?.cancel();
        completer.complete(result);
      }
    }

    timeoutTimer = Timer(_listenTimeout, () {
      finish(RevisionPlanResult(
        requestId: planId,
        status: 'error',
        errorMessage:
            'Timeout waiting for plan. In n8n, upsert revisionPlans/{planId} with '
            'status "completed" or "error" after writing dailyTasks.',
      ));
    });

    sub = docRef.snapshots().listen((snap) {
      if (!snap.exists) return;
      final data = snap.data();
      if (data == null) return;

      final rawStatus = (data['status'] as String? ?? 'pending').toLowerCase();
      if (rawStatus == 'error') {
        finish(RevisionPlanResult.fromFirestore(data));
        return;
      }

      // Existing revision plans usually stay Firestore status "completed" (or pending
      // while dailyTasks already exists — see RevisionPlanResult.fromFirestore).
      // Do NOT finish on status alone or the listener completes on the first snapshot
      // before n8n writes updated dailyTasks ("Reschedule overdue" looks like it worked
      // but nothing changes).
      final after = jsonEncode(_parseDailyTasksField(data));
      if (after.isNotEmpty && after != baselineDailyTasksJson) {
        finish(RevisionPlanResult(
          requestId: planId,
          status: 'completed',
          planContent: after,
        ));
      }
    });

    return completer.future;
  }

  Future<RevisionPlanResult> _postRegenerateWebhook(
    Map<String, dynamic> body, {
    required String baselineDailyTasksJson,
  }) async {
    final planId = body['planId'] as String;
    final uri = _regenerateWebhookUri();
    if (uri.host == 'your-n8n-instance.com') {
      throw Exception(
        'Configure n8n webhook URL in lib/config/app_config.dart.',
      );
    }

    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: utf8.encode(jsonEncode(body)),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Webhook failed: ${response.statusCode} ${response.body}',
      );
    }

    return _waitForRegeneratePlan(
      planId: planId,
      baselineDailyTasksJson: baselineDailyTasksJson,
    );
  }

  Future<RevisionPlanResult> rescheduleOverdueTasks({
    required String planId,
    required Map<String, dynamic> planData,
  }) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('Please sign in to reschedule.');
    }

    final dailyTasks = _parseDailyTasksField(planData);
    final overdue = collectOverdueTasksForReschedule(dailyTasks);
    if (overdue.isEmpty) {
      throw Exception('No overdue tasks to reschedule.');
    }

    final requestId = _generateRequestId();
    final baselineJson = jsonEncode(dailyTasks);
    final body = <String, dynamic>{
      ..._regenerateBaseFields(
        userId: userId,
        requestId: requestId,
        planId: planId,
        planData: planData,
      ),
      'existingDailyTasks': dailyTasks,
      'existingDailyTasksJson': jsonEncode(dailyTasks),
      'overdueTasks': overdue,
      'overdueTasksJson': jsonEncode(overdue),
      'rescheduleOverdue': true,
      'regenerateFullPlan': false,
      'preserveNonOverdueTasks': true,
      'lockedTaskPolicy': 'keep_non_overdue_unchanged',
      'modelInstruction':
          'Only reschedule overdue tasks. Keep every non-overdue task exactly '
              'as-is (same date/day bucket, order, and task content).',
    };

    return _postRegenerateWebhook(body, baselineDailyTasksJson: baselineJson);
  }

  Future<RevisionPlanResult> regenerateFullPlan({
    required String planId,
    required Map<String, dynamic> planData,
  }) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('Please sign in to regenerate the plan.');
    }

    final dailyTasks = _parseDailyTasksField(planData);
    if (dailyTasks.isEmpty) {
      throw Exception('No plan tasks to regenerate.');
    }
    final overdue = collectOverdueTasksForReschedule(dailyTasks);
    if (overdue.isEmpty) {
      throw Exception(
        'No overdue tasks to reschedule. Non-overdue tasks are kept unchanged.',
      );
    }

    final requestId = _generateRequestId();
    final baselineJson = jsonEncode(dailyTasks);
    final body = <String, dynamic>{
      ..._regenerateBaseFields(
        userId: userId,
        requestId: requestId,
        planId: planId,
        planData: planData,
      ),
      'existingDailyTasks': dailyTasks,
      'existingDailyTasksJson': jsonEncode(dailyTasks),
      'overdueTasks': overdue,
      'overdueTasksJson': jsonEncode(overdue),
      'rescheduleOverdue': true,
      'regenerateFullPlan': false,
      'preserveNonOverdueTasks': true,
      'lockedTaskPolicy': 'keep_non_overdue_unchanged',
      'modelInstruction':
          'Only reschedule overdue tasks. Keep every non-overdue task exactly '
              'as-is (same date/day bucket, order, and task content).',
    };

    return _postRegenerateWebhook(body, baselineDailyTasksJson: baselineJson);
  }
}
