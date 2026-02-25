import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// Payload sent to n8n webhook. n8n will forward to Gemini and then write result to Firebase.
class RevisionPlanRequest {
  final String userId;
  final String requestId;
  final String folderId;
  final String folderName;
  final String examDateIso;
  final List<String> selectedFileIds;
  final List<String> selectedFileNames;

  RevisionPlanRequest({
    required this.userId,
    required this.requestId,
    required this.folderId,
    required this.folderName,
    required this.examDateIso,
    required this.selectedFileIds,
    required this.selectedFileNames,
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'requestId': requestId,
        'folderId': folderId,
        'folderName': folderName,
        'examDate': examDateIso,
        'selectedFileIds': selectedFileIds,
        'selectedFileNames': selectedFileNames,
      };
}

/// Result written by n8n to Firestore. App listens for this.
class RevisionPlanResult {
  final String requestId;
  final String status; // 'pending' | 'completed' | 'error'
  final String? planContent;
  final String? errorMessage;
  final DateTime? completedAt;

  RevisionPlanResult({
    required this.requestId,
    required this.status,
    this.planContent,
    this.errorMessage,
    this.completedAt,
  });

  static RevisionPlanResult fromFirestore(Map<String, dynamic> data) {
    return RevisionPlanResult(
      requestId: data['requestId'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      planContent: data['planContent'] as String?,
      errorMessage: data['errorMessage'] as String?,
      completedAt: data['completedAt'] != null
          ? (data['completedAt'] is Timestamp
              ? (data['completedAt'] as Timestamp).toDate()
              : DateTime.tryParse(data['completedAt'].toString()))
          : null,
    );
  }
}

/// Service to trigger revision plan generation via n8n (Gemini) and read result from Firebase.
class RevisionPlanService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  static const String _collection = 'revisionPlans';
  static const Duration _listenTimeout = Duration(seconds: 120);

  /// Send revision plan details to n8n webhook. n8n will call Gemini and write the plan to Firebase.
  Future<void> sendToN8n(RevisionPlanRequest request) async {
    final uri = Uri.parse(n8nRevisionPlanWebhookUrl);
    if (uri.host == 'your-n8n-instance.com') {
      throw Exception(
        'Configure n8n webhook URL in lib/config/app_config.dart or via N8N_REVISION_PLAN_WEBHOOK env.',
      );
    }

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: utf8.encode(jsonEncode(request.toJson())),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Webhook failed: ${response.statusCode} ${response.body}',
      );
    }
  }

  /// Listen for the plan document written by n8n. Completes when status is 'completed' or 'error', or on timeout.
  Future<RevisionPlanResult> waitForPlan(String userId, String requestId) async {
    final docRef = _firestore
        .collection(_collection)
        .doc(userId)
        .collection('requests')
        .doc(requestId);

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
        requestId: requestId,
        status: 'error',
        errorMessage: 'Timeout waiting for plan',
      ));
    });

    sub = docRef.snapshots().listen((snap) {
      if (!snap.exists) return;
      final data = snap.data();
      if (data == null) return;
      final result = RevisionPlanResult.fromFirestore(data);
      if (result.status == 'completed' || result.status == 'error') {
        finish(result);
      }
    });

    return completer.future;
  }

  /// Generate a unique request id for this user.
  String generateRequestId() {
    final u = _userId ?? 'anon';
    final t = DateTime.now().millisecondsSinceEpoch;
    return '${u.substring(0, u.length > 8 ? 8 : u.length)}_$t';
  }

  /// Full flow: send request to n8n, then wait for Firebase result.
  Future<RevisionPlanResult> generatePlan(RevisionPlanRequest request) async {
    await sendToN8n(request);
    return waitForPlan(request.userId, request.requestId);
  }
}
