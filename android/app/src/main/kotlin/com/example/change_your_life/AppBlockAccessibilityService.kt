package com.example.change_your_life

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.view.accessibility.AccessibilityEvent

class AppBlockAccessibilityService : AccessibilityService() {

    private var lastBlockedPackage: String? = null
    private var lastLaunchTime: Long = 0L

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            return
        }

        val openedPackage = event.packageName?.toString() ?: return

        // No bloquear la propia app
        if (openedPackage == packageName || openedPackage == "com.example.change_your_life") {
            return
        }

        val blockedPackages = getBlockedPackages()

        if (blockedPackages.contains(openedPackage)) {
            val now = System.currentTimeMillis()

            // Evita abrir muchas veces seguidas la pantalla de bloqueo
            if (lastBlockedPackage == openedPackage && now - lastLaunchTime < 1500) {
                return
            }

            lastBlockedPackage = openedPackage
            lastLaunchTime = now

            val intent = Intent(this, BlockActivity::class.java)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            intent.putExtra("appName", getAppLabel(openedPackage))
            intent.putExtra("packageName", openedPackage)
            startActivity(intent)
        }
    }

    override fun onInterrupt() {
    }

    private fun getBlockedPackages(): Set<String> {
        val prefs = applicationContext.getSharedPreferences(
            "FlutterSharedPreferences",
            Context.MODE_PRIVATE
        )

        val csv = prefs.getString("flutter.blocked_packages_csv", "") ?: ""

        return csv.split(",")
            .map { it.trim() }
            .filter { it.isNotEmpty() }
            .toSet()
    }

    private fun getAppLabel(packageName: String): String {
        return try {
            val pm = packageManager
            val appInfo: ApplicationInfo = pm.getApplicationInfo(packageName, 0)
            pm.getApplicationLabel(appInfo).toString()
        } catch (e: Exception) {
            packageName
        }
    }
}