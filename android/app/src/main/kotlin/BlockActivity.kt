package com.example.change_your_life

import android.app.Activity
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Bundle
import android.widget.Button
import android.widget.TextView
import android.widget.Toast
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID

class BlockActivity : Activity() {
    companion object {
        @Volatile
        var isVisible: Boolean = false
    }

    private val prefsFileName = "FlutterSharedPreferences"
    private val pendingUnlockRequestsKey = "flutter.pending_unlock_requests_csv"
    private val friendNameKey = "flutter.friendName"
    private val friendEmailKey = "flutter.friendEmail"
    private val requesterNameKey = "flutter.requester_name"
    private val defaultUnlockMinutes = 60

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_block)

        val appName = intent.getStringExtra("appName") ?: "App"
        val packageName = intent.getStringExtra("packageName") ?: ""

        val titleText = findViewById<TextView>(R.id.blockTitle)
        val packageText = findViewById<TextView>(R.id.blockPackage)
        val requestUnlockButton = findViewById<Button>(R.id.requestUnlockButton)
        val closeButton = findViewById<Button>(R.id.closeButton)

        titleText.text = "$appName esta bloqueada"
        packageText.text = "Package: $packageName"

        requestUnlockButton.setOnClickListener {
            val request = savePendingUnlockRequest(packageName)
            if (request == null) {
                Toast.makeText(this, "No se pudo crear la solicitud.", Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }

            tryOpenUnlockRequestEmail(
                appName = appName,
                packageName = packageName,
                request = request
            )
            Toast.makeText(this, "Solicitud enviada", Toast.LENGTH_SHORT).show()
        }

        closeButton.setOnClickListener {
            val homeIntent = Intent(Intent.ACTION_MAIN)
            homeIntent.addCategory(Intent.CATEGORY_HOME)
            homeIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            startActivity(homeIntent)
            finish()
        }
    }

    override fun onPause() {
        super.onPause()
    }

    override fun onStart() {
        super.onStart()
        isVisible = true
    }

    override fun onStop() {
        isVisible = false
        super.onStop()
    }

    override fun onDestroy() {
        isVisible = false
        super.onDestroy()
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

    private fun tryOpenUnlockRequestEmail(
        appName: String,
        packageName: String,
        request: PendingRequestEntry
    ) {
        val prefs = applicationContext.getSharedPreferences(
            prefsFileName,
            MODE_PRIVATE
        )

        val friendName = prefs.getString(friendNameKey, "")?.trim().orEmpty()
        val friendEmail = prefs.getString(friendEmailKey, "")?.trim().orEmpty()
        val requesterName = prefs.getString(requesterNameKey, "")?.trim().orEmpty()

        if (friendEmail.isBlank()) {
            Toast.makeText(
                this,
                "No hay email del amigo responsable configurado.",
                Toast.LENGTH_SHORT
            ).show()
            return
        }

        val safeAppName = appName.ifBlank { if (packageName.isBlank()) "App" else packageName }
        val safeFriendName = friendName.ifBlank { "amigo responsable" }
        val safeRequesterName = requesterName.ifBlank { "Usuario actual" }
        val nowFormatted = SimpleDateFormat("dd/MM/yyyy HH:mm", Locale.getDefault())
            .format(Date())
        val approvalDeepLink = buildApprovalDeepLink(
            requestId = request.requestId ?: UUID.randomUUID().toString(),
            packageName = packageName,
            requestedAtMillis = request.requestedAtMillis ?: System.currentTimeMillis(),
            minutes = defaultUnlockMinutes
        )

        val subject = "Solicitud de desbloqueo temporal (60 min) - $safeAppName"
        val body = """
            Hola $safeFriendName,

            Se solicita tu aprobacion para desbloquear temporalmente una app por 60 minutos.

            App bloqueada: $safeAppName
            Package: $packageName
            Solicitante: $safeRequesterName
            Fecha/Hora: $nowFormatted

            Aprobas este desbloqueo temporal por 60 minutos?
            Aprobar desbloqueo: $approvalDeepLink
            Si no aparece clickeable, copiar este link y pegarlo en la app (test local).
        """.trimIndent()

        val emailIntent = Intent(Intent.ACTION_SENDTO).apply {
            data = Uri.parse("mailto:")
            putExtra(Intent.EXTRA_EMAIL, arrayOf(friendEmail))
            putExtra(Intent.EXTRA_SUBJECT, subject)
            putExtra(Intent.EXTRA_TEXT, body)
        }

        if (emailIntent.resolveActivity(packageManager) != null) {
            startActivity(Intent.createChooser(emailIntent, "Enviar solicitud por email"))
        } else {
            Toast.makeText(
                this,
                "No se encontro una app de correo en el dispositivo.",
                Toast.LENGTH_SHORT
            ).show()
        }
    }

    private fun buildApprovalDeepLink(
        requestId: String,
        packageName: String,
        requestedAtMillis: Long,
        minutes: Int
    ): String {
        return Uri.Builder()
            .scheme("changeyourlife")
            .authority("unlock")
            .appendPath("approve")
            .appendQueryParameter("requestId", requestId)
            .appendQueryParameter("package", packageName)
            .appendQueryParameter("requestedAt", requestedAtMillis.toString())
            .appendQueryParameter("minutes", minutes.toString())
            .appendQueryParameter("v", "1")
            .build()
            .toString()
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
}
