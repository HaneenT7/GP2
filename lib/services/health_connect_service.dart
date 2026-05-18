import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:health/health.dart';

class HeartRateReading {
  const HeartRateReading({
    required this.type,
    required this.bpm,
    required this.recordedAt,
    required this.source,
  });

  final String type;
  final double bpm;
  final DateTime recordedAt;
  final String source;
}

class BloodPressureReading {
  const BloodPressureReading({
    required this.systolic,
    required this.diastolic,
    required this.recordedAt,
    required this.source,
  });

  final double systolic;
  final double diastolic;
  final DateTime recordedAt;
  final String source;
}

class HealthConnectProbe {
  const HealthConnectProbe({
    required this.heartRateRecords,
    required this.sampleCount,
    required this.restingRecords,
    required this.sources,
    required this.grantedPermissions,
  });

  final int heartRateRecords;
  final int sampleCount;
  final int restingRecords;
  final List<String> sources;
  final List<String> grantedPermissions;

  bool get hasSamsungHealthSource {
    return sources.any((source) => isSamsungHealthSource(source));
  }

  bool get hasGoogleFitSource {
    return sources.any((source) => isGoogleFitSource(source));
  }

  bool get hasOnlyWatadSource {
    return sources.isNotEmpty &&
        sources.every((source) => source.contains('gp2_watad'));
  }
}

class HealthHeartRateFetchResult {
  const HealthHeartRateFetchResult({
    required this.readings,
    required this.grantedPermissions,
    required this.historyAuthorized,
    required this.searchStart,
    required this.searchEnd,
    this.errorMessage,
    this.probe,
  });

  final List<HeartRateReading> readings;
  final List<String> grantedPermissions;
  final bool historyAuthorized;
  final DateTime searchStart;
  final DateTime searchEnd;
  final String? errorMessage;
  final HealthConnectProbe? probe;

  bool get hasHeartRatePermission {
    return grantedPermissions.any(
      (permission) =>
          permission.contains('READ_HEART_RATE') ||
          permission.contains('READ_RESTING_HEART_RATE'),
    );
  }

  String get statusMessage => _buildHeartRateStatus(
        readings: readings,
        grantedPermissions: grantedPermissions,
        historyAuthorized: historyAuthorized,
        searchStart: searchStart,
        searchEnd: searchEnd,
        errorMessage: errorMessage,
        probe: probe,
      );
}

class LatestVitalsSnapshot {
  const LatestVitalsSnapshot({
    this.heartRate,
    this.bloodPressure,
    this.recentHeartRates = const [],
    this.recentBloodPressures = const [],
    this.errorMessage,
  });

  final HeartRateReading? heartRate;
  final BloodPressureReading? bloodPressure;
  final List<HeartRateReading> recentHeartRates;
  final List<BloodPressureReading> recentBloodPressures;
  final String? errorMessage;
}

class HealthBloodPressureFetchResult {
  const HealthBloodPressureFetchResult({
    required this.readings,
    required this.grantedPermissions,
    required this.historyAuthorized,
    required this.searchStart,
    required this.searchEnd,
    this.errorMessage,
  });

  final List<BloodPressureReading> readings;
  final List<String> grantedPermissions;
  final bool historyAuthorized;
  final DateTime searchStart;
  final DateTime searchEnd;
  final String? errorMessage;

  bool get hasBloodPressurePermission {
    return grantedPermissions.any(
      (permission) => permission.contains('READ_BLOOD_PRESSURE'),
    );
  }

  String get statusMessage {
    if (errorMessage != null) {
      return errorMessage!;
    }
    if (readings.isNotEmpty) {
      final sources = readings
          .map((r) => formatHealthSourceLabel(r.source))
          .toSet()
          .toList()
        ..sort();
      return 'Loaded ${readings.length} blood pressure reading(s) (${sources.join(', ')}).';
    }
    if (!hasBloodPressurePermission) {
      return 'Allow blood pressure read access for WATAD in Health Connect, then tap Load health data.';
    }
    if (!historyAuthorized) {
      return 'Allow past health data for WATAD in Health Connect, then try again.';
    }
    return 'No blood pressure between ${_formatDate(searchStart)} and ${_formatDate(searchEnd)}. '
        'Check Health Connect → Browse data → Blood pressure, and Samsung Health or Google Fit sharing.';
  }
}

bool isSamsungHealthSource(String source) => source.contains('shealth');

/// Matches package ids and display names Health Connect / Google Fit may use.
bool isGoogleFitSource(String source) {
  final lower = source.toLowerCase();
  const googlePackages = [
    'com.google.android.apps.fitness',
    'com.google.android.gms',
    'com.google.android.apps.wear',
    'com.google.android.wearable',
  ];
  if (googlePackages.any(lower.contains)) return true;
  if (lower.contains('google fit') || lower.contains('googlefit')) return true;
  if (lower.contains('google') && lower.contains('fitness')) return true;
  return false;
}

String healthPointSourceLabel(HealthDataPoint point) {
  final id = point.sourceId.trim();
  final name = point.sourceName.trim();
  if (id.isNotEmpty && name.isNotEmpty && id != name) {
    return '$id|$name';
  }
  if (id.isNotEmpty) return id;
  if (name.isNotEmpty) return name;
  return 'Health Connect';
}

String formatHealthSourceLabel(String source) {
  if (isSamsungHealthSource(source)) {
    return 'Samsung Health';
  }
  if (isGoogleFitSource(source)) {
    return 'Google Fit';
  }
  if (source.contains('gp2_watad')) {
    return 'WATAD';
  }
  if (source.contains('healthdata') || source.contains('health.connect')) {
    return 'Health Connect';
  }
  return source;
}

String _buildHeartRateStatus({
  required List<HeartRateReading> readings,
  required List<String> grantedPermissions,
  required bool historyAuthorized,
  required DateTime searchStart,
  required DateTime searchEnd,
  String? errorMessage,
  HealthConnectProbe? probe,
}) {
  if (errorMessage != null) {
    return errorMessage;
  }
  if (readings.isNotEmpty) {
    final sources = readings
        .map((reading) => formatHealthSourceLabel(reading.source))
        .toSet()
        .toList()
      ..sort();
    return 'Loaded ${readings.length} heart rate reading(s) (${sources.join(', ')}).';
  }
  if (!grantedPermissions.any(
    (p) => p.contains('READ_HEART_RATE') || p.contains('READ_RESTING_HEART_RATE'),
  )) {
    return 'Allow heart rate read access for WATAD in Health Connect.';
  }
  final probeInfo = probe;
  if (probeInfo != null) {
    if (probeInfo.sampleCount == 0 && probeInfo.restingRecords == 0) {
      return 'No heart rate in Health Connect. Enable sharing from Samsung Health or Google Fit in Health Connect app permissions.';
    }
    if (probeInfo.hasOnlyWatadSource) {
      return 'Heart rate in Health Connect is only from WATAD. Enable Samsung Health or Google Fit sharing in Health Connect.';
    }
  }
  if (!historyAuthorized) {
    return 'Allow past health data for WATAD in Health Connect.';
  }
  return 'No heart rate between ${_formatDate(searchStart)} and ${_formatDate(searchEnd)}.';
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

class HealthConnectService {
  HealthConnectService() : _health = Health();

  static const MethodChannel _nativeChannel = MethodChannel(
    'com.example.gp2_watad/health_connect',
  );

  final Health _health;
  bool _configured = false;

  static const List<HealthDataType> heartRateTypes = [
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
  ];
  static const List<HealthDataType> bloodPressureTypes = [
    HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
    HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
  ];
  static List<HealthDataType> get allHealthTypes => [
        ...heartRateTypes,
        ...bloodPressureTypes,
      ];
  static List<HealthDataAccess> get allHealthReadPermissions => List.filled(
        allHealthTypes.length,
        HealthDataAccess.READ,
      );

  Future<void> _ensureConfigured({bool force = false}) async {
    if (_configured && !force) return;
    await _health.configure();
    _configured = true;
  }

  /// Forces the health plugin to re-bind on the next read (fresher vitals refresh).
  Future<void> invalidateHealthPluginCache() async {
    _configured = false;
  }

  Future<HealthConnectSdkStatus?> getSdkStatus() async {
    await _ensureConfigured();
    return _health.getHealthConnectSdkStatus();
  }

  Future<void> openHealthConnectInstall() async {
    await _ensureConfigured();
    await _health.installHealthConnect();
  }

  Future<void> openHealthConnectPermissions() async {
    if (!Platform.isAndroid) return;
    await _nativeChannel.invokeMethod<void>('openPermissions');
  }

  Future<void> openSamsungHealth() async {
    if (!Platform.isAndroid) return;
    await _nativeChannel.invokeMethod<void>('openSamsungHealth');
  }

  Future<void> openGoogleFit() async {
    if (!Platform.isAndroid) return;
    await _nativeChannel.invokeMethod<void>('openGoogleFit');
  }

  Future<bool> requestHealthAccess() async {
    await _ensureConfigured();
    final authorized = await _health.requestAuthorization(
      allHealthTypes,
      permissions: allHealthReadPermissions,
    );
    await _health.requestHealthDataHistoryAuthorization();
    if (authorized) return true;
    final granted = await _getGrantedPermissions();
    return granted.any(
      (p) =>
          p.contains('READ_HEART_RATE') || p.contains('READ_BLOOD_PRESSURE'),
    );
  }

  Future<bool> requestHeartRateAccess() => requestHealthAccess();

  Future<List<String>> _getGrantedPermissions() async {
    if (!Platform.isAndroid) return const [];
    final permissions = await _nativeChannel.invokeMethod<List<dynamic>>(
      'getGrantedPermissions',
    );
    return permissions?.map((p) => p.toString()).toList() ?? const [];
  }

  Future<bool> isHistoryAuthorized() async {
    await _ensureConfigured();
    return _health.isHealthDataHistoryAuthorized();
  }

  /// Reads the newest heart rate / blood pressure from Health Connect (last [lookback]).
  Future<LatestVitalsSnapshot> fetchLatestVitals({
    Duration lookback = const Duration(hours: 48),
  }) async {
    await invalidateHealthPluginCache();
    await _ensureConfigured(force: true);

    final ctx = await _prepareFetchContext(lookback);
    if (ctx.error != null) {
      return LatestVitalsSnapshot(errorMessage: ctx.error);
    }

    try {
      HeartRateReading? latestHr;
      BloodPressureReading? latestBp;

      if (Platform.isAndroid) {
        final raw = await _nativeChannel.invokeMethod<dynamic>(
          'readLatestVitals',
          {'hours': lookback.inHours.clamp(1, 168)},
        );
        if (raw is Map) {
          final map = Map<String, dynamic>.from(raw);
          latestHr = _parseHeartRateMap(map['heartRate']);
          latestBp = _parseBloodPressureMap(map['bloodPressure']);
        }
      }

      final nativeHr =
          await _fetchHeartRateFromNative(ctx.start, ctx.end);
      final pluginHr =
          await _fetchHeartRateFromPlugin(ctx.start, ctx.end);
      final mergedHr = _mergeHeartRateReadings(nativeHr, pluginHr);

      final nativeBp =
          await _fetchBloodPressureFromNative(ctx.start, ctx.end);
      final pluginBp =
          await _fetchBloodPressureFromPlugin(ctx.start, ctx.end);
      final mergedBp = _mergeBloodPressureReadings(nativeBp, pluginBp);

      latestHr = _pickNewestHeartRate([
        latestHr,
        if (mergedHr.isNotEmpty) mergedHr.first,
      ]);
      latestBp = _pickNewestBloodPressure([
        latestBp,
        if (mergedBp.isNotEmpty) mergedBp.first,
      ]);

      if (kDebugMode) {
        debugPrint(
          'Latest vitals: HR=${latestHr?.bpm} @ ${latestHr?.recordedAt} '
          'src=${latestHr?.source} | BP=${latestBp?.systolic}/${latestBp?.diastolic}',
        );
      }

      return LatestVitalsSnapshot(
        heartRate: latestHr,
        bloodPressure: latestBp,
        recentHeartRates: mergedHr,
        recentBloodPressures: mergedBp,
      );
    } on PlatformException catch (error) {
      return LatestVitalsSnapshot(
        errorMessage: 'Could not read latest vitals: ${error.message}',
      );
    }
  }

  Future<HealthHeartRateFetchResult> fetchHeartRate({
    Duration lookback = const Duration(days: 365),
  }) async {
    final ctx = await _prepareFetchContext(lookback);
    if (ctx.error != null) {
      return HealthHeartRateFetchResult(
        readings: const [],
        grantedPermissions: ctx.grantedPermissions,
        historyAuthorized: ctx.historyAuthorized,
        searchStart: ctx.start,
        searchEnd: ctx.end,
        errorMessage: ctx.error,
      );
    }

    try {
      final nativeReadings =
          await _fetchHeartRateFromNative(ctx.start, ctx.end);
      final pluginReadings =
          await _fetchHeartRateFromPlugin(ctx.start, ctx.end);
      final readings = _mergeHeartRateReadings(nativeReadings, pluginReadings);

      HealthConnectProbe? probe;
      if (readings.isEmpty) {
        probe = await _probeHeartRate(ctx.start, ctx.end);
      }

      return HealthHeartRateFetchResult(
        readings: readings,
        grantedPermissions: ctx.grantedPermissions,
        historyAuthorized: ctx.historyAuthorized,
        searchStart: ctx.start,
        searchEnd: ctx.end,
        probe: probe,
      );
    } on PlatformException catch (error) {
      return HealthHeartRateFetchResult(
        readings: const [],
        grantedPermissions: ctx.grantedPermissions,
        historyAuthorized: ctx.historyAuthorized,
        searchStart: ctx.start,
        searchEnd: ctx.end,
        errorMessage: 'Could not read heart rate: ${error.message}',
      );
    }
  }

  Future<HealthBloodPressureFetchResult> fetchBloodPressure({
    Duration lookback = const Duration(days: 365),
  }) async {
    final ctx = await _prepareFetchContext(lookback);
    if (ctx.error != null) {
      return HealthBloodPressureFetchResult(
        readings: const [],
        grantedPermissions: ctx.grantedPermissions,
        historyAuthorized: ctx.historyAuthorized,
        searchStart: ctx.start,
        searchEnd: ctx.end,
        errorMessage: ctx.error,
      );
    }

    try {
      final nativeReadings =
          await _fetchBloodPressureFromNative(ctx.start, ctx.end);
      final pluginReadings =
          await _fetchBloodPressureFromPlugin(ctx.start, ctx.end);
      final readings =
          _mergeBloodPressureReadings(nativeReadings, pluginReadings);

      if (kDebugMode) {
        debugPrint('Blood pressure total readings=${readings.length}');
      }

      return HealthBloodPressureFetchResult(
        readings: readings,
        grantedPermissions: ctx.grantedPermissions,
        historyAuthorized: ctx.historyAuthorized,
        searchStart: ctx.start,
        searchEnd: ctx.end,
      );
    } on PlatformException catch (error) {
      return HealthBloodPressureFetchResult(
        readings: const [],
        grantedPermissions: ctx.grantedPermissions,
        historyAuthorized: ctx.historyAuthorized,
        searchStart: ctx.start,
        searchEnd: ctx.end,
        errorMessage: 'Could not read blood pressure: ${error.message}',
      );
    }
  }

  Future<_FetchContext> _prepareFetchContext(Duration lookback) async {
    await _ensureConfigured();
    var grantedPermissions = await _getGrantedPermissions();
    var historyAuthorized = await isHistoryAuthorized();
    final end = DateTime.now();
    final start = end.subtract(lookback);

    if (!Platform.isAndroid) {
      return _FetchContext(
        start: start,
        end: end,
        grantedPermissions: grantedPermissions,
        historyAuthorized: historyAuthorized,
        error: 'Health Connect is only available on Android.',
      );
    }

    final sdkStatus = await getSdkStatus();
    if (sdkStatus != HealthConnectSdkStatus.sdkAvailable) {
      return _FetchContext(
        start: start,
        end: end,
        grantedPermissions: grantedPermissions,
        historyAuthorized: historyAuthorized,
        error:
            'Health Connect is not available. Install or update it from the Play Store.',
      );
    }

    final needsPermission = !grantedPermissions.any(
      (p) =>
          p.contains('READ_HEART_RATE') || p.contains('READ_BLOOD_PRESSURE'),
    );
    if (needsPermission) {
      await requestHealthAccess();
      grantedPermissions = await _getGrantedPermissions();
      historyAuthorized = await isHistoryAuthorized();
    }

    return _FetchContext(
      start: start,
      end: end,
      grantedPermissions: grantedPermissions,
      historyAuthorized: historyAuthorized,
    );
  }

  Future<HealthConnectProbe?> _probeHeartRate(
    DateTime start,
    DateTime end,
  ) async {
    final raw = await _nativeChannel.invokeMethod<dynamic>(
      'probeHeartRate',
      {
        'startMs': start.millisecondsSinceEpoch,
        'endMs': end.millisecondsSinceEpoch,
      },
    );
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final sources = map['sources'];
    return HealthConnectProbe(
      heartRateRecords: _asInt(map['heartRateRecords']),
      sampleCount: _asInt(map['sampleCount']),
      restingRecords: _asInt(map['restingRecords']),
      sources: sources is List
          ? sources.map((v) => v.toString()).toList()
          : const [],
      grantedPermissions: map['grantedPermissions'] is List
          ? (map['grantedPermissions'] as List).map((v) => v.toString()).toList()
          : const [],
    );
  }

  int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Future<List<HeartRateReading>> _fetchHeartRateFromNative(
    DateTime start,
    DateTime end,
  ) async {
    final raw = await _nativeChannel.invokeMethod<dynamic>(
      'readHeartRate',
      {
        'startMs': start.millisecondsSinceEpoch,
        'endMs': end.millisecondsSinceEpoch,
      },
    );
    if (raw is! List) return const [];
    final readings = <HeartRateReading>[];
    for (final item in raw) {
      final reading = _parseHeartRateMap(item);
      if (reading != null) readings.add(reading);
    }
    readings.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    if (kDebugMode) {
      debugPrint(
        'HR native raw=${raw.length} parsed=${readings.length}',
      );
    }
    return readings;
  }

  Future<List<BloodPressureReading>> _fetchBloodPressureFromNative(
    DateTime start,
    DateTime end,
  ) async {
    final raw = await _nativeChannel.invokeMethod<dynamic>(
      'readBloodPressure',
      {
        'startMs': start.millisecondsSinceEpoch,
        'endMs': end.millisecondsSinceEpoch,
      },
    );
    if (raw is! List) return const [];
    final readings = <BloodPressureReading>[];
    for (final item in raw) {
      final reading = _parseBloodPressureMap(item);
      if (reading != null) readings.add(reading);
    }
    readings.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    if (kDebugMode) {
      debugPrint(
        'BP native raw=${raw.length} parsed=${readings.length}',
      );
    }
    return readings;
  }

  Future<List<HeartRateReading>> _fetchHeartRateFromPlugin(
    DateTime start,
    DateTime end,
  ) async {
    try {
      final points = await _health.getHealthDataFromTypes(
        types: heartRateTypes,
        startTime: start,
        endTime: end,
      );
      final readings = <HeartRateReading>[];
      for (final point in points) {
        final reading = _parseHeartRatePoint(point);
        if (reading != null) readings.add(reading);
      }
      if (kDebugMode) {
        debugPrint('HR plugin: ${points.length} pts, ${readings.length} parsed');
      }
      return readings;
    } catch (e) {
      if (kDebugMode) debugPrint('HR plugin failed: $e');
      return const [];
    }
  }

  Future<List<BloodPressureReading>> _fetchBloodPressureFromPlugin(
    DateTime start,
    DateTime end,
  ) async {
    try {
      final points = await _health.getHealthDataFromTypes(
        types: bloodPressureTypes,
        startTime: start,
        endTime: end,
      );
      final systolic = <int, double>{};
      final diastolic = <int, double>{};
      final sources = <int, String>{};

      for (final point in points) {
        final mmHg = _numericValueFromPoint(point);
        if (mmHg == null || mmHg <= 0) continue;
        final key = point.dateTo.millisecondsSinceEpoch;
        sources[key] = healthPointSourceLabel(point);
        if (point.type == HealthDataType.BLOOD_PRESSURE_SYSTOLIC) {
          systolic[key] = mmHg;
        } else {
          diastolic[key] = mmHg;
        }
      }

      final readings = <BloodPressureReading>[];
      for (final key in {...systolic.keys, ...diastolic.keys}) {
        final sys = systolic[key];
        final dia = diastolic[key];
        if (sys != null && dia != null) {
          readings.add(
            BloodPressureReading(
              systolic: sys,
              diastolic: dia,
              recordedAt: DateTime.fromMillisecondsSinceEpoch(key),
              source: sources[key] ?? 'Health Connect',
            ),
          );
        }
      }
      readings.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
      if (kDebugMode) {
        debugPrint('BP plugin: ${points.length} pts, ${readings.length} parsed');
      }
      return readings;
    } catch (e) {
      if (kDebugMode) debugPrint('BP plugin failed: $e');
      return const [];
    }
  }

  HeartRateReading? _parseHeartRateMap(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final timestamp = _asInt(map['recordedAtMs']);
    final bpm = _asDouble(map['bpm']);
    if (timestamp == 0 || bpm == null || bpm <= 0) return null;
    return HeartRateReading(
      type: map['type']?.toString() ?? 'HEART_RATE',
      bpm: bpm,
      recordedAt: DateTime.fromMillisecondsSinceEpoch(timestamp),
      source: map['source']?.toString() ?? 'Health Connect',
    );
  }

  BloodPressureReading? _parseBloodPressureMap(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final timestamp = _asInt(map['recordedAtMs']);
    final systolic = _asDouble(map['systolic']);
    final diastolic = _asDouble(map['diastolic']);
    if (timestamp == 0 ||
        systolic == null ||
        diastolic == null ||
        systolic <= 0 ||
        diastolic <= 0) {
      return null;
    }
    return BloodPressureReading(
      systolic: systolic,
      diastolic: diastolic,
      recordedAt: DateTime.fromMillisecondsSinceEpoch(timestamp),
      source: map['source']?.toString() ?? 'Health Connect',
    );
  }

  HeartRateReading? _parseHeartRatePoint(HealthDataPoint point) {
    final bpm = _numericValueFromPoint(point);
    if (bpm == null || bpm <= 0) return null;
    final type = switch (point.type) {
      HealthDataType.RESTING_HEART_RATE => 'RESTING_HEART_RATE',
      _ => 'HEART_RATE',
    };
    final source = healthPointSourceLabel(point);
    final recordedAt = point.dateTo.isAfter(point.dateFrom)
        ? point.dateTo
        : point.dateFrom;
    return HeartRateReading(
      type: type,
      bpm: bpm,
      recordedAt: recordedAt,
      source: source,
    );
  }

  HeartRateReading? _pickNewestHeartRate(List<HeartRateReading?> candidates) {
    HeartRateReading? best;
    for (final candidate in candidates) {
      if (candidate == null) continue;
      if (best == null || candidate.recordedAt.isAfter(best.recordedAt)) {
        best = candidate;
      }
    }
    return best;
  }

  BloodPressureReading? _pickNewestBloodPressure(
    List<BloodPressureReading?> candidates,
  ) {
    BloodPressureReading? best;
    for (final candidate in candidates) {
      if (candidate == null) continue;
      if (best == null || candidate.recordedAt.isAfter(best.recordedAt)) {
        best = candidate;
      }
    }
    return best;
  }

  double? _numericValueFromPoint(HealthDataPoint point) {
    final value = point.value;
    if (value is NumericHealthValue) {
      return value.numericValue.toDouble();
    }
    return double.tryParse(value.toString());
  }

  List<HeartRateReading> _mergeHeartRateReadings(
    List<HeartRateReading> primary,
    List<HeartRateReading> secondary,
  ) {
    final merged = [...primary];
    for (final reading in secondary) {
      final duplicate = merged.any(
        (e) =>
            e.bpm == reading.bpm &&
            e.recordedAt.isAtSameMomentAs(reading.recordedAt),
      );
      if (!duplicate) merged.add(reading);
    }
    merged.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return merged;
  }

  List<BloodPressureReading> _mergeBloodPressureReadings(
    List<BloodPressureReading> primary,
    List<BloodPressureReading> secondary,
  ) {
    final merged = [...primary];
    for (final reading in secondary) {
      final duplicate = merged.any(
        (e) =>
            e.systolic == reading.systolic &&
            e.diastolic == reading.diastolic &&
            e.recordedAt.isAtSameMomentAs(reading.recordedAt),
      );
      if (!duplicate) merged.add(reading);
    }
    merged.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return merged;
  }

  String formatHeartRate(HeartRateReading reading) {
    return '${reading.bpm.toStringAsFixed(0)} bpm';
  }

  String formatBloodPressure(BloodPressureReading reading) {
    return '${reading.systolic.toStringAsFixed(0)}/${reading.diastolic.toStringAsFixed(0)} mmHg';
  }

  String formatSourceLabel(String source) => formatHealthSourceLabel(source);
}

class _FetchContext {
  const _FetchContext({
    required this.start,
    required this.end,
    required this.grantedPermissions,
    required this.historyAuthorized,
    this.error,
  });

  final DateTime start;
  final DateTime end;
  final List<String> grantedPermissions;
  final bool historyAuthorized;
  final String? error;
}
