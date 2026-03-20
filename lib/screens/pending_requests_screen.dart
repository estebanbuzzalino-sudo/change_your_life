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
  static const String _temporaryUnlockedKey = 'temporary_unlocked_packages_csv';
  static const Duration _temporaryUnlockDuration = Duration(minutes: 60);

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

  Future<void> _approveRequest(PendingUnlockRequest request) async {
    final prefs = await SharedPreferences.getInstance();

    final pendingMap = _parsePendingRequests(
      prefs.getString(_pendingRequestsKey) ?? '',
    );
    pendingMap.remove(request.packageName);
    await prefs.setString(_pendingRequestsKey, _serializePendingRequests(pendingMap));

    final temporaryMap = _parseTemporaryUnlocked(
      prefs.getString(_temporaryUnlockedKey) ?? '',
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    final unlockUntil = now + _temporaryUnlockDuration.inMilliseconds;
    temporaryMap[request.packageName] = unlockUntil;
    await prefs.setString(
      _temporaryUnlockedKey,
      _serializeTemporaryUnlocked(temporaryMap),
    );

    if (!mounted) return;

    setState(() {
      pendingRequests.removeWhere((item) => item.packageName == request.packageName);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Solicitud aprobada por 60 minutos.')),
    );
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
      final packageName = entry.substringBefore('|').trim();
      if (packageName.isEmpty) return null;
      final timestamp = int.tryParse(entry.substringAfter('|').trim());
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

  String _serializePendingRequests(Map<String, int?> requests) {
    return requests.entries.map((entry) {
      final ts = entry.value;
      if (ts == null) return entry.key;
      return '${entry.key}|$ts';
    }).join(',');
  }

  Map<String, int> _parseTemporaryUnlocked(String csv) {
    final unlocked = <String, int>{};
    if (csv.trim().isEmpty) return unlocked;

    for (final raw in csv.split(',')) {
      final entry = raw.trim();
      if (entry.isEmpty || !entry.contains('|')) continue;

      final packageName = entry.substringBefore('|').trim();
      final until = int.tryParse(entry.substringAfter('|').trim());
      if (packageName.isEmpty || until == null) continue;

      final existing = unlocked[packageName];
      if (existing == null || until > existing) {
        unlocked[packageName] = until;
      }
    }

    return unlocked;
  }

  String _serializeTemporaryUnlocked(Map<String, int> unlocked) {
    return unlocked.entries.map((entry) => '${entry.key}|${entry.value}').join(',');
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
                        trailing: ElevatedButton(
                          onPressed: () => _approveRequest(request),
                          child: const Text('Aprobar'),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
