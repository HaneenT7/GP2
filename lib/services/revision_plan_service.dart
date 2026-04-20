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
  // 1. Get the status and make it lowercase
  String rawStatus = (data['status'] as String? ?? 'pending').toLowerCase();

  // 2. SAFETY CHECK: If 'status' is missing but 'dailyTasks' is present, 
  // it means n8n finished the job but didn't write the status field yet.
  if (rawStatus == 'pending' && data.containsKey('dailyTasks')) {
    rawStatus = 'completed';
  }

  return RevisionPlanResult(
    // In your screenshot, the field is named 'planId', not 'requestId'
    requestId: data['planId'] as String? ?? data['requestId'] as String? ?? '', 
    status: rawStatus,
    planContent: data['planContent'] as String?,
    errorMessage: data['errorMessage'] as String?,
    completedAt: data['completedAt'] != null
        ? (data['completedAt'] is Timestamp
            ? (data['completedAt'] as Timestamp).toDate()
            : DateTime.tryParse(data['completedAt'].toString()))
        : null,
  );
}}

/// Service to trigger revision plan generation via n8n (Gemini) and read result from Firebase.
class RevisionPlanService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  static const String _collection = 'revisionPlans';
  
  // 1. INCREASE THIS: Change from 120 to 600 (10 minutes)
  // This gives Gemini plenty of time to read files and generate the plan.
  static const Duration _listenTimeout = Duration(minutes: 10);

  Future<void> sendToN8n(RevisionPlanRequest request) async {
    final uri = Uri.parse(n8nRevisionPlanWebhookUrl);
    // ... validation code ...

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: utf8.encode(jsonEncode(request.toJson())),
    ).timeout(const Duration(seconds: 60)); // 2. INCREASE THIS: to 60 seconds

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Webhook failed: ${response.statusCode}');
    }
  }

  /// Listen for the plan document written by n8n. Completes when status is 'completed' or 'error', or on timeout.
  /// n8n writes to revisionPlans/{requestId} (no subcollection) so we listen at that path.
Future<RevisionPlanResult> waitForPlan(String userId, String requestId) async {
  final docRef = _firestore.collection(_collection).doc(requestId);
  final completer = Completer<RevisionPlanResult>();
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? sub;
  Timer? timeoutTimer;

  void finish(RevisionPlanResult result) {
    if (!completer.isCompleted) {
      print("DEBUG: Finishing with status: ${result.status}");
      sub?.cancel();
      timeoutTimer?.cancel();
      completer.complete(result);
    }
  }

  // 1. Immediate Check: Did n8n already finish before we started listening?
  final initialDoc = await docRef.get();
  if (initialDoc.exists) {
    final result = RevisionPlanResult.fromFirestore(initialDoc.data()!);
    if (result.status == 'completed' || result.status == 'error') {
      print("DEBUG: Found existing completed document immediately.");
      return result; // Stop right here, we are done!
    }
  }

  // 2. Set the 10-minute timeout
  timeoutTimer = Timer(_listenTimeout, () {
    finish(RevisionPlanResult(
      requestId: requestId,
      status: 'error',
      errorMessage: 'Timeout waiting for plan',
    ));
  });

  // 3. Listen for future changes (or the first creation)
  sub = docRef.snapshots(includeMetadataChanges: true).listen((snap) {
    if (!snap.exists) return;

    final data = snap.data();
    if (data == null) return;

    final result = RevisionPlanResult.fromFirestore(data);
    print("DEBUG: Stream detected update. Status: ${result.status}");

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
