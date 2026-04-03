import 'package:flutter/material.dart';

import '../services/unlock_grants_sync_service.dart';

class DebugSyncDiagnosticsData {
  final String installationId;
  final String? lastRequestId;
  final String? lastSyncSource;
  final DateTime? lastSyncAt;
  final bool? lastSyncOk;
  final String? lastSyncError;
  final String? lastEvaluatedPackage;
  final String? serverTime;
  final String temporaryCsv;
  final List<UnlockGrantActiveGrant> activeGrants;

  const DebugSyncDiagnosticsData({
    required this.installationId,
    required this.temporaryCsv,
    required this.activeGrants,
    this.lastRequestId,
    this.lastSyncSource,
    this.lastSyncAt,
    this.lastSyncOk,
    this.lastSyncError,
    this.lastEvaluatedPackage,
    this.serverTime,
  });
}

class DebugSyncDiagnosticsScreen extends StatefulWidget {
  final DebugSyncDiagnosticsData initialData;
  final Future<DebugSyncDiagnosticsData> Function({bool forceSync}) loadDiagnostics;

  const DebugSyncDiagnosticsScreen({
    required this.initialData,
    required this.loadDiagnostics,
    super.key,
  });

  @override
  State<DebugSyncDiagnosticsScreen> createState() => _DebugSyncDiagnosticsScreenState();
}

class _DebugSyncDiagnosticsScreenState extends State<DebugSyncDiagnosticsScreen> {
  late DebugSyncDiagnosticsData _data;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _data = widget.initialData;
  }

  Future<void> _refreshDiagnostics() async {
    if (_isRefreshing) return;
    setState(() {
      _isRefreshing = true;
    });

    try {
      final updated = await widget.loadDiagnostics(forceSync: true);
      if (!mounted) return;
      setState(() {
        _data = updated;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return '-';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    final second = value.second.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute:$second';
  }

  String _formatUntil(int millis) {
    return _formatDateTime(DateTime.fromMillisecondsSinceEpoch(millis));
  }

  @override
  Widget build(BuildContext context) {
    final statusText = _data.lastSyncOk == null
        ? 'Sin sync registrado'
        : _data.lastSyncOk!
            ? 'OK'
            : 'ERROR';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostico sync remoto'),
        actions: [
          IconButton(
            onPressed: _isRefreshing ? null : _refreshDiagnostics,
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Estado del ultimo sync',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text('Estado: $statusText'),
                  Text('Origen: ${_data.lastSyncSource ?? '-'}'),
                  Text('Hora local: ${_formatDateTime(_data.lastSyncAt)}'),
                  Text('serverTime: ${_data.serverTime ?? '-'}'),
                  Text('requestId: ${_data.lastRequestId ?? '-'}'),
                  Text('package evaluado: ${_data.lastEvaluatedPackage ?? '-'}'),
                  Text(
                    'error: ${(_data.lastSyncError == null || _data.lastSyncError!.isEmpty) ? '-' : _data.lastSyncError}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Identidad instalacion',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    _data.installationId.isEmpty ? '-' : _data.installationId,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Grants activos (${_data.activeGrants.length})',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  if (_data.activeGrants.isEmpty)
                    const Text('No hay grants activos')
                  else
                    ..._data.activeGrants.map((grant) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                grant.appName?.trim().isNotEmpty == true
                                    ? '${grant.appName} (${grant.packageName})'
                                    : grant.packageName,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text('Hasta: ${_formatUntil(grant.unlockUntilMillis)}'),
                              Text('requestId: ${grant.requestId ?? '-'}'),
                              Text('minutes: ${grant.minutes?.toString() ?? '-'}'),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'temporary_unlocked_packages_csv',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(_data.temporaryCsv.isEmpty ? '(vacio)' : _data.temporaryCsv),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
