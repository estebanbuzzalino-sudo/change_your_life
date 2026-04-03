package com.example.change_your_life

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.ApplicationInfo
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityEvent

class AppBlockAccessibilityService : AccessibilityService() {
    private val tag = "AppBlockService"

    private var lastBlockedPackage: String? = null
    private var lastLaunchTime: Long = 0L
    // Cooldown corto para evitar rafagas de relanzamiento.
    private val relaunchCooldownMillis = 500L
    // Ventana corta de transicion mientras BlockActivity entra en foreground.
    private val transitionGuardMillis = 800L
    private val launchAfterHomeDelayMillis = 120L
    private var transitionGuardPackage: String? = null
    private var transitionGuardUntil: Long = 0L
    private var lastForegroundPackage: String? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val prefsFileName = "FlutterSharedPreferences"
    private val blockedPackagesKey = "flutter.blocked_packages_csv"
    private val temporaryUnlockedPackagesKey = "flutter.temporary_unlocked_packages_csv"
    private lateinit var prefs: SharedPreferences
    private var blockedPackagesCache: Set<String> = emptySet()
    private var temporarilyUnlockedCache: Map<String, Long> = emptyMap()
    private var prefsListenerRegistered = false
    private val prefsListener = SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
        when (key) {
            blockedPackagesKey -> refreshBlockedPackages()
            temporaryUnlockedPackagesKey -> refreshTemporarilyUnlockedPackages()
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
        refreshTemporarilyUnlockedPackages()

        if (!prefsListenerRegistered) {
            prefs.registerOnSharedPreferenceChangeListener(prefsListener)
            prefsListenerRegistered = true
        }

        Thread {
            val syncResult = UnlockGrantSyncRepository.syncNow(
                context = applicationContext,
                trigger = "service_connected",
                force = true
            )
            refreshTemporarilyUnlockedPackages()
            Log.i(
                tag,
                "grantSync trigger=service_connected requestId=${syncResult.requestId} installationId=${syncResult.installationId} packageName=- activeFound=false success=${syncResult.success}",
            )
        }.start()
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

        if (!this::prefs.isInitialized) {
            ensurePrefsInitialized()
            refreshBlockedPackages()
            refreshTemporarilyUnlockedPackages()
        }

        val openedPackage = event.packageName?.toString() ?: return
        lastForegroundPackage = openedPackage

        if (isCriticalPackage(openedPackage)) {
            return
        }

        val now = System.currentTimeMillis()
        val blockedPackages = blockedPackagesCache
        val isBlocked = blockedPackages.contains(openedPackage)
        val isUnlockedNow = isTemporarilyUnlocked(openedPackage, now)

        if (isBlocked && !isUnlockedNow) {
            val grantCheck = UnlockGrantSyncRepository.syncAndCheckPackageBlocking(
                context = applicationContext,
                packageName = openedPackage,
                trigger = "accessibility_pre_block",
                timeoutMs = 900L
            )
            Log.i(
                tag,
                "grantCheck trigger=accessibility_pre_block requestId=${grantCheck.requestId} installationId=${grantCheck.installationId} packageName=$openedPackage activeFound=${grantCheck.activeFound} success=${grantCheck.success}",
            )

            if (grantCheck.activeFound) {
                refreshTemporarilyUnlockedPackages()
                return
            }
        }

        if (!isBlocked || isUnlockedNow) {
            if (transitionGuardPackage == openedPackage && now >= transitionGuardUntil) {
                transitionGuardPackage = null
            }
            return
        }

        if (isBlocked && !isUnlockedNow) {
            // Evita reentrada cuando BlockActivity ya esta visible.
            if (BlockActivity.isVisible && BlockActivity.visiblePackageName == openedPackage) {
                return
            }

            // Si la pantalla bloqueada estuvo recien visible para esa app, no relanzar.
            if (BlockActivity.visiblePackageName == openedPackage &&
                now - BlockActivity.lastVisibleAtMillis < transitionGuardMillis
            ) {
                return
            }

            // Guard corto por paquete durante la transicion.
            if (transitionGuardPackage == openedPackage && now < transitionGuardUntil) {
                return
            }

            // Debounce por paquete: evita rafagas del mismo evento.
            if (lastBlockedPackage == openedPackage &&
                now - lastLaunchTime < relaunchCooldownMillis
            ) return

            lastBlockedPackage = openedPackage
            lastLaunchTime = now
            transitionGuardPackage = openedPackage
            transitionGuardUntil = now + transitionGuardMillis

            // Empuja la app bloqueada a segundo plano antes de mostrar la pantalla de bloqueo.
            performGlobalAction(GLOBAL_ACTION_HOME)
            mainHandler.postDelayed({
                if (BlockActivity.isVisible && BlockActivity.visiblePackageName == openedPackage) {
                    return@postDelayed
                }

                val currentNow = System.currentTimeMillis()
                if (!blockedPackagesCache.contains(openedPackage)) {
                    return@postDelayed
                }

                if (isTemporarilyUnlocked(openedPackage, currentNow)) {
                    return@postDelayed
                }

                val latestForeground = lastForegroundPackage
                if (!latestForeground.isNullOrBlank() &&
                    latestForeground != openedPackage &&
                    !launcherPackages.contains(latestForeground) &&
                    !criticalPackages.contains(latestForeground)
                ) {
                    return@postDelayed
                }

                val intent = Intent(this, BlockActivity::class.java)
                intent.addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_NO_ANIMATION
                )
                intent.putExtra("appName", getAppLabel(openedPackage))
                intent.putExtra("packageName", openedPackage)
                startActivity(intent)
            }, launchAfterHomeDelayMillis)
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

    private fun refreshTemporarilyUnlockedPackages() {
        ensurePrefsInitialized()
        val csv = prefs.getString(temporaryUnlockedPackagesKey, "") ?: ""
        val parsed = parseTemporarilyUnlockedPackages(csv)
        val now = System.currentTimeMillis()
        val active = parsed.filterValues { it > now }

        temporarilyUnlockedCache = active

        if (active.size != parsed.size) {
            persistTemporarilyUnlockedPackages(active)
        }
    }

    private fun isTemporarilyUnlocked(packageName: String, now: Long): Boolean {
        val unlockedUntil = temporarilyUnlockedCache[packageName] ?: return false

        if (unlockedUntil <= now) {
            val updated = temporarilyUnlockedCache.toMutableMap()
            updated.remove(packageName)
            temporarilyUnlockedCache = updated
            persistTemporarilyUnlockedPackages(updated)
            return false
        }

        return true
    }

    private fun parseTemporarilyUnlockedPackages(csv: String): Map<String, Long> {
        if (csv.isBlank()) return emptyMap()

        val unlocked = LinkedHashMap<String, Long>()

        csv.split(",")
            .map { it.trim() }
            .filter { it.isNotEmpty() }
            .forEach { entry ->
                val packageName = entry.substringBefore("|").trim()
                if (packageName.isEmpty()) return@forEach

                val unlockedUntil = entry.substringAfter("|", "").trim().toLongOrNull()
                    ?: return@forEach

                val existing = unlocked[packageName]
                if (existing == null || unlockedUntil > existing) {
                    unlocked[packageName] = unlockedUntil
                }
            }

        return unlocked
    }

    private fun persistTemporarilyUnlockedPackages(packages: Map<String, Long>) {
        val csv = packages.entries.joinToString(",") { "${it.key}|${it.value}" }
        prefs.edit().putString(temporaryUnlockedPackagesKey, csv).apply()
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
