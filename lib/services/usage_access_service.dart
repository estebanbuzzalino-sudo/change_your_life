import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:usage_stats/usage_stats.dart';

class UsageAccessService {
  Future<bool> hasPermission() async {
    if (!Platform.isAndroid) return false;

    try {
      return await UsageStats.checkUsagePermission() ?? false;
    } catch (e) {
      debugPrint('[usage-access] hasPermission error: $e');
      return false;
    }
  }

  Future<void> requestPermission() async {
    if (!Platform.isAndroid) return;
    await UsageStats.grantUsagePermission();
  }

  Future<String?> getCurrentForegroundApp({
    required String ownPackageName,
  }) async {
    if (!Platform.isAndroid) return null;

    try {
      final now = DateTime.now();
      final start = now.subtract(const Duration(minutes: 10));

      final usageStats = await UsageStats.queryUsageStats(start, now);

      if (usageStats.isEmpty) return null;

      usageStats.removeWhere(
        (item) =>
            item.packageName == null ||
            item.packageName!.isEmpty ||
            item.lastTimeUsed == null ||
            item.lastTimeUsed!.isEmpty,
      );

      if (usageStats.isEmpty) return null;

      usageStats.sort((a, b) {
        final aTime = int.tryParse(a.lastTimeUsed ?? '0') ?? 0;
        final bTime = int.tryParse(b.lastTimeUsed ?? '0') ?? 0;
        return bTime.compareTo(aTime);
      });

      const ignoredPackages = {
        'com.example.change_your_life',
        'com.google.android.gms',
        'com.android.systemui',
        'com.google.android.permissioncontroller',
        'com.android.launcher3',
      };

      for (final item in usageStats) {
        final pkg = item.packageName;
        if (pkg == null || pkg.isEmpty) continue;
        if (pkg != ownPackageName && !ignoredPackages.contains(pkg)) {
          return pkg;
        }
      }

      return null;
    } catch (e) {
      debugPrint('[usage-access] getCurrentForegroundApp error: $e');
      return null;
    }
  }
}
