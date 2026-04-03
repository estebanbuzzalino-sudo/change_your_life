import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class _PendingRequestsScreenState extends State<PendingRequestsScreen> {
  static const String _pendingRequestsKey = 'pending_unlock_requests_csv';

  bool isLoading = true;
  List<PendingUnlockRequest> pendingRequests = [];

  @override
  void initState() {
    super.initState();
    _loadPendingRequests();
  }

  Future<void> _loadPendingRequests() async {
    final prefs = await SharedPreferences.getInstance();
    final csv = prefs.getString(_pendingRequestsKey) ?? '';
    final requestMap = _parsePendingRequests(csv);
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
      isLoading = false;
    });
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
      } else if (parsed.requestedAtMillis != null && parsed.requestedAtMillis! > existing) {
        requests[parsed.packageName] = parsed.requestedAtMillis;
      }
    }

    return requests;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitudes pendientes'),
        actions: [
          IconButton(
            onPressed: _loadPendingRequests,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : pendingRequests.isEmpty
              ? const Center(child: Text('No hay solicitudes pendientes'))
              : ListView.builder(
                  itemCount: pendingRequests.length,
                  itemBuilder: (context, index) {
                    final request = pendingRequests[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        title: Text(request.packageName),
                        subtitle: Text(
                          'Solicitada: ${_formatRequestedAt(request.requestedAtMillis)}',
                        ),
                        trailing: const Chip(
                          label: Text('Pendiente'),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
