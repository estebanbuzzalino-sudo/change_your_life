package com.example.change_your_life

import android.app.Activity
import android.content.Intent
import android.content.SharedPreferences
import android.os.Bundle
import android.widget.Button
import android.widget.TextView
import android.widget.Toast

class BlockActivity : Activity() {

    private val prefsFileName = "FlutterSharedPreferences"
    private val pendingUnlockRequestsKey = "flutter.pending_unlock_requests_csv"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_block)

        val appName = intent.getStringExtra("appName") ?: "App"
        val packageName = intent.getStringExtra("packageName") ?: ""

        val titleText = findViewById<TextView>(R.id.blockTitle)
        val packageText = findViewById<TextView>(R.id.blockPackage)
        val requestUnlockButton = findViewById<Button>(R.id.requestUnlockButton)
        val closeButton = findViewById<Button>(R.id.closeButton)

        titleText.text = "$appName está bloqueada"
        packageText.text = "Package: $packageName"

        requestUnlockButton.setOnClickListener {
            savePendingUnlockRequest(packageName)
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

    private fun savePendingUnlockRequest(packageName: String) {
        if (packageName.isBlank()) return

        val now = System.currentTimeMillis()
        val prefs = applicationContext.getSharedPreferences(
            prefsFileName,
            MODE_PRIVATE
        )
        val requestsByPackage = loadPendingRequests(prefs)

        if (!requestsByPackage.containsKey(packageName)) {
            requestsByPackage[packageName] = now
        }

        val csv = serializePendingRequests(requestsByPackage)
        prefs.edit().putString(pendingUnlockRequestsKey, csv).apply()
    }

    private fun loadPendingRequests(prefs: SharedPreferences): LinkedHashMap<String, Long> {
        val csv = prefs.getString(pendingUnlockRequestsKey, "") ?: ""
        val requests = LinkedHashMap<String, Long>()
        val now = System.currentTimeMillis()

        csv.split(",")
            .map { it.trim() }
            .filter { it.isNotEmpty() }
            .forEach { entry ->
                val request = parsePendingRequestEntry(entry)
                if (request != null && !requests.containsKey(request.packageName)) {
                    requests[request.packageName] = request.requestedAtMillis ?: now
                }
            }

        return requests
    }

    private fun serializePendingRequests(requests: Map<String, Long>): String {
        return requests.entries.joinToString(",") { "${it.key}|${it.value}" }
    }

    // Supports both legacy "package" and current "package|timestamp" entries.
    private fun parsePendingRequestEntry(entry: String): PendingRequestEntry? {
        return if (entry.contains("|")) {
            val pkg = entry.substringBefore("|").trim()
            if (pkg.isEmpty()) return null
            val timestamp = entry.substringAfter("|", "").trim().toLongOrNull()
            PendingRequestEntry(pkg, timestamp)
        } else {
            PendingRequestEntry(entry, null)
        }
    }

    private data class PendingRequestEntry(
        val packageName: String,
        val requestedAtMillis: Long?
    )
}
