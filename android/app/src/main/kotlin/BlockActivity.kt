package com.example.change_your_life

import android.app.Activity
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Bundle
import android.util.Log
import android.widget.Button
import android.widget.TextView
import android.widget.Toast
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.nio.charset.StandardCharsets
import java.util.UUID

class BlockActivity : Activity() {
    private val tag = "BlockActivity"

    companion object {
        @Volatile
        var isVisible: Boolean = false

        @Volatile
        var visiblePackageName: String? = null

        @Volatile
        var lastVisibleAtMillis: Long = 0L
    }

    private val prefsFileName = "FlutterSharedPreferences"
    private val pendingUnlockRequestsKey = "flutter.pending_unlock_requests_csv"
    private val friendNameKey = "flutter.friendName"
    private val friendEmailKey = "flutter.friendEmail"
    private val requesterNameKey = "flutter.requester_name"
    private val installationIdKey = "flutter.installation_id"
    private val defaultUnlockMinutes = 60
    private val defaultRequesterName = "Usuario"
    private val unlockRequestsEndpoint =
        "https://oggqvcjtvfgyagaisvmj.functions.supabase.co/unlock-requests"

    @Volatile
    private var isRequestInFlight: Boolean = false
    private lateinit var titleText: TextView
    private lateinit var openReplacementsButton: Button
    private lateinit var requestUnlockButton: Button
    private lateinit var closeButton: Button
    private var currentAppName: String = "App"
    private var currentPackageName: String = ""

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_block)

        titleText = findViewById(R.id.blockTitle)
        openReplacementsButton = findViewById(R.id.openReplacementsButton)
        requestUnlockButton = findViewById(R.id.requestUnlockButton)
        closeButton = findViewById(R.id.closeButton)
        bindIntentData(intent)

        openReplacementsButton.setOnClickListener {
            openReplacementsExperience()
        }

        requestUnlockButton.setOnClickListener {
            if (isRequestInFlight) {
                Toast.makeText(
                    this,
                    "Ya estamos enviando una solicitud.",
                    Toast.LENGTH_SHORT
                ).show()
                return@setOnClickListener
            }

            val request = savePendingUnlockRequest(currentPackageName)
            if (request == null) {
                Toast.makeText(this, "No se pudo crear la solicitud.", Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }

            isRequestInFlight = true
            requestUnlockButton.isEnabled = false
            requestUnlockButton.text = "Enviando..."

            sendUnlockRequestAutomatically(
                appName = currentAppName,
                packageName = currentPackageName,
                request = request,
                onSuccess = {
                    isRequestInFlight = false
                    requestUnlockButton.isEnabled = true
                    requestUnlockButton.text = "Solicitar desbloqueo"
                    Toast.makeText(
                        this,
                        "Solicitud enviada.",
                        Toast.LENGTH_SHORT
                    ).show()
                },
                onFailure = { failureReason ->
                    isRequestInFlight = false
                    requestUnlockButton.isEnabled = true
                    requestUnlockButton.text = "Solicitar desbloqueo"
                    Toast.makeText(
                        this,
                        "Fallo envio automatico ($failureReason). Reintenta en unos segundos.",
                        Toast.LENGTH_LONG
                    ).show()
                }
            )
        }

        closeButton.setOnClickListener {
            navigateToHome()
        }
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        setIntent(intent)
        bindIntentData(intent)
    }

    override fun onPause() {
        super.onPause()
    }

    override fun onStart() {
        super.onStart()
        isVisible = true
        visiblePackageName = currentPackageName
        lastVisibleAtMillis = System.currentTimeMillis()
        syncRemoteGrantsOnShow()
    }

    override fun onResume() {
        super.onResume()
        isVisible = true
        visiblePackageName = currentPackageName
        lastVisibleAtMillis = System.currentTimeMillis()
    }

    override fun onStop() {
        isVisible = false
        super.onStop()
    }

    override fun onDestroy() {
        isVisible = false
        visiblePackageName = null
        super.onDestroy()
    }

    override fun onBackPressed() {
        navigateToHome()
    }

    private fun savePendingUnlockRequest(packageName: String): PendingRequestEntry? {
        if (packageName.isBlank()) return null

        val now = System.currentTimeMillis()
        val prefs = applicationContext.getSharedPreferences(
            prefsFileName,
            MODE_PRIVATE
        )
        val requestsByPackage = loadPendingRequests(prefs)
        val existing = requestsByPackage[packageName]

        val requestToSave = if (existing == null) {
            PendingRequestEntry(
                packageName = packageName,
                requestedAtMillis = now,
                requestId = UUID.randomUUID().toString()
            )
        } else {
            PendingRequestEntry(
                packageName = packageName,
                requestedAtMillis = existing.requestedAtMillis ?: now,
                requestId = existing.requestId ?: UUID.randomUUID().toString()
            )
        }
        requestsByPackage[packageName] = requestToSave

        val csv = serializePendingRequests(requestsByPackage)
        prefs.edit().putString(pendingUnlockRequestsKey, csv).apply()
        return requestToSave
    }

    private fun bindIntentData(intent: Intent?) {
        currentAppName = intent?.getStringExtra("appName")?.takeIf { it.isNotBlank() } ?: "App"
        currentPackageName = intent?.getStringExtra("packageName") ?: ""

        titleText.text = "$currentAppName esta bloqueada"

        visiblePackageName = currentPackageName
        lastVisibleAtMillis = System.currentTimeMillis()
    }

    private fun openReplacementsExperience() {
        val replacementsIntent = Intent(Intent.ACTION_VIEW).apply {
            data = Uri.parse("changeyourlife://unlock/replacements?source=block_activity")
            setPackage(packageName)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }

        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }

        runCatching {
            startActivity(replacementsIntent)
        }.onFailure {
            if (launchIntent != null) {
                startActivity(launchIntent)
            } else {
                navigateToHome()
            }
        }

        finish()
    }

    private fun navigateToHome() {
        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(homeIntent)
        finish()
    }

    private fun syncRemoteGrantsOnShow() {
        val packageName = currentPackageName.trim()
        if (packageName.isEmpty()) return

        Thread {
            val syncResult = UnlockGrantSyncRepository.syncNow(
                context = applicationContext,
                trigger = "block_activity_show",
                force = true
            )
            val activeFound = UnlockGrantSyncRepository.hasActiveUnlockForPackage(
                context = applicationContext,
                packageName = packageName
            )
            Log.i(
                tag,
                "grantSync trigger=block_activity_show requestId=${syncResult.requestId} installationId=${syncResult.installationId} packageName=$packageName activeFound=$activeFound success=${syncResult.success}",
            )
            if (activeFound) {
                runOnUiThread {
                    finish()
                }
            }
        }.start()
    }

    private fun sendUnlockRequestAutomatically(
        appName: String,
        packageName: String,
        request: PendingRequestEntry,
        onSuccess: () -> Unit,
        onFailure: (String) -> Unit
    ) {
        val prefs = applicationContext.getSharedPreferences(prefsFileName, MODE_PRIVATE)
        val friendName = prefs.getString(friendNameKey, "")?.trim().orEmpty()
        val friendEmail = prefs.getString(friendEmailKey, "")?.trim().orEmpty()
        val requesterName = prefs.getString(requesterNameKey, "")?.trim().orEmpty()

        if (friendEmail.isBlank()) {
            onFailure("sin email de amigo responsable")
            return
        }

        val safeAppName = appName.ifBlank { if (packageName.isBlank()) "App" else packageName }
        val safeFriendName = friendName.ifBlank { "amigo responsable" }
        val safeRequesterName = requesterName.ifBlank { defaultRequesterName }
        val installationId = getOrCreateInstallationId(prefs)
        Log.i(
            tag,
            "unlockRequestSend installationId=$installationId packageName=$packageName requestId=${request.requestId}",
        )

        val payload = JSONObject().apply {
            put("packageName", packageName)
            put("appName", safeAppName)
            put("requesterName", safeRequesterName)
            put("friendName", safeFriendName)
            put("friendEmail", friendEmail)
            put("minutes", defaultUnlockMinutes)
            put("v", 1)
        }

        Thread {
            val result = postUnlockRequest(payload.toString(), installationId)
            runOnUiThread {
                if (result.success) {
                    val backendRequestId = result.requestId
                    Log.i(
                        tag,
                        "unlockRequestOk installationId=$installationId packageName=$packageName requestId=$backendRequestId",
                    )
                    if (!backendRequestId.isNullOrBlank()) {
                        updatePendingRequestIdFromBackend(packageName, request, backendRequestId)
                    }
                    onSuccess()
                } else {
                    Log.w(
                        tag,
                        "unlockRequestFail installationId=$installationId packageName=$packageName requestId=${request.requestId} error=${result.errorMessage}",
                    )
                    onFailure(result.errorMessage ?: "error desconocido")
                }
            }
        }.start()
    }

    private fun getOrCreateInstallationId(prefs: SharedPreferences): String {
        val existing = prefs.getString(installationIdKey, "")?.trim().orEmpty()
        if (existing.isNotBlank()) return existing

        val generated = UUID.randomUUID().toString()
        prefs.edit().putString(installationIdKey, generated).apply()
        return generated
    }

    private fun postUnlockRequest(bodyJson: String, installationId: String): BackendRequestResult {
        var connection: HttpURLConnection? = null
        return try {
            connection = (URL(unlockRequestsEndpoint).openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                connectTimeout = 10_000
                readTimeout = 15_000
                doOutput = true
                setRequestProperty("Content-Type", "application/json")
                setRequestProperty("Accept", "application/json")
                setRequestProperty("X-Installation-Id", installationId)
            }

            connection.outputStream.use { stream ->
                stream.write(bodyJson.toByteArray(StandardCharsets.UTF_8))
            }

            val statusCode = connection.responseCode
            val responseBody = readResponseBody(connection, statusCode)

            if (statusCode in 200..299) {
                val parsed = runCatching { JSONObject(responseBody) }.getOrNull()
                val ok = parsed?.optBoolean("ok", false) ?: false
                if (!ok) {
                    return BackendRequestResult(
                        success = false,
                        errorMessage = extractErrorMessage(responseBody) ?: "respuesta invalida del backend"
                    )
                }

                val requestId = parsed
                    ?.optJSONObject("data")
                    ?.optString("requestId")
                    ?.takeIf { it.isNotBlank() }

                BackendRequestResult(
                    success = true,
                    requestId = requestId
                )
            } else {
                BackendRequestResult(
                    success = false,
                    errorMessage = extractErrorMessage(responseBody) ?: "http $statusCode"
                )
            }
        } catch (e: Exception) {
            BackendRequestResult(
                success = false,
                errorMessage = e.message ?: "network_error"
            )
        } finally {
            connection?.disconnect()
        }
    }

    private fun readResponseBody(connection: HttpURLConnection, statusCode: Int): String {
        val source = if (statusCode in 200..299) {
            connection.inputStream
        } else {
            connection.errorStream
        } ?: return ""

        return source.bufferedReader(Charsets.UTF_8).use { reader -> reader.readText() }
    }

    private fun extractErrorMessage(responseBody: String): String? {
        if (responseBody.isBlank()) return null
        val parsed = runCatching { JSONObject(responseBody) }.getOrNull() ?: return null
        val nestedError = parsed.optJSONObject("error")
        val message = nestedError?.optString("message") ?: parsed.optString("message")
        return message?.takeIf { it.isNotBlank() }
    }

    private fun updatePendingRequestIdFromBackend(
        packageName: String,
        request: PendingRequestEntry,
        backendRequestId: String
    ) {
        val prefs = applicationContext.getSharedPreferences(prefsFileName, MODE_PRIVATE)
        val requestsByPackage = loadPendingRequests(prefs)
        val existing = requestsByPackage[packageName] ?: request

        requestsByPackage[packageName] = PendingRequestEntry(
            packageName = packageName,
            requestedAtMillis = existing.requestedAtMillis ?: System.currentTimeMillis(),
            requestId = backendRequestId
        )

        val csv = serializePendingRequests(requestsByPackage)
        prefs.edit().putString(pendingUnlockRequestsKey, csv).apply()
    }

    private fun loadPendingRequests(prefs: SharedPreferences): LinkedHashMap<String, PendingRequestEntry> {
        val csv = prefs.getString(pendingUnlockRequestsKey, "") ?: ""
        val requests = LinkedHashMap<String, PendingRequestEntry>()
        val now = System.currentTimeMillis()

        csv.split(",")
            .map { it.trim() }
            .filter { it.isNotEmpty() }
            .forEach { entry ->
                val request = parsePendingRequestEntry(entry)
                if (request != null && !requests.containsKey(request.packageName)) {
                    requests[request.packageName] = PendingRequestEntry(
                        packageName = request.packageName,
                        requestedAtMillis = request.requestedAtMillis ?: now,
                        requestId = request.requestId
                    )
                }
            }

        return requests
    }

    private fun serializePendingRequests(requests: Map<String, PendingRequestEntry>): String {
        return requests.values.joinToString(",") { request ->
            val timestamp = request.requestedAtMillis ?: System.currentTimeMillis()
            val requestId = request.requestId
            if (requestId.isNullOrBlank()) {
                "${request.packageName}|$timestamp"
            } else {
                "${request.packageName}|$timestamp|$requestId"
            }
        }
    }

    // Supports legacy "package", "package|timestamp", and "package|timestamp|requestId".
    private fun parsePendingRequestEntry(entry: String): PendingRequestEntry? {
        if (entry.isBlank()) return null

        if (!entry.contains("|")) {
            val pkg = entry.trim()
            if (pkg.isEmpty()) return null
            return PendingRequestEntry(
                packageName = pkg,
                requestedAtMillis = null,
                requestId = null
            )
        }

        val parts = entry.split("|")
        val pkg = parts.firstOrNull()?.trim().orEmpty()
        if (pkg.isEmpty()) return null

        val timestamp = parts.getOrNull(1)?.trim()?.toLongOrNull()
        val requestId = parts.getOrNull(2)?.trim()?.takeIf { it.isNotEmpty() }

        return PendingRequestEntry(
            packageName = pkg,
            requestedAtMillis = timestamp,
            requestId = requestId
        )
    }

    private data class PendingRequestEntry(
        val packageName: String,
        val requestedAtMillis: Long?,
        val requestId: String?
    )

    private data class BackendRequestResult(
        val success: Boolean,
        val requestId: String? = null,
        val errorMessage: String? = null
    )
}
