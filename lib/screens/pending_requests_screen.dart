import 'dart:async';

import 'package:flutter/material.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/unlock_grants_sync_service.dart';
import '../services/unlock_request_resender.dart';
import '../theme/app_theme.dart';

class PendingUnlockRequest {
  final String packageName;
  final int? requestedAtMillis;

  const PendingUnlockRequest({
    required this.packageName,
    required this.requestedAtMillis,
  });
}

class PendingRequestsScreen extends StatefulWidget {
  const PendingRequestsScreen({super.key});

  @override
  State<PendingRequestsScreen> createState() => _PendingRequestsScreenState();
}

class _PendingRequestsScreenState extends State<PendingRequestsScreen>
    with WidgetsBindingObserver {
  static const String _pendingRequestsKey = 'pending_unlock_requests_csv';
  static const String _temporaryUnlockedKey = 'temporary_unlocked_packages_csv';
  static const Duration _autoRefreshInterval = Duration(seconds: 12);

  final UnlockGrantsSyncService _syncService = UnlockGrantsSyncService();
  final UnlockRequestResender _resender = UnlockRequestResender();

  bool isLoading = true;
  List<PendingUnlockRequest> pendingRequests = [];
  Map<String, int> approvedUntilByPackage = {};
  Map<String, String> appNameByPackage = {};
  Set<String> resendingPackages = {};
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshAll(triggerSync: true);
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshAll(triggerSync: true);
      _startAutoRefresh();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _autoRefreshTimer?.cancel();
    }
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (_) {
      _refreshAll(triggerSync: true);
    });
  }

  Future<void> _refreshAll({required bool triggerSync}) async {
    if (triggerSync) {
      await _syncService.syncActiveGrants(trigger: 'pending_requests_screen');
    }
    await _loadPendingRequests();
    await _loadAppNames();
  }

  Future<void> _loadPendingRequests() async {
    final prefs = await SharedPreferences.getInstance();
    final csv = prefs.getString(_pendingRequestsKey) ?? '';
    final approvedCsv = prefs.getString(_temporaryUnlockedKey) ?? '';
    final requestMap = _parsePendingRequests(csv);
    final approved = _parseApprovedUnlocks(approvedCsv);
    final requests = requestMap.entries
        .map(
          (entry) => PendingUnlockRequest(
            packageName: entry.key,
            requestedAtMillis: entry.value,
          ),
        )
        .toList()
      ..sort((a, b) {
        final aTs = a.requestedAtMillis ?? 0;
        final bTs = b.requestedAtMillis ?? 0;
        return bTs.compareTo(aTs);
      });

    if (!mounted) return;
    setState(() {
      pendingRequests = requests;
      approvedUntilByPackage = approved;
      isLoading = false;
    });
  }

  Future<void> _loadAppNames() async {
    final missing = pendingRequests
        .map((r) => r.packageName)
        .where((pkg) => !appNameByPackage.containsKey(pkg))
        .toSet();
    if (missing.isEmpty) return;

    for (final pkg in missing) {
      try {
        final info = await InstalledApps.getAppInfo(pkg);
        if (info != null && info.name.isNotEmpty) {
          appNameByPackage[pkg] = info.name;
        }
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {});
  }

  Map<String, int?> _parsePendingRequests(String csv) {
    final requests = <String, int?>{};
    if (csv.trim().isEmpty) return requests;

    for (final raw in csv.split(',')) {
      final entry = raw.trim();
      if (entry.isEmpty) continue;

      final parsed = _parsePendingEntry(entry);
      if (parsed == null) continue;

      final existing = requests[parsed.packageName];
      if (existing == null) {
        requests[parsed.packageName] = parsed.requestedAtMillis;
      } else if (parsed.requestedAtMillis != null &&
          parsed.requestedAtMillis! > existing) {
        requests[parsed.packageName] = parsed.requestedAtMillis;
      }
    }

    return requests;
  }

  Map<String, int> _parseApprovedUnlocks(String csv) {
    final approved = <String, int>{};
    if (csv.trim().isEmpty) return approved;
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final raw in csv.split(',')) {
      final entry = raw.trim();
      if (entry.isEmpty || !entry.contains('|')) continue;
      final parts = entry.split('|');
      final pkg = parts.first.trim();
      final until = int.tryParse(parts.length > 1 ? parts[1].trim() : '');
      if (pkg.isEmpty || until == null || until <= now) continue;
      final existing = approved[pkg];
      if (existing == null || until > existing) {
        approved[pkg] = until;
      }
    }
    return approved;
  }

  PendingUnlockRequest? _parsePendingEntry(String entry) {
    if (entry.contains('|')) {
      final parts = entry.split('|');
      final packageName = parts.first.trim();
      if (packageName.isEmpty) return null;
      final timestampText = parts.length > 1 ? parts[1].trim() : '';
      final timestamp = int.tryParse(timestampText);
      return PendingUnlockRequest(
        packageName: packageName,
        requestedAtMillis: timestamp,
      );
    }

    if (entry.trim().isEmpty) return null;
    return PendingUnlockRequest(
      packageName: entry.trim(),
      requestedAtMillis: null,
    );
  }

  String _formatRequestedAt(int? millis) {
    if (millis == null) return 'Sin fecha';
    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year.toString();
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  String _formatRemaining(int unlockUntilMillis) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final remainingMs = unlockUntilMillis - now;
    if (remainingMs <= 0) return 'expirando';
    final totalMinutes = (remainingMs / 60000).ceil();
    if (totalMinutes < 60) return '$totalMinutes min';
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours < 24) return '${hours}h ${minutes}m';
    final days = hours ~/ 24;
    final remainingHours = hours % 24;
    return '${days}d ${remainingHours}h';
  }

  Future<void> _resendRequest(PendingUnlockRequest request) async {
    final pkg = request.packageName;
    if (resendingPackages.contains(pkg)) return;
    setState(() {
      resendingPackages.add(pkg);
    });

    final result = await _resender.resend(
      packageName: pkg,
      appName: appNameByPackage[pkg],
    );

    if (!mounted) return;
    setState(() {
      resendingPackages.remove(pkg);
    });

    final messenger = ScaffoldMessenger.of(context);
    if (result.success) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Solicitud reenviada al amigo responsable.'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo reenviar: ${result.errorMessage ?? 'error desconocido'}',
          ),
          backgroundColor: const Color(0xFFC62828),
        ),
      );
    }
  }

  Widget _buildStatusChip(PendingUnlockRequest request) {
    final until = approvedUntilByPackage[request.packageName];
    if (until != null) {
      return Chip(
        avatar: const Icon(Icons.check_circle, color: Colors.white, size: 18),
        label: Text('Aprobada · ${_formatRemaining(until)}'),
        backgroundColor: AppColors.primaryMuted,
        labelStyle: const TextStyle(color: Colors.white),
      );
    }
    return const Chip(
      avatar: Icon(Icons.hourglass_top, color: Colors.white, size: 18),
      label: Text('Pendiente'),
      backgroundColor: AppColors.orange,
      labelStyle: TextStyle(color: Colors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitudes pendientes'),
        actions: [
          IconButton(
            tooltip: 'Refrescar ahora',
            onPressed: () => _refreshAll(triggerSync: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : pendingRequests.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          size: 72,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Todo tranquilo',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'No tenés solicitudes de desbloqueo pendientes.\nCuando pidas una, aparecerá acá.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _refreshAll(triggerSync: true),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: pendingRequests.length,
                    itemBuilder: (context, index) {
                      final request = pendingRequests[index];
                      final pkg = request.packageName;
                      final isApproved =
                          approvedUntilByPackage.containsKey(pkg);
                      final isResending = resendingPackages.contains(pkg);
                      final displayName = appNameByPackage[pkg] ?? pkg;

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          displayName,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Solicitada: ${_formatRequestedAt(request.requestedAtMillis)}',
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _buildStatusChip(request),
                                ],
                              ),
                              if (!isApproved) ...[
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: isResending
                                        ? null
                                        : () => _resendRequest(request),
                                    icon: isResending
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.send),
                                    label: Text(
                                      isResending
                                          ? 'Reenviando...'
                                          : 'Reenviar al amigo',
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
