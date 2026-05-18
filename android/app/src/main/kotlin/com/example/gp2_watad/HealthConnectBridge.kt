package com.example.gp2_watad

import android.content.Intent
import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.BloodPressureRecord
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.RestingHeartRateRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.time.Instant
import java.time.temporal.ChronoUnit
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class HealthConnectBridge(
    private val activity: FlutterFragmentActivity,
    messenger: BinaryMessenger,
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val channel = MethodChannel(messenger, CHANNEL_NAME)

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getGrantedPermissions" -> scope.launch {
                    runCatching {
                        val client = HealthConnectClient.getOrCreate(activity)
                        val permissions = client.permissionController.getGrantedPermissions()
                        result.success(permissions.toList())
                    }.onFailure { error ->
                        Log.e(TAG, "Failed to read granted permissions", error)
                        result.error("health_connect_error", error.message, null)
                    }
                }

                "readHeartRate" -> {
                    val startMs = call.argument<Long>("startMs")
                    val endMs = call.argument<Long>("endMs")
                    if (startMs == null || endMs == null) {
                        result.error("invalid_args", "startMs and endMs are required", null)
                        return@setMethodCallHandler
                    }

                    scope.launch {
                        runCatching {
                            val records = readHeartRate(startMs, endMs)
                            Log.i(TAG, "Returning ${records.size} heart rate record(s)")
                            result.success(records)
                        }.onFailure { error ->
                            Log.e(TAG, "Failed to read heart rate", error)
                            result.error("health_connect_error", error.message, null)
                        }
                    }
                }

                "readBloodPressure" -> {
                    val startMs = call.argument<Long>("startMs")
                    val endMs = call.argument<Long>("endMs")
                    if (startMs == null || endMs == null) {
                        result.error("invalid_args", "startMs and endMs are required", null)
                        return@setMethodCallHandler
                    }

                    scope.launch {
                        runCatching {
                            val records = readBloodPressure(startMs, endMs)
                            Log.i(TAG, "Returning ${records.size} blood pressure record(s)")
                            result.success(records)
                        }.onFailure { error ->
                            Log.e(TAG, "Failed to read blood pressure", error)
                            result.error("health_connect_error", error.message, null)
                        }
                    }
                }

                "openPermissions" -> {
                    runCatching {
                        openHealthConnectPermissions()
                        result.success(true)
                    }.onFailure { error ->
                        Log.e(TAG, "Failed to open Health Connect permissions", error)
                        result.error("health_connect_error", error.message, null)
                    }
                }

                "probeHeartRate" -> {
                    val startMs = call.argument<Long>("startMs")
                    val endMs = call.argument<Long>("endMs")
                    if (startMs == null || endMs == null) {
                        result.error("invalid_args", "startMs and endMs are required", null)
                        return@setMethodCallHandler
                    }

                    scope.launch {
                        runCatching {
                            result.success(probeHeartRate(startMs, endMs))
                        }.onFailure { error ->
                            Log.e(TAG, "Failed to probe heart rate", error)
                            result.error("health_connect_error", error.message, null)
                        }
                    }
                }

                "openSamsungHealth" -> {
                    runCatching {
                        openSamsungHealth()
                        result.success(true)
                    }.onFailure { error ->
                        Log.e(TAG, "Failed to open Samsung Health", error)
                        result.error("health_connect_error", error.message, null)
                    }
                }

                "openGoogleFit" -> {
                    runCatching {
                        openGoogleFit()
                        result.success(true)
                    }.onFailure { error ->
                        Log.e(TAG, "Failed to open Google Fit", error)
                        result.error("health_connect_error", error.message, null)
                    }
                }

                "readLatestVitals" -> {
                    val hours = call.argument<Int>("hours") ?: 48
                    scope.launch {
                        runCatching {
                            result.success(readLatestVitals(hours))
                        }.onFailure { error ->
                            Log.e(TAG, "Failed to read latest vitals", error)
                            result.error("health_connect_error", error.message, null)
                        }
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    private suspend fun readHeartRate(startMs: Long, endMs: Long): List<Map<String, Any?>> =
        withContext(Dispatchers.IO) {
            val client = HealthConnectClient.getOrCreate(activity)
            val start = Instant.ofEpochMilli(startMs)
            val end = Instant.ofEpochMilli(endMs)
            val results = mutableListOf<Map<String, Any?>>()

            appendHeartRateRecords(client, start, end, results)
            appendRestingHeartRateRecords(client, start, end, results)

            results.sortedByDescending { (it["recordedAtMs"] as Number).toLong() }
        }

    private suspend fun readBloodPressure(startMs: Long, endMs: Long): List<Map<String, Any?>> =
        withContext(Dispatchers.IO) {
            val client = HealthConnectClient.getOrCreate(activity)
            val start = Instant.ofEpochMilli(startMs)
            val end = Instant.ofEpochMilli(endMs)
            val results = mutableListOf<Map<String, Any?>>()
            appendBloodPressureRecords(client, start, end, results)
            results.sortedByDescending { (it["recordedAtMs"] as Number).toLong() }
        }

    private fun openHealthConnectPermissions() {
        val intent = Intent("androidx.health.ACTION_HEALTH_CONNECT_SETTINGS")
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        activity.startActivity(intent)
    }

    private fun openSamsungHealth() {
        openExternalApp(
            packages = listOf(
                "com.sec.android.app.shealth",
                "com.samsung.android.app.shealth",
            ),
            notInstalledMessage = "Samsung Health is not installed on this device",
        )
    }

    private fun openGoogleFit() {
        openExternalApp(
            packages = listOf(
                "com.google.android.apps.fitness",
            ),
            notInstalledMessage = "Google Fit is not installed on this device",
        )
    }

    private fun openExternalApp(packages: List<String>, notInstalledMessage: String) {
        for (packageName in packages) {
            val intent = activity.packageManager.getLaunchIntentForPackage(packageName)
            if (intent != null) {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                activity.startActivity(intent)
                return
            }
        }
        error(notInstalledMessage)
    }

    private suspend fun probeHeartRate(startMs: Long, endMs: Long): Map<String, Any?> =
        withContext(Dispatchers.IO) {
            val client = HealthConnectClient.getOrCreate(activity)
            val start = Instant.ofEpochMilli(startMs)
            val end = Instant.ofEpochMilli(endMs)
            val sources = linkedSetOf<String>()
            var heartRateRecords = 0
            var sampleCount = 0
            var restingRecords = 0

            var pageToken: String? = null
            do {
                val response = client.readRecords(
                    ReadRecordsRequest(
                        recordType = HeartRateRecord::class,
                        timeRangeFilter = TimeRangeFilter.between(start, end),
                        pageToken = pageToken,
                    ),
                )
                heartRateRecords += response.records.size
                for (record in response.records) {
                    sources.add(record.metadata.dataOrigin.packageName)
                    sampleCount += record.samples.size
                }
                pageToken = response.pageToken
            } while (!pageToken.isNullOrEmpty())

            pageToken = null
            do {
                val response = client.readRecords(
                    ReadRecordsRequest(
                        recordType = RestingHeartRateRecord::class,
                        timeRangeFilter = TimeRangeFilter.between(start, end),
                        pageToken = pageToken,
                    ),
                )
                restingRecords += response.records.size
                for (record in response.records) {
                    sources.add(record.metadata.dataOrigin.packageName)
                }
                pageToken = response.pageToken
            } while (!pageToken.isNullOrEmpty())

            val granted = client.permissionController.getGrantedPermissions()
            Log.i(
                TAG,
                "Probe: $heartRateRecords HR records, $sampleCount samples, " +
                    "$restingRecords resting, sources=$sources",
            )

            mapOf(
                "heartRateRecords" to heartRateRecords,
                "sampleCount" to sampleCount,
                "restingRecords" to restingRecords,
                "sources" to sources.toList(),
                "grantedPermissions" to granted.toList(),
            )
        }

    private suspend fun appendHeartRateRecords(
        client: HealthConnectClient,
        start: Instant,
        end: Instant,
        results: MutableList<Map<String, Any?>>,
    ) {
        var pageToken: String? = null
        do {
            val response = client.readRecords(
                ReadRecordsRequest(
                    recordType = HeartRateRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(start, end),
                    pageToken = pageToken,
                ),
            )
            Log.i(TAG, "Read ${response.records.size} HEART_RATE record(s) from Health Connect")
            for (record in response.records) {
                val sourcePackage = record.metadata.dataOrigin.packageName

                if (record.samples.isEmpty()) {
                    Log.w(
                        TAG,
                        "HEART_RATE record with no samples from $sourcePackage",
                    )
                    continue
                }

                for (sample in record.samples) {
                    Log.i(
                        TAG,
                        "Including HEART_RATE ${sample.beatsPerMinute} bpm from $sourcePackage",
                    )
                    results.add(
                        mapOf(
                            "type" to "HEART_RATE",
                            "bpm" to sample.beatsPerMinute.toDouble(),
                            "recordedAtMs" to sample.time.toEpochMilli(),
                            "source" to sourcePackage,
                        ),
                    )
                }
            }
            pageToken = response.pageToken
        } while (!pageToken.isNullOrEmpty())
    }

    private suspend fun appendBloodPressureRecords(
        client: HealthConnectClient,
        start: Instant,
        end: Instant,
        results: MutableList<Map<String, Any?>>,
    ) {
        var pageToken: String? = null
        do {
            val response = client.readRecords(
                ReadRecordsRequest(
                    recordType = BloodPressureRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(start, end),
                    pageToken = pageToken,
                ),
            )
            Log.i(
                TAG,
                "Read ${response.records.size} BLOOD_PRESSURE record(s) from Health Connect",
            )
            for (record in response.records) {
                val sourcePackage = record.metadata.dataOrigin.packageName
                val systolic = record.systolic.inMillimetersOfMercury
                val diastolic = record.diastolic.inMillimetersOfMercury
                Log.i(
                    TAG,
                    "Including BLOOD_PRESSURE $systolic/$diastolic mmHg from $sourcePackage",
                )
                results.add(
                    mapOf(
                        "systolic" to systolic,
                        "diastolic" to diastolic,
                        "recordedAtMs" to record.time.toEpochMilli(),
                        "source" to sourcePackage,
                    ),
                )
            }
            pageToken = response.pageToken
        } while (!pageToken.isNullOrEmpty())
    }

    private suspend fun appendRestingHeartRateRecords(
        client: HealthConnectClient,
        start: Instant,
        end: Instant,
        results: MutableList<Map<String, Any?>>,
    ) {
        var pageToken: String? = null
        do {
            val response = client.readRecords(
                ReadRecordsRequest(
                    recordType = RestingHeartRateRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(start, end),
                    pageToken = pageToken,
                ),
            )
            Log.i(TAG, "Read ${response.records.size} RESTING_HEART_RATE record(s) from Health Connect")
            for (record in response.records) {
                val sourcePackage = record.metadata.dataOrigin.packageName

                Log.i(
                    TAG,
                    "Including RESTING_HEART_RATE ${record.beatsPerMinute} bpm from $sourcePackage",
                )
                results.add(
                    mapOf(
                        "type" to "RESTING_HEART_RATE",
                        "bpm" to record.beatsPerMinute.toDouble(),
                        "recordedAtMs" to record.time.toEpochMilli(),
                        "source" to sourcePackage,
                    ),
                )
            }
            pageToken = response.pageToken
        } while (!pageToken.isNullOrEmpty())
    }

    private suspend fun readLatestVitals(hours: Int): Map<String, Any?> =
        withContext(Dispatchers.IO) {
            val client = HealthConnectClient.getOrCreate(activity)
            val end = Instant.now()
            val start = end.minus(hours.toLong(), ChronoUnit.HOURS)

            val heartRates = mutableListOf<Map<String, Any?>>()
            appendHeartRateRecords(client, start, end, heartRates)
            appendRestingHeartRateRecords(client, start, end, heartRates)

            val bloodPressures = mutableListOf<Map<String, Any?>>()
            appendBloodPressureRecords(client, start, end, bloodPressures)

            val latestHeartRate = heartRates.maxByOrNull { record ->
                (record["recordedAtMs"] as Number).toLong()
            }
            val latestBloodPressure = bloodPressures.maxByOrNull { record ->
                (record["recordedAtMs"] as Number).toLong()
            }

            Log.i(
                TAG,
                "Latest vitals: HR=$latestHeartRate BP=$latestBloodPressure " +
                    "(from ${heartRates.size} HR / ${bloodPressures.size} BP points)",
            )

            mapOf(
                "heartRate" to latestHeartRate,
                "bloodPressure" to latestBloodPressure,
            )
        }

    companion object {
        private const val TAG = "GP2_HEALTH_CONNECT"
        const val CHANNEL_NAME = "com.example.gp2_watad/health_connect"
    }
}
