import '../services/revision_plan_service.dart';

/// User-facing copy for revision plan / n8n / Gemini failures.
class RevisionPlanErrors {
  RevisionPlanErrors._();

  static const String aiUnavailable =
      'The AI planner is temporarily unavailable. Please try again later.';

  static const String networkUnreachable =
      'Could not reach the study plan service. Check your internet connection and try again.';

  static const String planTimedOut =
      'Your revision plan could not be completed in time. The AI service may be busy—please try again in a few minutes.';

  static const String rescheduleTimedOut =
      'Rescheduling is taking too long. Please check your connection and try again in a few minutes.';

  static const String planGenerationFailed =
      'We could not create your revision plan. Please try again.';

  static const String rescheduleFailed =
      'We could not reschedule your overdue tasks. Please try again.';

  static const String webhookRejected =
      'The study plan service rejected the request. Please try again later.';

  /// Maps thrown errors from [RevisionPlanService.sendToN8n] and webhooks.
  static String fromException(Object error) {
    final raw = error.toString();
    final lower = raw.toLowerCase();

    if (error is Exception) {
      final msg = raw.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
      if (_looksUserReady(msg)) return msg;
    }

    if (lower.contains('timeoutexception') ||
        lower.contains('timed out') ||
        lower.contains('timeout waiting')) {
      return networkUnreachable;
    }
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection refused') ||
        lower.contains('network is unreachable') ||
        lower.contains('clientexception')) {
      return networkUnreachable;
    }
    if (lower.contains('webhook failed')) {
      return _fromWebhookStatusLine(raw);
    }
    if (lower.contains('configure n8n webhook')) {
      return 'Study plan service is not configured. Please contact support.';
    }

    return fromBackendMessage(raw) ?? planGenerationFailed;
  }

  /// Maps [RevisionPlanResult] after Firestore listen (n8n may set errorMessage).
  static String forResult(RevisionPlanResult result, {bool isReschedule = false}) {
    if (result.status != 'error') return '';

    final raw = result.errorMessage?.trim();
    if (raw == null || raw.isEmpty) {
      return isReschedule ? rescheduleFailed : planGenerationFailed;
    }

    if (lowerEquals(raw, 'timeout waiting for plan')) {
      return planTimedOut;
    }
    if (raw.toLowerCase().contains('reschedule is taking too long')) {
      return rescheduleTimedOut;
    }

    return fromBackendMessage(raw) ??
        (_looksUserReady(raw)
            ? raw
            : (isReschedule ? rescheduleFailed : planGenerationFailed));
  }

  /// Normalizes messages written by n8n (Gemini, HTTP, etc.).
  static String? fromBackendMessage(String? raw) {
    if (raw == null) return null;
    final text = raw.trim();
    if (text.isEmpty) return null;
    if (_looksUserReady(text) && !_looksTechnical(text)) return text;

    final lower = text.toLowerCase();

    if (lower.contains('server not found') ||
        lower.contains('service unavailable') ||
        lower.contains('503') ||
        lower.contains('502') ||
        lower.contains('504') ||
        lower.contains('bad gateway') ||
        lower.contains('overloaded') ||
        lower.contains('resource exhausted')) {
      return aiUnavailable;
    }
    if (lower.contains('gemini') ||
        lower.contains('generative') ||
        lower.contains('google ai') ||
        lower.contains('api key') ||
        lower.contains('quota') ||
        lower.contains('rate limit') ||
        lower.contains('model')) {
      return aiUnavailable;
    }
    if (lower.contains('webhook') && lower.contains('failed')) {
      return _fromWebhookStatusLine(text);
    }
    if (lower.contains('timeout') || lower.contains('timed out')) {
      return planTimedOut;
    }
    if (lower.contains('network') ||
        lower.contains('connection') ||
        lower.contains('host lookup') ||
        lower.contains('unreachable')) {
      return networkUnreachable;
    }
    if (lower.contains('unauthorized') ||
        lower.contains('forbidden') ||
        lower.contains('401') ||
        lower.contains('403')) {
      return 'The study plan service could not be authorized. Please try again later.';
    }
    if (lower.contains('not found') || lower.contains('404')) {
      return 'The study plan service is not available right now. Please try again later.';
    }

    return null;
  }

  static String _fromWebhookStatusLine(String raw) {
    final codeMatch = RegExp(r'\b([45]\d{2})\b').firstMatch(raw);
    final code = codeMatch != null ? int.tryParse(codeMatch.group(1)!) : null;
    if (code == null) return webhookRejected;
    if (code == 404) {
      return 'The study plan service is not available right now. Please try again later.';
    }
    if (code == 408 || code == 504) return planTimedOut;
    if (code == 502 || code == 503) return aiUnavailable;
    if (code >= 500) return aiUnavailable;
    if (code >= 400) return webhookRejected;
    return webhookRejected;
  }

  static bool _looksUserReady(String msg) {
    if (msg.length > 220) return false;
    if (msg.contains('\n')) return false;
    return !_looksTechnical(msg);
  }

  static bool _looksTechnical(String msg) {
    final lower = msg.toLowerCase();
    return lower.contains('stacktrace') ||
        lower.contains('dart:') ||
        lower.contains('package:') ||
        lower.contains('revisionplans/') ||
        lower.contains('dailytasks when finished');
  }

  static bool lowerEquals(String a, String b) =>
      a.toLowerCase() == b.toLowerCase();
}
