import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UnlockGrantActiveGrant {
  final String packageName;
  final int unlockUntilMillis;
  final String? requestId;
  final String? appName;
  final int? minutes;

  const UnlockGrantActiveGrant({
    required this.packageName,
    required this.unlockUntilMillis,
    this.requestId,
    this.appName,
    this.minutes,
  });
}

class UnlockGrantSyncResult {
  final bool success;
  final String installationId;
  final String? requestId;
  final String? serverTime;
  final int activeCount;
  final bool hasActiveForPackage;
  final String? packageName;
  final String? errorMessage;
  final List<UnlockGrantActiveGrant> activeGrants;

  const UnlockGrantSyncResult({
    required this.success,
    required this.installationId,
    required this.activeCount,
    required this.hasActiveForPackage,
    required this.activeGrants,
    this.requestId,
    this.serverTime,
    this.packageName,
    this.errorMessage,
  });
}

class UnlockGrantsSyncService {
  static const String _installationIdKey = 'installation_id';
  static const String _temporaryUnlockedKey = 'temporary_unlocked_packages_csv';
  static const String _ignoredUnlockGrantsKey = 'ignored_unlock_grants_csv';
  static const String _endpoint =
      'https://oggqvcjtvfgyagaisvmj.functions.supabase.co/unlock-grants/active';
  static const int _minSyncIntervalMillis = 10 * 1000;

  int _lastSyncAttemptAtMillis = 0;

  Future<UnlockGrantSyncResult> syncActiveGrants({
    required String trigger,
    String? packageName,
    bool force = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final installationId = await _getOrCreateInstallationId(prefs);
    final now = DateTime.now().millisecondsSinceEpoch;

    if (!force && (now - _lastSyncAttemptAtMillis) < _minSyncIntervalMillis) {
      final local = _parseTemporaryUnlockedCsv(
        prefs.getString(_temporaryUnlockedKey) ?? '',
      );
      final activeLocal = _filterActive(local, now);
      final hasActive = _hasActiveForPackage(activeLocal, packageName, now);
      return UnlockGrantSyncResult(
        success: true,
        installationId: installationId,
        activeCount: activeLocal.length,
        hasActiveForPackage: hasActive,
        activeGrants: _activeGrantsFromMap(activeLocal),
        packageName: packageName,
      );
    }

    _lastSyncAttemptAtMillis = now;

    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
      final request = await client.getUrl(Uri.parse(_endpoint));
      request.headers.set('Accept', 'application/json');
      request.headers.set('X-Installation-Id', installationId);

      final response = await request.close().timeout(const Duration(seconds: 7));
      final body = await utf8.decoder.bind(response).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final activeLocal = _filterActive(
          _parseTemporaryUnlockedCsv(prefs.getString(_temporaryUnlockedKey) ?? ''),
          now,
        );
        debugPrint(
          '[grant-sync] trigger=$trigger installationId=$installationId packageName=$packageName http=${response.statusCode} body=$body',
        );
        return UnlockGrantSyncResult(
          success: false,
          installationId: installationId,
          activeCount: activeLocal.length,
          hasActiveForPackage: _hasActiveForPackage(activeLocal, packageName, now),
          activeGrants: _activeGrantsFromMap(activeLocal),
          packageName: packageName,
          errorMessage: 'http_${response.statusCode}',
        );
      }

      final parsed = jsonDecode(body);
      if (parsed is! Map<String, dynamic>) {
        final activeLocal = _filterActive(
          _parseTemporaryUnlockedCsv(prefs.getString(_temporaryUnlockedKey) ?? ''),
          now,
        );
        return UnlockGrantSyncResult(
          success: false,
          installationId: installationId,
          activeCount: activeLocal.length,
          hasActiveForPackage: _hasActiveForPackage(activeLocal, packageName, now),
          activeGrants: _activeGrantsFromMap(activeLocal),
          packageName: packageName,
          errorMessage: 'invalid_json',
        );
      }

      final meta = (parsed['meta'] is Map<String, dynamic>)
          ? parsed['meta'] as Map<String, dynamic>
          : const <String, dynamic>{};
      final data = (parsed['data'] is Map<String, dynamic>)
          ? parsed['data'] as Map<String, dynamic>
          : const <String, dynamic>{};

      final requestId = (meta['requestId'] ?? data['requestId'])?.toString();
      final serverTime = (data['serverTime'] ?? meta['serverTime'])?.toString();
      final serverMillis = DateTime.tryParse(serverTime ?? '')?.millisecondsSinceEpoch ?? now;
      final ignoredGrantKeys = _parseIgnoredGrantKeys(
        prefs.getString(_ignoredUnlockGrantsKey) ?? '',
      );

      final grantsRaw = data['grants'];
      final remoteByPackage = <String, int>{};
      final remoteGrantDetails = <String, UnlockGrantActiveGrant>{};
      if (grantsRaw is List) {
        for (final item in grantsRaw) {
          if (item is! Map) continue;
          final package = (item['packageName'] ?? item['package_name'] ?? '')
              .toString()
              .trim();
          final grantRequestId = (item['requestId'] ?? item['request_id'] ?? '')
              .toString()
              .trim();
          if (package.isNotEmpty &&
              grantRequestId.isNotEmpty &&
              ignoredGrantKeys.contains('$package|$grantRequestId')) {
            continue;
          }
          final unlockUntil = (item['unlockUntil'] ?? item['unlock_until'] ?? '')
              .toString()
              .trim();
          if (package.isEmpty || unlockUntil.isEmpty) continue;

          final untilMillis = DateTime.tryParse(unlockUntil)?.millisecondsSinceEpoch;
          if (untilMillis == null || untilMillis <= serverMillis) continue;

          final existing = remoteByPackage[package];
          if (existing == null || untilMillis > existing) {
            remoteByPackage[package] = untilMillis;
            final requestId = grantRequestId;
            final appName = (item['appName'] ?? item['app_name'])?.toString();
            final minutesRaw = int.tryParse((item['minutes'] ?? '').toString());
            remoteGrantDetails[package] = UnlockGrantActiveGrant(
              packageName: package,
              unlockUntilMillis: untilMillis,
              requestId: (requestId == null || requestId.trim().isEmpty) ? null : requestId.trim(),
              appName: (appName == null || appName.trim().isEmpty) ? null : appName.trim(),
              minutes: minutesRaw,
            );
          }
        }
      }

      final localByPackage = _parseTemporaryUnlockedCsv(
        prefs.getString(_temporaryUnlockedKey) ?? '',
      );

      final merged = <String, int>{}..addAll(_filterActive(localByPackage, serverMillis));
      for (final entry in remoteByPackage.entries) {
        final current = merged[entry.key];
        if (current == null || entry.value > current) {
          merged[entry.key] = entry.value;
        }
      }

      final activeGrants = _activeGrantsFromMap(
        merged,
        remoteDetails: remoteGrantDetails,
      );

      await prefs.setString(
        _temporaryUnlockedKey,
        _serializeTemporaryUnlockedCsv(merged),
      );

      final hasActive = _hasActiveForPackage(merged, packageName, serverMillis);
      debugPrint(
        '[grant-sync] trigger=$trigger requestId=$requestId installationId=$installationId packageName=$packageName activeFound=$hasActive activeCount=${merged.length}',
      );

      return UnlockGrantSyncResult(
        success: true,
        installationId: installationId,
        requestId: requestId,
        serverTime: serverTime,
        activeCount: merged.length,
        hasActiveForPackage: hasActive,
        activeGrants: activeGrants,
        packageName: packageName,
      );
    } catch (e) {
      final activeLocal = _filterActive(
        _parseTemporaryUnlockedCsv(prefs.getString(_temporaryUnlockedKey) ?? ''),
        now,
      );
      debugPrint(
        '[grant-sync] trigger=$trigger installationId=$installationId packageName=$packageName error=$e',
      );
      return UnlockGrantSyncResult(
        success: false,
        installationId: installationId,
        activeCount: activeLocal.length,
        hasActiveForPackage: _hasActiveForPackage(activeLocal, packageName, now),
        activeGrants: _activeGrantsFromMap(activeLocal),
        packageName: packageName,
        errorMessage: e.toString(),
      );
    } finally {
      client?.close(force: true);
    }
  }

  Future<String> _getOrCreateInstallationId(SharedPreferences prefs) async {
    final existing = (prefs.getString(_installationIdKey) ?? '').trim();
    if (existing.isNotEmpty) return existing;

    final generated = _generateInstallationId();
    await prefs.setString(_installationIdKey, generated);
    return generated;
  }

  String _generateInstallationId() {
    final now = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final random = Random.secure().nextInt(1 << 31).toRadixString(16);
    return 'ins_${now}_$random';
  }

  Map<String, int> _parseTemporaryUnlockedCsv(String csv) {
    final unlocked = <String, int>{};
    if (csv.trim().isEmpty) return unlocked;

    for (final raw in csv.split(',')) {
      final entry = raw.trim();
      if (entry.isEmpty || !entry.contains('|')) continue;

      final separatorIndex = entry.indexOf('|');
      final packageName = entry.substring(0, separatorIndex).trim();
      final until = int.tryParse(entry.substring(separatorIndex + 1).trim());
      if (packageName.isEmpty || until == null) continue;

      final existing = unlocked[packageName];
      if (existing == null || until > existing) {
        unlocked[packageName] = until;
      }
    }

    return unlocked;
  }

  Map<String, int> _filterActive(Map<String, int> entries, int nowMillis) {
    return entries
      ..removeWhere((_, unlockUntilMillis) => unlockUntilMillis <= nowMillis);
  }

  String _serializeTemporaryUnlockedCsv(Map<String, int> unlocked) {
    return unlocked.entries.map((entry) => '${entry.key}|${entry.value}').join(',');
  }

  Set<String> _parseIgnoredGrantKeys(String csv) {
    final keys = <String>{};
    if (csv.trim().isEmpty) return keys;

    for (final raw in csv.split(',')) {
      final entry = raw.trim();
      if (entry.isEmpty || !entry.contains('|')) continue;

      final separatorIndex = entry.indexOf('|');
      final packageName = entry.substring(0, separatorIndex).trim();
      final requestId = entry.substring(separatorIndex + 1).trim();
      if (packageName.isEmpty || requestId.isEmpty) continue;

      keys.add('$packageName|$requestId');
    }
    return keys;
  }

  bool _hasActiveForPackage(
    Map<String, int> unlocked,
    String? packageName,
    int nowMillis,
  ) {
    final normalizedPackage = (packageName ?? '').trim();
    if (normalizedPackage.isEmpty) return false;
    final unlockUntil = unlocked[normalizedPackage];
    return unlockUntil != null && unlockUntil > nowMillis;
  }

  List<UnlockGrantActiveGrant> _activeGrantsFromMap(
    Map<String, int> entries, {
    Map<String, UnlockGrantActiveGrant>? remoteDetails,
  }) {
    final grants = entries.entries.map((entry) {
      final details = remoteDetails?[entry.key];
      return UnlockGrantActiveGrant(
        packageName: entry.key,
        unlockUntilMillis: entry.value,
        requestId: details?.requestId,
        appName: details?.appName,
        minutes: details?.minutes,
      );
    }).toList()
      ..sort((a, b) => a.unlockUntilMillis.compareTo(b.unlockUntilMillis));

    return grants;
  }
}
