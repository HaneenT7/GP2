import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// Payload sent to n8n webhook.
class RevisionPlanRequest {
  final String userId;
  final String requestId;
  final String folderId;
  final String folderName;
  final String examDateIso;
  final List<String> selectedFileIds;
  final List<String> selectedFileNames;
  final List<String> selectedFileUrls;

  RevisionPlanRequest({
    required this.userId,
    required this.requestId,
    required this.folderId,
    required this.folderName,
    required this.examDateIso,
    required this.selectedFileIds,
    required this.selectedFileNames,
    required this.selectedFileUrls,
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'requestId': requestId,
        'folderId': folderId,
        'folderName': folderName,
        'examDate': examDateIso,
        'selectedFileIds': selectedFileIds,
        'selectedFileNames': selectedFileNames,
        'fileUrls': selectedFileUrls,
      };
}

/// Result written by n8n to Firestore.
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
    String rawStatus =
        (data['status'] as String? ?? 'pending').toLowerCase();

    if (rawStatus == 'pending' && data.containsKey('dailyTasks')) {
      rawStatus = 'completed';
    }

    return RevisionPlanResult(
      requestId: data['planId'] as String? ??
          data['requestId'] as String? ??
          '',
      status: rawStatus,
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

class RevisionPlanService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  static const String _collection = 'revisionPlans';
  static const Duration _listenTimeout = Duration(minutes: 10);

  // ─────────────────────────────────────────
  // STEP 1 — Just send to n8n, return immediately.
  // Call this from SetUpRevPlan so the form can
  // close right away without waiting.
  // ─────────────────────────────────────────
  Future<void> sendToN8n(RevisionPlanRequest request) async {
    final uri = Uri.parse(n8nRevisionPlanWebhookUrl);

    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: utf8.encode(jsonEncode(request.toJson())),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Webhook failed: ${response.statusCode}');
    }
  }

  // ─────────────────────────────────────────
  // STEP 2 — Listen for the Firestore result.
  // Call this from RevPlanPage in the background
  // after the form closes. Calls onCompleted when
  // n8n finishes writing the plan.
  // ─────────────────────────────────────────
  void listenForPlan({
    required String requestId,
    required void Function(RevisionPlanResult result) onCompleted,
  }) {
    final docRef = _firestore.collection(_collection).doc(requestId);
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? sub;
    Timer? timeoutTimer;

    void finish(RevisionPlanResult result) {
      sub?.cancel();
      timeoutTimer?.cancel();
      onCompleted(result);
    }

    // Immediate check — did n8n already finish?
    docRef.get().then((initialDoc) {
      if (initialDoc.exists) {
        final result =
            RevisionPlanResult.fromFirestore(initialDoc.data()!);
        if (result.status == 'completed' ||
            result.status == 'error') {
          finish(result);
          return;
        }
      }

      // Set timeout
      timeoutTimer = Timer(_listenTimeout, () {
        finish(RevisionPlanResult(
          requestId: requestId,
          status: 'error',
          errorMessage: 'Timeout waiting for plan',
        ));
      });

      // Listen for changes
      sub = docRef
          .snapshots(includeMetadataChanges: true)
          .listen((snap) {
        if (!snap.exists || snap.data() == null) return;
        final result =
            RevisionPlanResult.fromFirestore(snap.data()!);
        if (result.status == 'completed' ||
            result.status == 'error') {
          finish(result);
        }
      });
    });
  }

  // ─────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────

  String generateRequestId() {
    final u = _userId ?? 'anon';
    final t = DateTime.now().millisecondsSinceEpoch;
    return '${u.substring(0, u.length > 8 ? 8 : u.length)}_$t';
  }

  /// Old combined method — kept for backwards compatibility.
  /// Prefer sendToN8n + listenForPlan separately for the new flow.
  Future<RevisionPlanResult> generatePlan(
      RevisionPlanRequest request) async {
    await sendToN8n(request);
    final completer = Completer<RevisionPlanResult>();
    listenForPlan(
      requestId: request.requestId,
      onCompleted: completer.complete,
    );
    return completer.future;
  }
}