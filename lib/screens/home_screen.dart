import 'dart:convert';
import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_block.dart';
import '../services/unlock_grants_sync_service.dart';
import 'friend_screen.dart';
import 'block_screen.dart';
import 'debug_sync_diagnostics_screen.dart';
import 'pending_requests_screen.dart';
import 'widgets/selectable_option_card.dart';
import 'widgets/wizard_bottom_nav.dart';
import 'widgets/wizard_step_shell.dart';

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

class _PopularBlockAppOption {
  final String packageName;
  final String appName;
  final IconData icon;

  const _PopularBlockAppOption({
    required this.packageName,
    required this.appName,
    required this.icon,
  });
}

class _ReplacementOption {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;

  const _ReplacementOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

class _ReplacementSuggestion {
  final String title;
  final String action;
  final IconData icon;

  const _ReplacementSuggestion({
    required this.title,
    required this.action,
    required this.icon,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const String _durationDays = 'Dias';
  static const String _durationMonths = 'Meses';
  static const String _temporaryUnlockedKey = 'temporary_unlocked_packages_csv';
  static const String _pendingRequestsKey = 'pending_unlock_requests_csv';
  static const String _approvedRequestIdsKey = 'approved_unlock_request_ids_csv';
  static const String _replacementChoicesKey = 'replacement_choices';
  static const int _defaultDeepLinkUnlockMinutes = 60;
  static const List<_PopularBlockAppOption> _popularBlockApps = [
    _PopularBlockAppOption(
      packageName: 'com.instagram.android',
      appName: 'Instagram',
      icon: FontAwesomeIcons.instagram,
    ),
    _PopularBlockAppOption(
      packageName: 'com.facebook.katana',
      appName: 'Facebook',
      icon: FontAwesomeIcons.facebookF,
    ),
    _PopularBlockAppOption(
      packageName: 'com.zhiliaoapp.musically',
      appName: 'TikTok',
      icon: FontAwesomeIcons.tiktok,
    ),
    _PopularBlockAppOption(
      packageName: 'com.twitter.android',
      appName: 'X / Twitter',
      icon: FontAwesomeIcons.xTwitter,
    ),
    _PopularBlockAppOption(
      packageName: 'com.google.android.youtube',
      appName: 'YouTube',
      icon: FontAwesomeIcons.youtube,
    ),
  ];
  static const List<_ReplacementOption> _replacementOptions = [
    _ReplacementOption(
      id: 'reading_learning',
      title: 'Lectura y aprendizaje',
      subtitle: 'Libros, cursos, idiomas y contenido educativo.',
      icon: Icons.menu_book_rounded,
    ),
    _ReplacementOption(
      id: 'wellbeing_training',
      title: 'Entrenamiento y bienestar',
      subtitle: 'Ejercicio, meditacion y habitos saludables.',
      icon: Icons.fitness_center_rounded,
    ),
    _ReplacementOption(
      id: 'music_creativity',
      title: 'Musica y creatividad',
      subtitle: 'Podcasts, instrumentos, canto y creacion.',
      icon: Icons.headphones_rounded,
    ),
    _ReplacementOption(
      id: 'focus_games',
      title: 'Concentracion y juegos didacticos',
      subtitle: 'Juegos mentales y actividades para foco.',
      icon: Icons.psychology_alt_rounded,
    ),
  ];
  static const Map<String, List<_ReplacementSuggestion>>
      _replacementSuggestionsByOptionId = {
    'reading_learning': [
      _ReplacementSuggestion(
        title: 'Lectura de 10 minutos',
        action: 'Elegi un articulo o capitulo corto y marca un objetivo simple.',
        icon: Icons.chrome_reader_mode_rounded,
      ),
      _ReplacementSuggestion(
        title: 'Podcast educativo',
        action: 'Escucha un episodio breve mientras caminas o te preparas algo.',
        icon: Icons.podcasts_rounded,
      ),
      _ReplacementSuggestion(
        title: 'Curso rapido',
        action: 'Avanza una leccion de algun curso que ya tengas guardado.',
        icon: Icons.school_rounded,
      ),
      _ReplacementSuggestion(
        title: 'Idioma en micro sesiones',
        action: 'Practica 15 minutos de vocabulario o escucha activa.',
        icon: Icons.translate_rounded,
      ),
    ],
    'wellbeing_training': [
      _ReplacementSuggestion(
        title: 'Respiracion guiada',
        action: 'Haz 3 minutos de respiracion profunda para bajar ansiedad.',
        icon: Icons.air_rounded,
      ),
      _ReplacementSuggestion(
        title: 'Estiramiento breve',
        action: 'Mueve cuello, hombros y espalda durante 5 a 10 minutos.',
        icon: Icons.accessibility_new_rounded,
      ),
      _ReplacementSuggestion(
        title: 'Caminata corta',
        action: 'Sal a caminar 15 minutos para cambiar de foco mental.',
        icon: Icons.directions_walk_rounded,
      ),
      _ReplacementSuggestion(
        title: 'Mini rutina',
        action: 'Completa una rutina de cuerpo completo de 12 minutos.',
        icon: Icons.fitness_center_rounded,
      ),
    ],
    'music_creativity': [
      _ReplacementSuggestion(
        title: 'Playlist enfocada',
        action: 'Escucha musica instrumental para trabajar o relajarte.',
        icon: Icons.queue_music_rounded,
      ),
      _ReplacementSuggestion(
        title: 'Escritura libre',
        action: 'Anota ideas, pendientes o un diario rapido de 10 minutos.',
        icon: Icons.edit_note_rounded,
      ),
      _ReplacementSuggestion(
        title: 'Dibujo o boceto',
        action: 'Haz un boceto simple para activar creatividad sin presion.',
        icon: Icons.brush_rounded,
      ),
      _ReplacementSuggestion(
        title: 'Practica musical',
        action: 'Si tocas un instrumento, practica una cancion corta.',
        icon: Icons.piano_rounded,
      ),
    ],
    'focus_games': [
      _ReplacementSuggestion(
        title: 'Sudoku o logica',
        action: 'Resuelve un desafio de logica para entrenar concentracion.',
        icon: Icons.grid_view_rounded,
      ),
      _ReplacementSuggestion(
        title: 'Ajedrez tactico',
        action: 'Juega una partida corta o un problema tactico.',
        icon: Icons.extension_rounded,
      ),
      _ReplacementSuggestion(
        title: 'Memoria activa',
        action: 'Usa ejercicios de memoria durante 10 minutos.',
        icon: Icons.psychology_rounded,
      ),
      _ReplacementSuggestion(
        title: 'Desafio de foco',
        action: 'Configura 25 minutos de foco total en una tarea concreta.',
        icon: Icons.timer_rounded,
      ),
    ],
  };

  String selectedDurationType = _durationDays;
  double selectedValue = 7;
  int _currentWizardIndex = 0;
  final PageController _wizardPageController = PageController();
  final List<Map<String, String>> selectedApps = [];
  final Set<String> _selectedReplacementIds = {};
  final Set<String> _installedAppPackages = {};
  String? friendName;
  String? friendEmail;

  bool isLoading = true;
  List<AppBlock> activeBlocks = [];

  final UnlockGrantsSyncService _unlockGrantsSyncService = UnlockGrantsSyncService();
  bool _isActivatingFromStep2 = false;
  List<_TemporaryUnlockInfo> temporaryUnlockedApps = [];
  List<_PendingRequestRecord> pendingRequests = [];
  Timer? _temporaryUnlockTimer;
  final Map<String, String> _appNameCache = {};
  bool _isResolvingAppNames = false;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _deepLinkSubscription;
  String? _lastHandledDeepLink;
  String? _lastSyncRequestId;
  String? _lastSyncServerTime;
  String? _lastSyncError;
  String? _lastSyncPackageName;
  String? _lastSyncSource;
  String? _lastSyncInstallationId;
  DateTime? _lastSyncAt;
  bool? _lastSyncOk;
  List<UnlockGrantActiveGrant> _lastSyncActiveGrants = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSavedData();
    _startTemporaryUnlockTimer();
    _setupDeepLinks();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _wizardPageController.dispose();
    _temporaryUnlockTimer?.cancel();
    _deepLinkSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_syncRemoteUnlockGrants(trigger: 'app_foreground'));
    }
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    if (kDebugMode) {
      await _clearPersistedAppState(prefs);
    }
    final savedBlocks = prefs.getStringList('activeBlocks') ?? [];
    final savedApps = prefs.getStringList('selectedApps') ?? [];

    final decodedApps = savedApps
        .map((item) => Map<String, String>.from(jsonDecode(item)))
        .toList();

    final decodedBlocks = savedBlocks
        .map((item) => AppBlock.fromMap(jsonDecode(item)))
        .toList();
    final savedDurationType = prefs.getString('durationType');
    final normalizedDurationType = _normalizeDurationType(savedDurationType);
    final savedDurationValue = prefs.getDouble('durationValue') ?? 7;
    final normalizedDurationValue = normalizedDurationType == _durationDays
        ? savedDurationValue.clamp(1, 30).toDouble()
        : savedDurationValue.clamp(1, 12).toDouble();
    final savedReplacementIds = prefs.getStringList(_replacementChoicesKey) ?? [];

    setState(() {
      selectedDurationType = normalizedDurationType;
      selectedValue = normalizedDurationValue;

      selectedApps
        ..clear()
        ..addAll(decodedApps);

      friendName = prefs.getString('friendName');
      friendEmail = prefs.getString('friendEmail');
      _selectedReplacementIds
        ..clear()
        ..addAll(savedReplacementIds);

      activeBlocks = decodedBlocks;
      isLoading = false;
    });

    _seedAppNameCacheFromKnownData();
    await _saveBlockedPackagesForAndroid();
    await _loadTemporaryUnlockedApps();
    await _loadPendingRequests();
    await _loadInstalledPackagesForWizard();
    await _syncRemoteUnlockGrants(trigger: 'app_start', force: true);
  }

  Future<UnlockGrantSyncResult> _syncRemoteUnlockGrants({
    required String trigger,
    bool force = false,
    String? packageName,
  }) async {
    final result = await _unlockGrantsSyncService.syncActiveGrants(
      trigger: trigger,
      force: force,
      packageName: packageName,
    );

    _lastSyncRequestId = result.requestId;
    _lastSyncServerTime = result.serverTime;
    _lastSyncError = result.errorMessage;
    _lastSyncPackageName = result.packageName ?? packageName;
    _lastSyncSource = trigger;
    _lastSyncInstallationId = result.installationId;
    _lastSyncAt = DateTime.now();
    _lastSyncOk = result.success;
    _lastSyncActiveGrants = result.activeGrants;

    if (!mounted) return result;
    await _loadTemporaryUnlockedApps();
    if (mounted) {
      setState(() {});
    }
    debugPrint(
      '[home-sync] trigger=$trigger requestId=${result.requestId} installationId=${result.installationId} packageName=$packageName activeFound=${result.hasActiveForPackage} activeCount=${result.activeCount} success=${result.success} serverTime=${result.serverTime}',
    );
    return result;
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
    if (!_isApprovalDeepLink(uri) && !_isReplacementsDeepLink(uri)) return;

    final rawUri = uri.toString();
    if (_lastHandledDeepLink == rawUri) return;
    _lastHandledDeepLink = rawUri;

    if (_isReplacementsDeepLink(uri)) {
      await _openReplacementsFromDeepLink();
      return;
    }

    await _applyDeepLinkApproval(uri);
  }

  bool _isApprovalDeepLink(Uri uri) {
    final normalizedPath = uri.path.startsWith('/') ? uri.path : '/${uri.path}';
    return uri.scheme == 'changeyourlife' &&
        uri.host == 'unlock' &&
        normalizedPath == '/approve';
  }

  bool _isReplacementsDeepLink(Uri uri) {
    final normalizedPath = uri.path.startsWith('/') ? uri.path : '/${uri.path}';
    return uri.scheme == 'changeyourlife' &&
        uri.host == 'unlock' &&
        normalizedPath == '/replacements';
  }

  Future<void> _openReplacementsFromDeepLink() async {
    await _jumpToWizardStep(2);
    if (!mounted) return;
    _showMessage('Te llevamos a alternativas utiles para este momento.');
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
    await _loadPendingRequests();

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
        .followedBy(pendingRequests.map((item) => item.packageName.trim()))
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

  String _normalizeDurationType(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    if (normalized.startsWith('mes')) return _durationMonths;
    return _durationDays;
  }

  Future<void> _loadInstalledPackagesForWizard() async {
    try {
      final installedApps = await InstalledApps.getInstalledApps(
        excludeSystemApps: true,
        excludeNonLaunchableApps: true,
        withIcon: false,
      );

      if (!mounted) return;

      final packages = installedApps
          .map((app) => app.packageName.trim())
          .where((packageName) => packageName.isNotEmpty)
          .toSet();

      var changed = false;
      for (final app in installedApps) {
        final packageName = app.packageName.trim();
        final appName = app.name.trim();
        if (packageName.isEmpty || appName.isEmpty) continue;
        if (_appNameCache[packageName] == appName) continue;
        _appNameCache[packageName] = appName;
        changed = true;
      }

      setState(() {
        _installedAppPackages
          ..clear()
          ..addAll(packages);
      });

      if (changed && mounted) {
        setState(() {});
      }
    } catch (_) {
      // Keep fallback behavior: popular apps remain selectable.
    }
  }

  Future<void> _saveReplacementChoices() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _replacementChoicesKey,
      _selectedReplacementIds.toList(),
    );
  }

  bool _isPopularAppAvailable(_PopularBlockAppOption option) {
    if (_installedAppPackages.isEmpty) return true;
    return _installedAppPackages.contains(option.packageName);
  }

  bool _isAppSelected(String packageName) {
    return selectedApps.any((app) => app['packageName'] == packageName);
  }

  bool get _hasFriendConfigured {
    final name = (friendName ?? '').trim();
    final email = (friendEmail ?? '').trim();
    return name.isNotEmpty && email.isNotEmpty;
  }

  bool get _hasSelectedAppsActiveBlock {
    if (selectedApps.isEmpty) return false;
    final now = DateTime.now();
    return selectedApps.every((app) {
      final packageName = (app['packageName'] ?? '').trim();
      if (packageName.isEmpty) return false;
      return activeBlocks.any(
        (block) => block.packageName == packageName && block.endDate.isAfter(now),
      );
    });
  }

  bool get _hasSelectedAppsConfiguredInBlocks {
    if (selectedApps.isEmpty) return false;
    return selectedApps.every((app) {
      final packageName = (app['packageName'] ?? '').trim();
      if (packageName.isEmpty) return false;
      return activeBlocks.any((block) => block.packageName == packageName);
    });
  }

  bool get _isStep1Ready => selectedApps.isNotEmpty;
  bool get _isStep2Ready => selectedValue >= 1 && _hasFriendConfigured;
  bool get _isStep3Ready => true;

  bool _isStepReady(int index) {
    if (index == 0) return _isStep1Ready;
    if (index == 1) return _isStep2Ready && _hasSelectedAppsConfiguredInBlocks;
    if (index == 2) return _isStep3Ready;
    return true;
  }

  bool get _canGoNext {
    if (_currentWizardIndex == 0) return _isStep1Ready;
    if (_currentWizardIndex == 1) return _isStep2Ready;
    if (_currentWizardIndex == 2) return _isStep3Ready;
    return true;
  }

  Future<void> _jumpToWizardStep(int targetIndex) async {
    if (targetIndex < 0 || targetIndex > 3) return;

    if (!mounted) return;
    if (_wizardPageController.hasClients) {
      await _wizardPageController.animateToPage(
        targetIndex,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    setState(() {
      _currentWizardIndex = targetIndex;
    });
  }

  Future<void> _goToWizardStep(int targetIndex) async {
    if (targetIndex < 0 || targetIndex > 3) return;
    if (targetIndex == _currentWizardIndex) return;

    if (targetIndex > _currentWizardIndex) {
      for (var step = _currentWizardIndex; step < targetIndex; step++) {
        if (!_isStepReady(step)) {
          _showStepRequirementMessage(step);
          return;
        }
      }
    }

    await _jumpToWizardStep(targetIndex);
  }

  Future<void> _goNextWizardStep() async {
    if (!_canGoNext) {
      _showStepRequirementMessage(_currentWizardIndex);
      return;
    }
    await _goToWizardStep(_currentWizardIndex + 1);
  }

  Future<void> _confirmAndActivateFromStep2() async {
    if (_isActivatingFromStep2) return;

    if (!_isStep1Ready) {
      _showStepRequirementMessage(0);
      return;
    }
    if (!_isStep2Ready) {
      _showStepRequirementMessage(1);
      return;
    }

    setState(() {
      _isActivatingFromStep2 = true;
    });

    try {
      await _activateBlock(showSuccessMessage: false);
      if (!mounted) return;
      await _goToWizardStep(2);
      if (!mounted) return;
      _showMessage('Bloqueo activo. Ahora elegi alternativas positivas.');
    } finally {
      if (mounted) {
        setState(() {
          _isActivatingFromStep2 = false;
        });
      }
    }
  }

  Future<void> _goPreviousWizardStep() async {
    await _goToWizardStep(_currentWizardIndex - 1);
  }

  void _showStepRequirementMessage(int step) {
    if (step == 0) {
      _showMessage('Elegi al menos una app para continuar.');
      return;
    }
    if (step == 1) {
      if (_isStep2Ready && !_hasSelectedAppsConfiguredInBlocks) {
        _showMessage('Confirma y activa el bloqueo para pasar al siguiente paso.');
        return;
      }
      _showMessage('Defini duracion y amigo responsable para continuar.');
      return;
    }
  }

  Future<void> _togglePopularBlockApp(_PopularBlockAppOption option) async {
    final selectedIndex = selectedApps.indexWhere(
      (app) => app['packageName'] == option.packageName,
    );

    setState(() {
      if (selectedIndex >= 0) {
        selectedApps.removeAt(selectedIndex);
      } else {
        selectedApps.add({
          'packageName': option.packageName,
          'appName': option.appName,
        });
      }
    });

    _seedAppNameCacheFromKnownData();
    await _saveData();
  }

  Future<void> _toggleReplacementOption(String id) async {
    setState(() {
      if (_selectedReplacementIds.contains(id)) {
        _selectedReplacementIds.remove(id);
      } else {
        _selectedReplacementIds.add(id);
      }
    });

    await _saveReplacementChoices();
  }

  void _showReplacementIdeas(_ReplacementOption option) {
    final ideas = _replacementSuggestionsByOptionId[option.id] ?? const [];
    if (ideas.isEmpty) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Opciones concretas para reemplazar redes en este momento:',
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 10),
                ...ideas.map(
                  (idea) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        dense: true,
                        leading: Icon(idea.icon),
                        title: Text(idea.title),
                        subtitle: Text(idea.action),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
    await _loadPendingRequests();
  }

  List<UnlockGrantActiveGrant> _fallbackActiveGrantsFromLocalState() {
    final grants = temporaryUnlockedApps.map((item) {
      return UnlockGrantActiveGrant(
        packageName: item.packageName,
        unlockUntilMillis: item.unlockedUntilMillis,
      );
    }).toList()
      ..sort((a, b) => a.unlockUntilMillis.compareTo(b.unlockUntilMillis));
    return grants;
  }

  Future<DebugSyncDiagnosticsData> _loadDebugDiagnostics({
    bool forceSync = false,
  }) async {
    if (forceSync) {
      await _syncRemoteUnlockGrants(trigger: 'manual', force: true);
    }

    final prefs = await SharedPreferences.getInstance();
    final temporaryCsv = prefs.getString(_temporaryUnlockedKey) ?? '';
    final installationId = (prefs.getString('installation_id') ?? _lastSyncInstallationId ?? '').trim();
    final grants = _lastSyncActiveGrants.isNotEmpty
        ? _lastSyncActiveGrants
        : _fallbackActiveGrantsFromLocalState();

    return DebugSyncDiagnosticsData(
      installationId: installationId,
      lastRequestId: _lastSyncRequestId,
      lastSyncSource: _lastSyncSource,
      lastSyncAt: _lastSyncAt,
      lastSyncOk: _lastSyncOk,
      lastSyncError: _lastSyncError,
      lastEvaluatedPackage: _lastSyncPackageName,
      serverTime: _lastSyncServerTime,
      temporaryCsv: temporaryCsv,
      activeGrants: grants,
    );
  }

  Future<void> _openDebugDiagnosticsScreen() async {
    final initialData = await _loadDebugDiagnostics();
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DebugSyncDiagnosticsScreen(
          initialData: initialData,
          loadDiagnostics: ({bool forceSync = false}) {
            return _loadDebugDiagnostics(forceSync: forceSync);
          },
        ),
      ),
    );
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

  Future<void> _loadPendingRequests() async {
    final prefs = await SharedPreferences.getInstance();
    final csv = prefs.getString(_pendingRequestsKey) ?? '';
    final loaded = _parsePendingRequestsCsv(csv).values.toList()
      ..sort(
        (a, b) => (b.requestedAtMillis ?? 0).compareTo(a.requestedAtMillis ?? 0),
      );

    if (!mounted) return;
    setState(() {
      pendingRequests = loaded;
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
    if (selectedDurationType == _durationDays) {
      return value == 1 ? '1 dia' : '$value dias';
    } else {
      return value == 1 ? '1 mes' : '$value meses';
    }
  }

  Future<void> _activateBlock({bool showSuccessMessage = true}) async {
    if (selectedApps.isEmpty) {
      _showMessage('Primero elegi al menos una app para bloquear.');
      return;
    }

    if (friendName == null ||
        friendName!.isEmpty ||
        friendEmail == null ||
        friendEmail!.isEmpty) {
      _showMessage('Primero elegi un amigo responsable.');
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

      final endDate = selectedDurationType == _durationDays
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

    if (showSuccessMessage) {
      _showMessage('Bloqueos activados correctamente.');
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> _clearPersistedAppState(SharedPreferences prefs) async {
    await prefs.remove('durationType');
    await prefs.remove('durationValue');
    await prefs.remove('selectedApps');
    await prefs.remove('friendName');
    await prefs.remove('friendEmail');
    await prefs.remove('activeBlocks');
    await prefs.remove('blocked_packages_csv');
    await prefs.remove('pending_unlock_requests_csv');
    await prefs.remove('temporary_unlocked_packages_csv');
    await prefs.remove(_replacementChoicesKey);
    await prefs.remove(_approvedRequestIdsKey);
  }
  Future<void> _clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await _clearPersistedAppState(prefs);

    setState(() {
      selectedDurationType = _durationDays;
      selectedValue = 7;
      _currentWizardIndex = 0;
      selectedApps.clear();
      _selectedReplacementIds.clear();
      friendName = null;
      friendEmail = null;
      activeBlocks.clear();
      temporaryUnlockedApps.clear();
      _appNameCache.clear();
    });
    _wizardPageController.jumpToPage(0);

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

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  String _formatDateTime(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month/${value.year} $hour:$minute';
  }

  String _pendingRequestedAtText(_PendingRequestRecord request) {
    final requestedAt = request.requestedAtMillis;
    if (requestedAt == null) return 'Pendiente de revision';

    final requestedDate = DateTime.fromMillisecondsSinceEpoch(requestedAt);
    return 'Solicitado el ${_formatDateTime(requestedDate)}';
  }

  List<AppBlock> _selectedActiveBlocks() {
    final selectedPackages = selectedApps
        .map((app) => (app['packageName'] ?? '').trim())
        .where((packageName) => packageName.isNotEmpty)
        .toSet();
    final now = DateTime.now();
    return activeBlocks.where((block) {
      return selectedPackages.contains(block.packageName) &&
          block.endDate.isAfter(now);
    }).toList();
  }

  String _remainingTimeFrom(DateTime endDate) {
    final now = DateTime.now();
    final diff = endDate.difference(now);
    if (diff.inSeconds <= 0) return 'Finalizado';
    if (diff.inDays >= 1) {
      final hours = diff.inHours.remainder(24);
      return '${diff.inDays}d ${hours}h';
    }
    if (diff.inHours >= 1) {
      final minutes = diff.inMinutes.remainder(60);
      return '${diff.inHours}h ${minutes}m';
    }
    final minutes = diff.inMinutes <= 0 ? 1 : diff.inMinutes;
    return '${minutes}m';
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Icon(icon, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyStateCard({
    required IconData icon,
    required String message,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: Colors.black54),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> get _selectedReplacementTitles {
    return _replacementOptions
        .where((option) => _selectedReplacementIds.contains(option.id))
        .map((option) => option.title)
        .toList();
  }

  Widget _buildStepOne() {
    final extraSelectedApps = selectedApps.where((app) {
      final packageName = (app['packageName'] ?? '').trim();
      return !_popularBlockApps.any((option) => option.packageName == packageName);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: WizardStepShell(
        stepLabel: 'Paso 1 de 3',
        title: 'Elegi que apps queres bloquear',
        subtitle: 'Elegi las apps que queres pausar',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ..._popularBlockApps.map((option) {
              final isSelected = _isAppSelected(option.packageName);
              final isAvailable = _isPopularAppAvailable(option);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SelectableOptionCard(
                  title: option.appName,
                  subtitle: isAvailable
                      ? 'Disponible en este dispositivo'
                      : 'No instalada en este dispositivo',
                  icon: option.icon,
                  selected: isSelected,
                  enabled: isAvailable || isSelected,
                  onTap: () => _togglePopularBlockApp(option),
                ),
              );
            }),
            const SizedBox(height: 12),
            if (selectedApps.isEmpty)
              _buildEmptyStateCard(
                icon: Icons.touch_app_rounded,
                message: 'Selecciona una o mas apps para continuar.',
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Apps seleccionadas (${selectedApps.length})',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: selectedApps.map((app) {
                          final packageName = (app['packageName'] ?? '').trim();
                          final appName = _displayNameForPackage(packageName);
                          return Chip(label: Text(appName));
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            if (extraSelectedApps.isNotEmpty) ...[
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Tambien tenes seleccionadas ${extraSelectedApps.length} app(s) adicionales desde la lista completa.',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStepTwo() {
    final maxValue = selectedDurationType == _durationDays ? 30.0 : 12.0;
    final divisions = selectedDurationType == _durationDays ? 29 : 11;
    final sliderValue = selectedValue > maxValue ? maxValue : selectedValue;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: WizardStepShell(
        stepLabel: 'Paso 2 de 3',
        title: 'Elegi el tiempo y el amigo responsable',
        subtitle: 'Defini cuanto tiempo queres bloquearlas',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Duracion',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment<String>(
                          value: _durationDays,
                          label: Text('Dias'),
                        ),
                        ButtonSegment<String>(
                          value: _durationMonths,
                          label: Text('Meses'),
                        ),
                      ],
                      selected: {selectedDurationType},
                      onSelectionChanged: (newSelection) async {
                        setState(() {
                          selectedDurationType = newSelection.first;
                          selectedValue =
                              selectedDurationType == _durationDays ? 7 : 1;
                        });
                        await _saveData();
                      },
                    ),
                    const SizedBox(height: 16),
                    Text('Duracion elegida: $durationText'),
                    Slider(
                      value: sliderValue,
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _openFriendScreen,
              icon: const Icon(Icons.group_rounded),
              label: const Text('Elegir amigo responsable'),
            ),
            const SizedBox(height: 10),
            if (_hasFriendConfigured)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Amigo responsable',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text('Nombre: ${friendName ?? ''}'),
                      Text('Email: ${friendEmail ?? ''}'),
                    ],
                  ),
                ),
              )
            else
              _buildEmptyStateCard(
                icon: Icons.person_add_alt_1_rounded,
                message: 'Falta elegir un amigo responsable para continuar.',
              ),
            const SizedBox(height: 10),
            Card(
              color: Colors.blueGrey.shade50,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.chat_bubble_outline_rounded),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'WhatsApp (proximamente): dejamos la interfaz lista sin cambiar la logica actual.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepThree() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: WizardStepShell(
        stepLabel: 'Paso 3 de 3',
        title: 'Elegi con que queres reemplazar ese tiempo',
        subtitle: 'Elegi alternativas positivas para aprovechar mejor tu tiempo',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.blue.shade50,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mientras tus redes estan bloqueadas, te sugerimos apps y actividades para aprovechar mejor ese tiempo.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Estas opciones funcionan como reemplazos positivos: bienestar, aprendizaje, musica y juegos didacticos.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            ..._replacementOptions.map((option) {
              final isSelected = _selectedReplacementIds.contains(option.id);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SelectableOptionCard(
                      title: option.title,
                      subtitle: option.subtitle,
                      icon: option.icon,
                      selected: isSelected,
                      onTap: () => _toggleReplacementOption(option.id),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _showReplacementIdeas(option),
                        icon: const Icon(Icons.tips_and_updates_outlined),
                        label: const Text('Ver ideas concretas'),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            if (_selectedReplacementIds.isEmpty)
              _buildEmptyStateCard(
                icon: Icons.lightbulb_outline_rounded,
                message: 'Este paso es opcional, pero puede ayudarte a sostener el cambio.',
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Excelente, elegiste ${_selectedReplacementIds.length} alternativa(s) para reemplazar ese tiempo.',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryStep() {
    final selectedActiveBlocks = _selectedActiveBlocks();
    final isBlockingActive = _hasSelectedAppsActiveBlock;
    String remainingOverview = 'Aun no hay un bloqueo activo para las apps elegidas.';
    if (selectedActiveBlocks.isNotEmpty) {
      DateTime nearestEnd = selectedActiveBlocks.first.endDate;
      for (final block in selectedActiveBlocks) {
        if (block.endDate.isBefore(nearestEnd)) {
          nearestEnd = block.endDate;
        }
      }
      remainingOverview = 'Tiempo restante aproximado: ${_remainingTimeFrom(nearestEnd)}';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: WizardStepShell(
        stepLabel: null,
        title: 'Resumen final',
        subtitle: 'Asi quedo configurado tu plan de bloqueo.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: isBlockingActive ? Colors.green.shade50 : Colors.orange.shade50,
              child: ListTile(
                leading: Icon(
                  isBlockingActive ? Icons.verified_rounded : Icons.warning_amber_rounded,
                  color: isBlockingActive ? Colors.green.shade700 : Colors.orange.shade700,
                ),
                title: Text(
                  isBlockingActive ? 'Bloqueo activo' : 'Bloqueo pendiente',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isBlockingActive ? Colors.green.shade800 : Colors.orange.shade800,
                  ),
                ),
                subtitle: Text(remainingOverview),
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
                      'Apps a bloquear',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    if (selectedApps.isEmpty)
                      const Text('No hay apps seleccionadas.')
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: selectedApps.map((app) {
                          final packageName = (app['packageName'] ?? '').trim();
                          final appName = _displayNameForPackage(packageName);
                          return Chip(label: Text(appName));
                        }).toList(),
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
                    const Row(
                      children: [
                        Icon(Icons.schedule_rounded),
                        SizedBox(width: 8),
                        Text(
                          'Duracion elegida',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(durationText, style: const TextStyle(fontSize: 16)),
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
                    const Row(
                      children: [
                        Icon(Icons.group_rounded),
                        SizedBox(width: 8),
                        Text(
                          'Amigo responsable',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _hasFriendConfigured
                          ? '${friendName ?? ''} - ${friendEmail ?? ''}'
                          : 'No definido',
                    ),
                  ],
                ),
              ),
            ),
            if (selectedActiveBlocks.isNotEmpty) ...[
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Estado por app bloqueada',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      ...selectedActiveBlocks.map((block) {
                        final appName = block.appName.trim().isNotEmpty
                            ? block.appName.trim()
                            : _displayNameForPackage(block.packageName);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              const Icon(Icons.lock_clock_rounded, size: 18),
                              const SizedBox(width: 8),
                              Expanded(child: Text(appName)),
                              Text(
                                _remainingTimeFrom(block.endDate),
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Apps utiles seleccionadas',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    if (_selectedReplacementTitles.isEmpty)
                      const Text('No seleccionaste alternativas por ahora.')
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _selectedReplacementTitles
                            .map((title) => Chip(label: Text(title)))
                            .toList(),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildSectionHeader(
              icon: Icons.insights_rounded,
              title: 'Seguimiento',
              subtitle: 'Accesos rapidos para mantener control del estado actual.',
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _openPendingRequestsScreen,
              icon: const Icon(Icons.pending_actions_rounded),
              label: Text('Solicitudes pendientes (${pendingRequests.length})'),
            ),
            const SizedBox(height: 8),
            if (pendingRequests.isEmpty)
              _buildEmptyStateCard(
                icon: Icons.mark_email_read_outlined,
                message: 'No hay solicitudes pendientes en este momento.',
              )
            else
              ...pendingRequests.take(3).map((request) {
                final appName = _displayNameForPackage(request.packageName);
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.mark_email_unread_outlined),
                    title: Text(appName),
                    subtitle: Text(_pendingRequestedAtText(request)),
                  ),
                );
              }),
            if (pendingRequests.length > 3)
              Padding(
                padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
                child: Text(
                  'Mostrando 3 de ${pendingRequests.length} solicitudes. Abri el detalle para ver todas.',
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
            const SizedBox(height: 4),
            if (temporaryUnlockedApps.isEmpty)
              _buildEmptyStateCard(
                icon: Icons.hourglass_empty_rounded,
                message: 'No hay desbloqueos temporales activos.',
              )
            else
              ...temporaryUnlockedApps.map((item) {
                final remaining = _remainingMinutes(item);
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.lock_open_rounded),
                    title: Text(_displayNameForPackage(item.packageName)),
                    subtitle: Text('Tiempo restante: $remaining min'),
                    trailing: Chip(label: Text('$remaining min')),
                  ),
                );
              }),
            const SizedBox(height: 8),
            if (activeBlocks.isEmpty)
              _buildEmptyStateCard(
                icon: Icons.lock_open_rounded,
                message: 'Todavia no hay bloqueos activos.',
              )
            else
              ...activeBlocks.map((block) {
                final appName = block.appName.trim().isNotEmpty
                    ? block.appName.trim()
                    : _displayNameForPackage(block.packageName);
                return Card(
                  child: ListTile(
                    onTap: () => _openBlockScreen(block),
                    leading: const Icon(Icons.lock_rounded),
                    title: Text(appName),
                    subtitle: Text('Hasta: ${_formatDate(block.endDate)}'),
                  ),
                );
              }),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _clearAllData,
              child: const Text('Borrar datos guardados'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWizardActionBar() {
    if (_currentWizardIndex == 3) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _goPreviousWizardStep,
              child: const Text('Volver'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _activateBlock,
              child: const Text('Actualizar bloqueo'),
            ),
          ),
        ],
      );
    }

    if (_currentWizardIndex == 1) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _goPreviousWizardStep,
              child: const Text('Volver'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _isStep2Ready && !_isActivatingFromStep2
                  ? _confirmAndActivateFromStep2
                  : null,
              child: _isActivatingFromStep2
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Confirmar y bloquear'),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _currentWizardIndex > 0 ? _goPreviousWizardStep : null,
            child: const Text('Volver'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _canGoNext ? _goNextWizardStep : null,
            child: const Text('Siguiente'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    const navItems = [
      WizardNavItem(title: 'Bloqueo', icon: Icons.block_rounded),
      WizardNavItem(title: 'Tiempo', icon: Icons.schedule_rounded),
      WizardNavItem(title: 'Reemplazo', icon: Icons.self_improvement_rounded),
      WizardNavItem(title: 'Resumen', icon: Icons.fact_check_rounded),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Change Your Life in Community'),
        actions: [
          if (kDebugMode)
            IconButton(
              onPressed: _openDebugDiagnosticsScreen,
              icon: const Icon(Icons.bug_report_rounded),
              tooltip: 'Diagnostico sync',
            ),
        ],
      ),
      body: PageView(
        controller: _wizardPageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (index) {
          if (!mounted) return;
          setState(() {
            _currentWizardIndex = index;
          });
        },
        children: [
          _buildStepOne(),
          _buildStepTwo(),
          _buildStepThree(),
          _buildSummaryStep(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: _buildWizardActionBar(),
            ),
            WizardBottomNav(
              items: navItems,
              currentIndex: _currentWizardIndex,
              onTap: (index) {
                _goToWizardStep(index);
              },
            ),
          ],
        ),
      ),
    );
  }
}




