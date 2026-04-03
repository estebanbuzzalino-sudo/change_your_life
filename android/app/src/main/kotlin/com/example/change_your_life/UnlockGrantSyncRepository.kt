package com.example.change_your_life

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.text.ParseException
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone
import java.util.UUID
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

object UnlockGrantSyncRepository {
    private const val TAG = "UnlockGrantSync"
    private const val PREFS_FILE_NAME = "FlutterSharedPreferences"
    private const val TEMPORARY_UNLOCKED_KEY = "flutter.temporary_unlocked_packages_csv"
    private const val INSTALLATION_ID_KEY = "flutter.installation_id"
    private const val ACTIVE_GRANTS_ENDPOINT =
        "https://oggqvcjtvfgyagaisvmj.functions.supabase.co/unlock-grants/active"
    private const val MIN_SYNC_INTERVAL_MILLIS = 2_000L

    @Volatile
    private var lastSyncAttemptAtMillis: Long = 0L

    data class SyncResult(
        val success: Boolean,
        val requestId: String? = null,
        val installationId: String? = null,
        val packageName: String? = null,
        val activeFound: Boolean = false,
        val activeCount: Int = 0,
        val serverTime: String? = null,
        val errorMessage: String? = null,
        val skippedByThrottle: Boolean = false,
    )

    @Synchronized
    fun getOrCreateInstallationId(context: Context): String {
        val prefs = context.getSharedPreferences(PREFS_FILE_NAME, Context.MODE_PRIVATE)
        val existing = prefs.getString(INSTALLATION_ID_KEY, "")?.trim().orEmpty()
        if (existing.isNotBlank()) return existing

        val generated = UUID.randomUUID().toString()
        prefs.edit().putString(INSTALLATION_ID_KEY, generated).apply()
        Log.i(TAG, "generatedInstallationId installationId=$generated")
        return generated
    }

    fun hasActiveUnlockForPackage(
        context: Context,
        packageName: String,
        nowMillis: Long = System.currentTimeMillis(),
    ): Boolean {
        if (packageName.isBlank()) return false
        val prefs = context.getSharedPreferences(PREFS_FILE_NAME, Context.MODE_PRIVATE)
        val local = parseTemporaryUnlockedCsv(prefs.getString(TEMPORARY_UNLOCKED_KEY, "") ?: "")
        val unlockUntil = local[packageName] ?: return false
        return unlockUntil > nowMillis
    }

    fun syncAndCheckPackageBlocking(
        context: Context,
        packageName: String,
        trigger: String,
        timeoutMs: Long = 900L,
    ): SyncResult {
        val now = System.currentTimeMillis()
        if (hasActiveUnlockForPackage(context, packageName, now)) {
            return SyncResult(
                success = true,
                installationId = getOrCreateInstallationId(context),
                packageName = packageName,
                activeFound = true,
            )
        }

        val syncResultHolder = arrayOfNulls<SyncResult>(1)
        val latch = CountDownLatch(1)
        Thread {
            try {
                syncResultHolder[0] = syncNow(context, trigger = trigger, force = false)
            } finally {
                latch.countDown()
            }
        }.start()

        val finished = latch.await(timeoutMs, TimeUnit.MILLISECONDS)
        val activeAfterSync = hasActiveUnlockForPackage(context, packageName, System.currentTimeMillis())
        val base = if (finished) {
            syncResultHolder[0] ?: SyncResult(
                success = false,
                installationId = getOrCreateInstallationId(context),
                packageName = packageName,
                errorMessage = "empty_sync_result",
            )
        } else {
            SyncResult(
                success = false,
                installationId = getOrCreateInstallationId(context),
                packageName = packageName,
                errorMessage = "sync_timeout",
            )
        }

        val result = base.copy(
            packageName = packageName,
            activeFound = activeAfterSync,
        )
        Log.i(
            TAG,
            "syncAndCheck trigger=$trigger requestId=${result.requestId} installationId=${result.installationId} packageName=$packageName activeFound=${result.activeFound} success=${result.success} skipped=${result.skippedByThrottle} error=${result.errorMessage}",
        )
        return result
    }

    fun syncNow(
        context: Context,
        trigger: String,
        force: Boolean,
    ): SyncResult {
        val prefs = context.getSharedPreferences(PREFS_FILE_NAME, Context.MODE_PRIVATE)
        val installationId = getOrCreateInstallationId(context)
        val now = System.currentTimeMillis()

        synchronized(this) {
            if (!force && now - lastSyncAttemptAtMillis < MIN_SYNC_INTERVAL_MILLIS) {
                val local = parseTemporaryUnlockedCsv(prefs.getString(TEMPORARY_UNLOCKED_KEY, "") ?: "")
                val activeLocal = filterActive(local, now)
                val skipped = SyncResult(
                    success = true,
                    installationId = installationId,
                    activeCount = activeLocal.size,
                    skippedByThrottle = true,
                )
                Log.i(
                    TAG,
                    "syncSkipped trigger=$trigger installationId=$installationId activeCount=${activeLocal.size}",
                )
                return skipped
            }
            lastSyncAttemptAtMillis = now
        }

        var connection: HttpURLConnection? = null
        return try {
            connection = (URL(ACTIVE_GRANTS_ENDPOINT).openConnection() as HttpURLConnection).apply {
                requestMethod = "GET"
                connectTimeout = 2_500
                readTimeout = 3_500
                setRequestProperty("Accept", "application/json")
                setRequestProperty("X-Installation-Id", installationId)
            }

            val statusCode = connection.responseCode
            val responseBody = readResponseBody(connection, statusCode)
            if (statusCode !in 200..299) {
                val result = SyncResult(
                    success = false,
                    installationId = installationId,
                    errorMessage = "http_$statusCode",
                )
                Log.w(
                    TAG,
                    "syncHttpError trigger=$trigger installationId=$installationId status=$statusCode body=$responseBody",
                )
                return result
            }

            val parsed = runCatching { JSONObject(responseBody) }.getOrNull()
            if (parsed == null) {
                return SyncResult(
                    success = false,
                    installationId = installationId,
                    errorMessage = "invalid_json",
                )
            }

            val data = parsed.optJSONObject("data")
            val meta = parsed.optJSONObject("meta")
            val requestId = meta?.optString("requestId")?.takeIf { it.isNotBlank() }
            val serverTime = data?.optString("serverTime")?.takeIf { it.isNotBlank() }
                ?: meta?.optString("serverTime")?.takeIf { it.isNotBlank() }
            val referenceNow = parseIsoMillis(serverTime) ?: System.currentTimeMillis()

            val remoteByPackage = LinkedHashMap<String, Long>()
            val grants = data?.optJSONArray("grants")
            if (grants != null) {
                for (index in 0 until grants.length()) {
                    val item = grants.optJSONObject(index) ?: continue
                    val packageName = item.optString("packageName")
                        .ifBlank { item.optString("package_name") }
                        .trim()
                    val unlockUntilIso = item.optString("unlockUntil")
                        .ifBlank { item.optString("unlock_until") }
                        .trim()
                    val unlockUntilMillis = parseIsoMillis(unlockUntilIso) ?: continue

                    if (packageName.isBlank() || unlockUntilMillis <= referenceNow) continue

                    val existing = remoteByPackage[packageName]
                    if (existing == null || unlockUntilMillis > existing) {
                        remoteByPackage[packageName] = unlockUntilMillis
                    }
                }
            }

            val localByPackage = parseTemporaryUnlockedCsv(
                prefs.getString(TEMPORARY_UNLOCKED_KEY, "") ?: "",
            )
            val merged = filterActive(localByPackage, referenceNow)
            for ((packageName, unlockUntil) in remoteByPackage) {
                val existing = merged[packageName]
                if (existing == null || unlockUntil > existing) {
                    merged[packageName] = unlockUntil
                }
            }

            prefs.edit().putString(TEMPORARY_UNLOCKED_KEY, serializeTemporaryUnlockedCsv(merged)).apply()

            val result = SyncResult(
                success = true,
                requestId = requestId,
                installationId = installationId,
                activeCount = merged.size,
                serverTime = serverTime,
            )
            Log.i(
                TAG,
                "syncOk trigger=$trigger requestId=$requestId installationId=$installationId activeCount=${merged.size} serverTime=$serverTime",
            )
            result
        } catch (e: Exception) {
            val result = SyncResult(
                success = false,
                installationId = installationId,
                errorMessage = e.message ?: "network_error",
            )
            Log.w(
                TAG,
                "syncException trigger=$trigger installationId=$installationId error=${result.errorMessage}",
            )
            result
        } finally {
            connection?.disconnect()
        }
    }

    private fun readResponseBody(connection: HttpURLConnection, statusCode: Int): String {
        val source = if (statusCode in 200..299) connection.inputStream else connection.errorStream
            ?: return ""
        return source.bufferedReader(Charsets.UTF_8).use { it.readText() }
    }

    private fun parseTemporaryUnlockedCsv(csv: String): LinkedHashMap<String, Long> {
        val unlocked = LinkedHashMap<String, Long>()
        if (csv.isBlank()) return unlocked

        csv.split(",")
            .map { it.trim() }
            .filter { it.isNotEmpty() }
            .forEach { entry ->
                val packageName = entry.substringBefore("|").trim()
                if (packageName.isEmpty()) return@forEach

                val unlockUntil = entry.substringAfter("|", "").trim().toLongOrNull() ?: return@forEach
                val existing = unlocked[packageName]
                if (existing == null || unlockUntil > existing) {
                    unlocked[packageName] = unlockUntil
                }
            }

        return unlocked
    }

    private fun filterActive(entries: Map<String, Long>, now: Long): LinkedHashMap<String, Long> {
        val active = LinkedHashMap<String, Long>()
        for ((pkg, unlockUntil) in entries) {
            if (unlockUntil > now) {
                active[pkg] = unlockUntil
            }
        }
        return active
    }

    private fun serializeTemporaryUnlockedCsv(entries: Map<String, Long>): String {
        return entries.entries.joinToString(",") { "${it.key}|${it.value}" }
    }

    private fun parseIsoMillis(value: String?): Long? {
        if (value.isNullOrBlank()) return null
        val candidates = listOf(
            "yyyy-MM-dd'T'HH:mm:ss.SSSX",
            "yyyy-MM-dd'T'HH:mm:ssX",
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXX",
            "yyyy-MM-dd'T'HH:mm:ssXXX",
        )
        for (pattern in candidates) {
            try {
                val formatter = SimpleDateFormat(pattern, Locale.US).apply {
                    timeZone = TimeZone.getTimeZone("UTC")
                }
                val date = formatter.parse(value)
                if (date != null) return date.time
            } catch (_: ParseException) {
            }
        }
        return null
    }
}
