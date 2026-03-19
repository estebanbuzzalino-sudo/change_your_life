package com.example.change_your_life

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.ApplicationInfo
import android.view.accessibility.AccessibilityEvent

class AppBlockAccessibilityService : AccessibilityService() {

    private var lastBlockedPackage: String? = null
    private var lastLaunchTime: Long = 0L
    private val prefsFileName = "FlutterSharedPreferences"
    private val blockedPackagesKey = "flutter.blocked_packages_csv"
    private lateinit var prefs: SharedPreferences
    private var blockedPackagesCache: Set<String> = emptySet()
    private var prefsListenerRegistered = false
    private val prefsListener = SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
        if (key == blockedPackagesKey) {
            refreshBlockedPackages()
        }
    }
    private val criticalPackages = setOf(
        "android",
        "com.android.settings",
        "com.android.systemui",
        "com.google.android.gms",
        "com.android.permissioncontroller",
        "com.google.android.permissioncontroller",
        "com.android.launcher3",
        "com.google.android.apps.nexuslauncher",
        "com.sec.android.app.launcher",
        "com.miui.home",
        "com.huawei.android.launcher",
        "com.oppo.launcher",
        "com.oneplus.launcher"
    )
    private val launcherPackages: Set<String> by lazy {
        val homeIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        val resolvedHomePackage = packageManager
            .resolveActivity(homeIntent, 0)
            ?.activityInfo
            ?.packageName
        val homeHandlers = packageManager.queryIntentActivities(homeIntent, 0)
            .mapNotNull { it.activityInfo?.packageName }

        buildSet {
            if (!resolvedHomePackage.isNullOrBlank()) {
                add(resolvedHomePackage)
            }
            addAll(homeHandlers)
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        ensurePrefsInitialized()
        refreshBlockedPackages()

        if (!prefsListenerRegistered) {
            prefs.registerOnSharedPreferenceChangeListener(prefsListener)
            prefsListenerRegistered = true
        }
    }

    override fun onDestroy() {
        if (this::prefs.isInitialized && prefsListenerRegistered) {
            prefs.unregisterOnSharedPreferenceChangeListener(prefsListener)
            prefsListenerRegistered = false
        }
        super.onDestroy()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            return
        }

        val openedPackage = event.packageName?.toString() ?: return

        if (isCriticalPackage(openedPackage)) {
            return
        }

        val blockedPackages = blockedPackagesCache

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

    private fun isCriticalPackage(openedPackage: String): Boolean {
        if (openedPackage == packageName || openedPackage == "com.example.change_your_life") {
            return true
        }

        if (criticalPackages.contains(openedPackage)) {
            return true
        }

        return launcherPackages.contains(openedPackage)
    }

    private fun ensurePrefsInitialized() {
        if (!this::prefs.isInitialized) {
            prefs = applicationContext.getSharedPreferences(
                prefsFileName,
                Context.MODE_PRIVATE
            )
        }
    }

    private fun refreshBlockedPackages() {
        ensurePrefsInitialized()
        blockedPackagesCache = getBlockedPackages()
    }

    private fun getBlockedPackages(): Set<String> {
        val csv = prefs.getString(blockedPackagesKey, "") ?: ""

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
