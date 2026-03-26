import 'dart:convert';
import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_block.dart';
import '../services/usage_access_service.dart';
import 'apps_selection_screen.dart';
import 'friend_screen.dart';
import 'block_screen.dart';
import 'pending_requests_screen.dart';

class _TemporaryUnlockInfo {
  final String packageName;
  final int unlockedUntilMillis;

  const _TemporaryUnlockInfo({
    required this.packageName,
    required this.unlockedUntilMillis,
  });
}

class _PendingRequestRecord {
  final String packageName;
  final int? requestedAtMillis;
  final String? requestId;

  const _PendingRequestRecord({
    required this.packageName,
    required this.requestedAtMillis,
    required this.requestId,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _temporaryUnlockedKey = 'temporary_unlocked_packages_csv';
  static const String _pendingRequestsKey = 'pending_unlock_requests_csv';
  static const String _approvedRequestIdsKey = 'approved_unlock_request_ids_csv';
  static const int _defaultDeepLinkUnlockMinutes = 60;
  String selectedDurationType = 'Días';
  double selectedValue = 7;

  final List<Map<String, String>> selectedApps = [];
  String? friendName;
  String? friendEmail;

  bool isLoading = true;
  List<AppBlock> activeBlocks = [];

  final UsageAccessService _usageAccessService = UsageAccessService();
  bool hasUsagePermission = false;
  String currentForegroundApp = 'No detectada';
  List<_TemporaryUnlockInfo> temporaryUnlockedApps = [];
  Timer? _temporaryUnlockTimer;
  final Map<String, String> _appNameCache = {};
  bool _isResolvingAppNames = false;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _deepLinkSubscription;
  String? _lastHandledDeepLink;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
    _checkUsagePermission();
    _startTemporaryUnlockTimer();
    _setupDeepLinks();
  }

  @override
  void dispose() {
    _temporaryUnlockTimer?.cancel();
    _deepLinkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedBlocks = prefs.getStringList('activeBlocks') ?? [];
    final savedApps = prefs.getStringList('selectedApps') ?? [];

    final decodedApps = savedApps
        .map((item) => Map<String, String>.from(jsonDecode(item)))
        .toList();

    final decodedBlocks = savedBlocks
        .map((item) => AppBlock.fromMap(jsonDecode(item)))
        .toList();

    setState(() {
      selectedDurationType = prefs.getString('durationType') ?? 'Días';
      selectedValue = prefs.getDouble('durationValue') ?? 7;

      selectedApps
        ..clear()
        ..addAll(decodedApps);

      friendName = prefs.getString('friendName');
      friendEmail = prefs.getString('friendEmail');

      activeBlocks = decodedBlocks;
      isLoading = false;
    });

    _seedAppNameCacheFromKnownData();
    await _saveBlockedPackagesForAndroid();
    await _loadTemporaryUnlockedApps();
  }

  Future<void> _setupDeepLinks() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        await _handleIncomingDeepLink(initialUri);
      }

      _deepLinkSubscription = _appLinks.uriLinkStream.listen(
        (uri) {
          _handleIncomingDeepLink(uri);
        },
        onError: (_) {
          // Keep default behavior if deep links fail.
        },
      );
    } catch (_) {
      // Keep default behavior if deep links fail.
    }
  }

  Future<void> _handleIncomingDeepLink(Uri uri) async {
    if (!_isApprovalDeepLink(uri)) return;

    final rawUri = uri.toString();
    if (_lastHandledDeepLink == rawUri) return;
    _lastHandledDeepLink = rawUri;

    await _applyDeepLinkApproval(uri);
  }

  bool _isApprovalDeepLink(Uri uri) {
    final normalizedPath = uri.path.startsWith('/') ? uri.path : '/${uri.path}';
    return uri.scheme == 'changeyourlife' &&
        uri.host == 'unlock' &&
        normalizedPath == '/approve';
  }

  Future<void> _applyDeepLinkApproval(Uri uri) async {
    final packageName = (uri.queryParameters['package'] ?? '').trim();
    final requestId = (uri.queryParameters['requestId'] ?? '').trim();
    final requestedAt = int.tryParse(uri.queryParameters['requestedAt'] ?? '');
    final minutesRaw = int.tryParse(uri.queryParameters['minutes'] ?? '');
    final contractVersion = (uri.queryParameters['v'] ?? '').trim();
    final minutes = (minutesRaw != null && minutesRaw > 0)
        ? minutesRaw
        : _defaultDeepLinkUnlockMinutes;

    if (contractVersion.isNotEmpty && contractVersion != '1') {
      if (mounted) {
        _showMessage('Link de aprobacion no compatible.');
      }
      return;
    }

    if (packageName.isEmpty) {
      if (mounted) {
        _showMessage('Link de aprobacion invalido: falta package.');
      }
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final approvedRequestIds = _parseCsvSet(
      prefs.getString(_approvedRequestIdsKey) ?? '',
    );
    if (requestId.isNotEmpty && approvedRequestIds.contains(requestId)) {
      if (mounted) {
        _showMessage('Esta solicitud ya fue aprobada anteriormente.');
      }
      return;
    }

    final pendingRequests = _parsePendingRequestsCsv(
      prefs.getString(_pendingRequestsKey) ?? '',
    );
    final removedByPackage = pendingRequests.remove(packageName) != null;
    if (!removedByPackage && requestId.isNotEmpty) {
      pendingRequests.removeWhere((_, request) {
        if (request.requestId != requestId) return false;
        if (requestedAt == null) return true;
        return request.requestedAtMillis == requestedAt;
      });
    }
    await prefs.setString(
      _pendingRequestsKey,
      _serializePendingRequestsCsv(pendingRequests),
    );

    final temporaryUnlocked = _parseTemporaryUnlockedCsv(
      prefs.getString(_temporaryUnlockedKey) ?? '',
    );
    final unlockUntil = DateTime.now()
        .add(Duration(minutes: minutes))
        .millisecondsSinceEpoch;
    temporaryUnlocked[packageName] = unlockUntil;
    await prefs.setString(
      _temporaryUnlockedKey,
      _serializeTemporaryUnlockedCsv(temporaryUnlocked),
    );
    if (requestId.isNotEmpty) {
      approvedRequestIds.add(requestId);
      await prefs.setString(
        _approvedRequestIdsKey,
        _serializeCsvSet(approvedRequestIds),
      );
    }

    await _loadTemporaryUnlockedApps();

    if (!mounted) return;
    _showMessage('Aprobacion local aplicada por $minutes min para $packageName.');
  }

  Map<String, _PendingRequestRecord> _parsePendingRequestsCsv(String csv) {
    final requests = <String, _PendingRequestRecord>{};
    if (csv.trim().isEmpty) return requests;

    for (final raw in csv.split(',')) {
      final entry = raw.trim();
      if (entry.isEmpty) continue;

      final parts = entry.split('|');
      final packageName = parts.first.trim();
      if (packageName.isEmpty) continue;

      final timestamp = parts.length > 1 ? int.tryParse(parts[1].trim()) : null;
      final requestId = parts.length > 2 ? parts[2].trim() : null;

      final parsed = _PendingRequestRecord(
        packageName: packageName,
        requestedAtMillis: timestamp,
        requestId: requestId == null || requestId.isEmpty ? null : requestId,
      );

      final existing = requests[packageName];
      if (existing == null) {
        requests[packageName] = parsed;
        continue;
      }

      final existingTs = existing.requestedAtMillis ?? 0;
      final parsedTs = parsed.requestedAtMillis ?? 0;
      if (parsedTs > existingTs) {
        requests[packageName] = parsed;
      }
    }

    return requests;
  }

  String _serializePendingRequestsCsv(Map<String, _PendingRequestRecord> requests) {
    return requests.values.map((request) {
      final ts = request.requestedAtMillis ?? DateTime.now().millisecondsSinceEpoch;
      final requestId = request.requestId?.trim() ?? '';
      if (requestId.isEmpty) {
        return '${request.packageName}|$ts';
      }
      return '${request.packageName}|$ts|$requestId';
    }).join(',');
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

  String _serializeTemporaryUnlockedCsv(Map<String, int> unlocked) {
    return unlocked.entries.map((entry) => '${entry.key}|${entry.value}').join(',');
  }

  Set<String> _parseCsvSet(String csv) {
    final values = <String>{};
    if (csv.trim().isEmpty) return values;

    for (final raw in csv.split(',')) {
      final value = raw.trim();
      if (value.isEmpty) continue;
      values.add(value);
    }
    return values;
  }

  String _serializeCsvSet(Set<String> values) {
    return values.map((value) => value.trim()).where((value) => value.isNotEmpty).join(',');
  }

  void _seedAppNameCacheFromKnownData() {
    var changed = false;

    for (final app in selectedApps) {
      final packageName = (app['packageName'] ?? '').trim();
      final appName = (app['appName'] ?? '').trim();
      if (packageName.isEmpty || appName.isEmpty) continue;
      if (_appNameCache[packageName] == appName) continue;

      _appNameCache[packageName] = appName;
      changed = true;
    }

    for (final block in activeBlocks) {
      final packageName = block.packageName.trim();
      final appName = block.appName.trim();
      if (packageName.isEmpty || appName.isEmpty) continue;
      if (_appNameCache[packageName] == appName) continue;

      _appNameCache[packageName] = appName;
      changed = true;
    }

    if (changed && mounted) {
      setState(() {});
    }
  }

  String _displayNameForPackage(String packageName) {
    final normalized = packageName.trim();
    if (normalized.isEmpty) return packageName;
    return _appNameCache[normalized] ?? normalized;
  }

  Future<void> _resolveTemporaryUnlockedAppNames() async {
    if (_isResolvingAppNames) return;

    _seedAppNameCacheFromKnownData();

    final missingPackages = temporaryUnlockedApps
        .map((item) => item.packageName.trim())
        .where((pkg) => pkg.isNotEmpty && !_appNameCache.containsKey(pkg))
        .toSet();

    if (missingPackages.isEmpty) return;

    _isResolvingAppNames = true;
    try {
      final installedApps = await InstalledApps.getInstalledApps(
        excludeSystemApps: false,
        excludeNonLaunchableApps: false,
        withIcon: false,
      );

      if (!mounted) return;

      var changed = false;
      for (final app in installedApps) {
        final packageName = app.packageName.trim();
        if (!missingPackages.contains(packageName)) continue;

        final appName = app.name.trim();
        if (appName.isEmpty) continue;

        if (_appNameCache[packageName] != appName) {
          _appNameCache[packageName] = appName;
          changed = true;
        }
      }

      if (changed && mounted) {
        setState(() {});
      }
    } catch (_) {
      // Fallback: keep using packageName in UI.
    } finally {
      _isResolvingAppNames = false;
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('durationType', selectedDurationType);
    await prefs.setDouble('durationValue', selectedValue);
    await prefs.setStringList(
      'selectedApps',
      selectedApps.map((app) => jsonEncode(app)).toList(),
    );
    await prefs.setString('friendName', friendName ?? '');
    await prefs.setString('friendEmail', friendEmail ?? '');
  }

  Future<void> _saveBlocks() async {
    final prefs = await SharedPreferences.getInstance();

    final encodedBlocks =
        activeBlocks.map((block) => jsonEncode(block.toMap())).toList();

    await prefs.setStringList('activeBlocks', encodedBlocks);
  }

  Future<void> _saveBlockedPackagesForAndroid() async {
    final prefs = await SharedPreferences.getInstance();

    final packages = activeBlocks
        .map((block) => block.packageName)
        .where((pkg) => pkg.isNotEmpty)
        .toSet()
        .toList();

    await prefs.setString('blocked_packages_csv', packages.join(','));
  }

  Future<void> _checkUsagePermission() async {
    final granted = await _usageAccessService.hasPermission();
    if (!mounted) return;

    setState(() {
      hasUsagePermission = granted;
    });
  }

  Future<void> _requestUsagePermission() async {
    await _usageAccessService.requestPermission();
    await Future.delayed(const Duration(seconds: 2));
    await _checkUsagePermission();
  }

  Future<void> _detectCurrentApp() async {
    final packageName = await _usageAccessService.getCurrentForegroundApp(
      ownPackageName: 'com.example.change_your_life',
    );

    if (!mounted) return;

    setState(() {
      currentForegroundApp = packageName ?? 'No detectada';
    });
  }

  Future<void> _openAppsSelection() async {
    final result = await Navigator.push<List<Map<String, String>>>(
      context,
      MaterialPageRoute(
        builder: (_) => AppsSelectionScreen(
          initialSelectedApps: selectedApps,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        selectedApps
          ..clear()
          ..addAll(result);
      });
      _seedAppNameCacheFromKnownData();
      await _saveData();
    }
  }

  Future<void> _openFriendScreen() async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => FriendScreen(
          initialName: friendName,
          initialEmail: friendEmail,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        friendName = result['name'];
        friendEmail = result['email'];
      });
      await _saveData();
    }
  }

  Future<void> _openPendingRequestsScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PendingRequestsScreen(),
      ),
    );
    await _loadTemporaryUnlockedApps();
  }

  Future<void> _openDeepLinkTestTool() async {
    final controller = TextEditingController();
    try {
      final input = await showDialog<String>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Procesar link de aprobacion'),
            content: TextField(
              controller: controller,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Pegá el link changeyourlife://...',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(controller.text),
                child: const Text('Procesar'),
              ),
            ],
          );
        },
      );

      if (input == null) return;

      final candidate = _extractDeepLinkCandidate(input);
      if (candidate == null) {
        _showMessage('No se encontro un deep link valido.');
        return;
      }

      final uri = Uri.tryParse(candidate);
      if (uri == null) {
        _showMessage('Formato de deep link invalido.');
        return;
      }

      if (!_isApprovalDeepLink(uri)) {
        _showMessage('El link no corresponde a aprobacion local.');
        return;
      }

      await _handleIncomingDeepLink(uri);
    } finally {
      controller.dispose();
    }
  }

  String? _extractDeepLinkCandidate(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('changeyourlife://')) return trimmed;

    final match = RegExp(r'changeyourlife://\S+').firstMatch(trimmed);
    return match?.group(0);
  }

  void _startTemporaryUnlockTimer() {
    _temporaryUnlockTimer?.cancel();
    _temporaryUnlockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      setState(() {
        temporaryUnlockedApps = temporaryUnlockedApps
            .where((item) => item.unlockedUntilMillis > now)
            .toList();
      });
    });
  }

  Future<void> _loadTemporaryUnlockedApps() async {
    final prefs = await SharedPreferences.getInstance();
    final csv = prefs.getString(_temporaryUnlockedKey) ?? '';
    final now = DateTime.now().millisecondsSinceEpoch;
    final latestByPackage = <String, int>{};

    for (final raw in csv.split(',')) {
      final entry = raw.trim();
      if (entry.isEmpty) continue;

      final separatorIndex = entry.indexOf('|');
      if (separatorIndex <= 0) continue;

      final packageName = entry.substring(0, separatorIndex).trim();
      final unlockedUntil = int.tryParse(entry.substring(separatorIndex + 1).trim());
      if (packageName.isEmpty || unlockedUntil == null) continue;
      if (unlockedUntil <= now) continue;

      final existing = latestByPackage[packageName];
      if (existing == null || unlockedUntil > existing) {
        latestByPackage[packageName] = unlockedUntil;
      }
    }

    final loaded = latestByPackage.entries
        .map(
          (entry) => _TemporaryUnlockInfo(
            packageName: entry.key,
            unlockedUntilMillis: entry.value,
          ),
        )
        .toList()
      ..sort((a, b) => a.unlockedUntilMillis.compareTo(b.unlockedUntilMillis));

    if (!mounted) return;
    setState(() {
      temporaryUnlockedApps = loaded;
    });
    await _resolveTemporaryUnlockedAppNames();
  }

  int _remainingMinutes(_TemporaryUnlockInfo info) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final remainingMillis = info.unlockedUntilMillis - now;
    if (remainingMillis <= 0) return 0;
    return (remainingMillis / Duration.millisecondsPerMinute).ceil();
  }

  String get durationText {
    final value = selectedValue.round();
    if (selectedDurationType == 'Días') {
      return value == 1 ? '1 día' : '$value días';
    } else {
      return value == 1 ? '1 mes' : '$value meses';
    }
  }

  Future<void> _activateBlock() async {
    if (selectedApps.isEmpty) {
      _showMessage('Primero elegí al menos una app para bloquear.');
      return;
    }

    if (friendName == null ||
        friendName!.isEmpty ||
        friendEmail == null ||
        friendEmail!.isEmpty) {
      _showMessage('Primero elegí un amigo responsable.');
      return;
    }

    final now = DateTime.now();

    for (final app in selectedApps) {
      final packageName = app['packageName'] ?? '';
      final appName = app['appName'] ?? 'App sin nombre';

      final alreadyBlocked = activeBlocks.any(
        (block) => block.packageName == packageName,
      );

      if (alreadyBlocked) {
        continue;
      }

      final endDate = selectedDurationType == 'Días'
          ? now.add(Duration(days: selectedValue.round()))
          : DateTime(
              now.year,
              now.month + selectedValue.round(),
              now.day,
              now.hour,
              now.minute,
              now.second,
            );

      activeBlocks.add(
        AppBlock(
          appName: appName,
          packageName: packageName,
          durationType: selectedDurationType,
          durationValue: selectedValue.round(),
          friendName: friendName!,
          friendEmail: friendEmail!,
          startDate: now,
          endDate: endDate,
        ),
      );
    }

    await _saveBlocks();
    await _saveBlockedPackagesForAndroid();

    if (!mounted) return;

    setState(() {});
    _seedAppNameCacheFromKnownData();

    _showMessage('Bloqueos activados correctamente.');
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> _clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('durationType');
    await prefs.remove('durationValue');
    await prefs.remove('selectedApps');
    await prefs.remove('friendName');
    await prefs.remove('friendEmail');
    await prefs.remove('activeBlocks');
    await prefs.remove('blocked_packages_csv');
    await prefs.remove('pending_unlock_requests_csv');
    await prefs.remove('temporary_unlocked_packages_csv');
    await prefs.remove(_approvedRequestIdsKey);

    setState(() {
      selectedDurationType = 'Días';
      selectedValue = 7;
      selectedApps.clear();
      friendName = null;
      friendEmail = null;
      activeBlocks.clear();
      temporaryUnlockedApps.clear();
      _appNameCache.clear();
      currentForegroundApp = 'No detectada';
    });

    _showMessage('Datos borrados.');
  }

  void _openBlockScreen(AppBlock block) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlockScreen(
          appName: block.appName,
          packageName: block.packageName,
          friendName: block.friendName,
          endDate: block.endDate,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxValue = selectedDurationType == 'Días' ? 30.0 : 12.0;
    final divisions = selectedDurationType == 'Días' ? 29 : 11;

    if (selectedValue > maxValue) {
      selectedValue = maxValue;
    }

    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Change Your Life in Community'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Reducí redes sociales y convertí ese tiempo en hábitos saludables.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            const Text(
              'Tipo de duración',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment<String>(
                  value: 'Días',
                  label: Text('Días'),
                ),
                ButtonSegment<String>(
                  value: 'Meses',
                  label: Text('Meses'),
                ),
              ],
              selected: {selectedDurationType},
              onSelectionChanged: (newSelection) async {
                setState(() {
                  selectedDurationType = newSelection.first;
                  selectedValue = selectedDurationType == 'Días' ? 7 : 1;
                });
                await _saveData();
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Duración elegida: $durationText',
              style: const TextStyle(fontSize: 16),
            ),
            Slider(
              value: selectedValue,
              min: 1,
              max: maxValue,
              divisions: divisions,
              label: durationText,
              onChanged: (value) async {
                setState(() {
                  selectedValue = value;
                });
                await _saveData();
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _openAppsSelection,
              child: const Text('Elegir Apps a Bloquear'),
            ),
            const SizedBox(height: 10),
            if (selectedApps.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Apps seleccionadas: ${selectedApps.map((e) => e['appName']).join(', ')}',
                  ),
                ),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _openFriendScreen,
              child: const Text('Elegir Amigo Responsable'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _openPendingRequestsScreen,
              child: const Text('Ver solicitudes pendientes'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _openDeepLinkTestTool,
              child: const Text('Procesar link (test local)'),
            ),
            const SizedBox(height: 10),
            if (friendName != null &&
                friendName!.isNotEmpty &&
                friendEmail != null &&
                friendEmail!.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Amigo responsable: $friendName\nEmail: $friendEmail',
                  ),
                ),
              ),
            if (temporaryUnlockedApps.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Desbloqueos temporales activos',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...temporaryUnlockedApps.map((item) {
                final remaining = _remainingMinutes(item);
                return Card(
                  child: ListTile(
                    title: Text(_displayNameForPackage(item.packageName)),
                    subtitle: Text(
                      'Package: ${item.packageName}\nTiempo restante: $remaining min',
                    ),
                  ),
                );
              }),
            ],
            const SizedBox(height: 24),
            const Text(
              'Detección de app en uso',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasUsagePermission
                          ? 'Permiso Usage Access: concedido'
                          : 'Permiso Usage Access: no concedido',
                    ),
                    const SizedBox(height: 8),
                    Text('App detectada: $currentForegroundApp'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _requestUsagePermission,
                      child: const Text('Dar permiso Usage Access'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _detectCurrentApp,
                      child: const Text('Detectar app actual'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (activeBlocks.isNotEmpty) ...[
              Text(
                'Bloqueos activos (${activeBlocks.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...activeBlocks.map(
                (block) => Card(
                  child: ListTile(
                    title: Text(block.appName),
                    subtitle: Text(
                      'Package: ${block.packageName}\nHasta: ${block.endDate.day}/${block.endDate.month}/${block.endDate.year}',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
              ),
              onPressed: _activateBlock,
              child: const Text(
                'ACTIVAR BLOQUEO',
                style: TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _clearAllData,
              child: const Text('Borrar datos guardados'),
            ),
          ],
        ),
      ),
    );
  }
}
