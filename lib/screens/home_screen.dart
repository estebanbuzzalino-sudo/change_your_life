import 'dart:convert';
import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final String playStorePackageId;
  final String playStoreQuery;
  final bool featured;

  const _ReplacementSuggestion({
    required this.title,
    required this.action,
    required this.icon,
    required this.playStorePackageId,
    required this.playStoreQuery,
    this.featured = false,
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
  static const String _ignoredUnlockGrantsKey = 'ignored_unlock_grants_csv';
  static const String _replacementChoicesKey = 'replacement_choices';
  static const String _requesterNameKey = 'requester_name';
  static const String _friendWhatsappE164Key = 'friendWhatsappE164';
  static const String _notificationModeKey = 'notificationMode';
  static const String _notificationEmailOnly = 'email_only';
  static const String _notificationWhatsappOnly = 'whatsapp_only';
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
        playStorePackageId: 'com.google.android.apps.books',
        playStoreQuery: 'Google Play Books',
        featured: true,
      ),
      _ReplacementSuggestion(
        title: 'Podcast educativo',
        action: 'Escucha un episodio breve mientras caminas o te preparas algo.',
        icon: Icons.podcasts_rounded,
        playStorePackageId: 'com.spotify.music',
        playStoreQuery: 'Spotify podcast',
        featured: true,
      ),
      _ReplacementSuggestion(
        title: 'Curso rapido',
        action: 'Avanza una leccion de algun curso que ya tengas guardado.',
        icon: Icons.school_rounded,
        playStorePackageId: 'org.khanacademy.android',
        playStoreQuery: 'Khan Academy',
      ),
      _ReplacementSuggestion(
        title: 'Idioma en micro sesiones',
        action: 'Practica 15 minutos de vocabulario o escucha activa.',
        icon: Icons.translate_rounded,
        playStorePackageId: 'com.duolingo',
        playStoreQuery: 'Duolingo',
      ),
    ],
    'wellbeing_training': [
      _ReplacementSuggestion(
        title: 'Respiracion guiada',
        action: 'Haz 3 minutos de respiracion profunda para bajar ansiedad.',
        icon: Icons.air_rounded,
        playStorePackageId: 'com.calm.android',
        featured: true,
        playStoreQuery: 'Calm meditación',
      ),
      _ReplacementSuggestion(
        title: 'Estiramiento breve',
        action: 'Mueve cuello, hombros y espalda durante 5 a 10 minutos.',
        icon: Icons.accessibility_new_rounded,
        playStorePackageId: 'com.nike.ntc',
        playStoreQuery: 'entrenamiento estiramiento',
      ),
      _ReplacementSuggestion(
        title: 'Caminata corta',
        action: 'Sal a caminar 15 minutos para cambiar de foco mental.',
        icon: Icons.directions_walk_rounded,
        playStorePackageId: 'com.google.android.apps.fitness',
        playStoreQuery: 'Google Fit caminar',
      ),
      _ReplacementSuggestion(
        title: 'Mini rutina',
        action: 'Completa una rutina de cuerpo completo de 12 minutos.',
        icon: Icons.fitness_center_rounded,
        playStorePackageId: 'homeworkout.homeworkouts.noequipment',
        featured: true,
        playStoreQuery: 'home workout',
      ),
    ],
    'music_creativity': [
      _ReplacementSuggestion(
        title: 'Playlist enfocada',
        action: 'Escucha musica instrumental para trabajar o relajarte.',
        icon: Icons.queue_music_rounded,
        playStorePackageId: 'com.spotify.music',
        featured: true,
        playStoreQuery: 'Spotify',
      ),
      _ReplacementSuggestion(
        title: 'Escritura libre',
        action: 'Anota ideas, pendientes o un diario rapido de 10 minutos.',
        icon: Icons.edit_note_rounded,
        playStorePackageId: 'com.microsoft.office.onenote',
        playStoreQuery: 'OneNote',
      ),
      _ReplacementSuggestion(
        title: 'Dibujo o boceto',
        action: 'Haz un boceto simple para activar creatividad sin presion.',
        icon: Icons.brush_rounded,
        playStorePackageId: 'com.adsk.sketchbook',
        playStoreQuery: 'Sketchbook',
      ),
      _ReplacementSuggestion(
        title: 'Practica musical',
        action: 'Si tocas un instrumento, practica una cancion corta.',
        icon: Icons.piano_rounded,
        playStorePackageId: 'com.bandlab.bandlab',
        playStoreQuery: 'BandLab',
      ),
    ],
    'focus_games': [
      _ReplacementSuggestion(
        title: 'Sudoku o logica',
        action: 'Resuelve un desafio de logica para entrenar concentracion.',
        icon: Icons.grid_view_rounded,
        playStorePackageId: 'easy.sudoku.puzzle.solver.free',
        featured: true,
        playStoreQuery: 'sudoku',
      ),
      _ReplacementSuggestion(
        title: 'Ajedrez tactico',
        action: 'Juega una partida corta o un problema tactico.',
        icon: Icons.extension_rounded,
        playStorePackageId: 'com.chess',
        playStoreQuery: 'chess',
      ),
      _ReplacementSuggestion(
        title: 'Memoria activa',
        action: 'Usa ejercicios de memoria durante 10 minutos.',
        icon: Icons.psychology_rounded,
        playStorePackageId: 'com.peak.app',
        playStoreQuery: 'Peak brain training',
      ),
      _ReplacementSuggestion(
        title: 'Desafio de foco',
        action: 'Configura 25 minutos de foco total en una tarea concreta.',
        icon: Icons.timer_rounded,
        playStorePackageId: 'com.pomodrone.app',
        playStoreQuery: 'Pomodoro timer',
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
  String? requesterName;
  String? friendName;
  String? friendEmail;
  String? friendWhatsappE164;
  String _notificationMode = _notificationEmailOnly;

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
    final savedBlocks = prefs.getStringList('activeBlocks') ?? [];
    final savedApps = prefs.getStringList('selectedApps') ?? [];

    final decodedApps = savedApps
        .map((item) => Map<String, String>.from(jsonDecode(item)))
        .toList();

    final decodedBlocks = savedBlocks
        .map((item) => AppBlock.fromMap(jsonDecode(item)))
        .toList();
    final now = DateTime.now();
    final activeBlockedPackages = decodedBlocks
        .where(
          (block) =>
              block.packageName.trim().isNotEmpty && block.endDate.isAfter(now),
        )
        .map((block) => block.packageName.trim())
        .toSet();
    final activeBlockedSelectedApps = decodedBlocks
        .where(
          (block) =>
              block.packageName.trim().isNotEmpty && block.endDate.isAfter(now),
        )
        .map((block) {
          final packageName = block.packageName.trim();
          final appName = block.appName.trim().isNotEmpty
              ? block.appName.trim()
              : packageName;
          return <String, String>{
            'packageName': packageName,
            'appName': appName,
          };
        })
        .toList();
    final additionalDecodedApps = decodedApps.where((app) {
      final packageName = (app['packageName'] ?? '').trim();
      if (packageName.isEmpty) return false;
      return !activeBlockedPackages.contains(packageName);
    }).toList();
    final selectedByPackage = <String, Map<String, String>>{};
    for (final app in activeBlockedSelectedApps) {
      final packageName = (app['packageName'] ?? '').trim();
      if (packageName.isEmpty) continue;
      selectedByPackage[packageName] = app;
    }
    for (final app in additionalDecodedApps) {
      final packageName = (app['packageName'] ?? '').trim();
      if (packageName.isEmpty) continue;
      selectedByPackage[packageName] = {
        'packageName': packageName,
        'appName': (app['appName'] ?? '').trim().isNotEmpty
            ? (app['appName'] ?? '').trim()
            : packageName,
      };
    }
    final normalizedSelectedApps = selectedByPackage.values.toList();
    final normalizedNeedsSave = normalizedSelectedApps.length != decodedApps.length ||
        additionalDecodedApps.length != decodedApps.length;
    if (normalizedNeedsSave) {
      await prefs.setStringList(
        'selectedApps',
        normalizedSelectedApps.map((app) => jsonEncode(app)).toList(),
      );
    }
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
        ..addAll(normalizedSelectedApps);

      requesterName = prefs.getString(_requesterNameKey);
      friendName = prefs.getString('friendName');
      friendEmail = prefs.getString('friendEmail');
      friendWhatsappE164 = prefs.getString(_friendWhatsappE164Key);
      final savedNotificationMode = prefs.getString(_notificationModeKey);
      _notificationMode = savedNotificationMode == _notificationWhatsappOnly
          ? _notificationWhatsappOnly
          : _notificationEmailOnly;
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

  AppBlock? _activeBlockForPackage(String packageName) {
    final normalizedPackage = packageName.trim();
    if (normalizedPackage.isEmpty) return null;
    final now = DateTime.now();

    AppBlock? latest;
    for (final block in activeBlocks) {
      if (block.packageName.trim() != normalizedPackage) continue;
      if (!block.endDate.isAfter(now)) continue;
      if (latest == null || block.endDate.isAfter(latest.endDate)) {
        latest = block;
      }
    }
    return latest;
  }

  bool _isPackageAlreadyBlocked(String packageName) {
    return _activeBlockForPackage(packageName) != null;
  }

  bool get _hasFriendConfigured {
    final name = (friendName ?? '').trim();
    if (name.isEmpty) return false;
    if (_requiresWhatsappChannel) return _hasValidWhatsappForMode;
    final email = (friendEmail ?? '').trim();
    return email.isNotEmpty;
  }

  bool get _hasRequesterConfigured => (requesterName ?? '').trim().isNotEmpty;

  bool get _requiresWhatsappChannel =>
      _notificationMode == _notificationWhatsappOnly;

  bool _isValidE164(String value) {
    return RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(value);
  }

  bool get _hasValidWhatsappForMode {
    if (!_requiresWhatsappChannel) return true;
    final whatsapp = (friendWhatsappE164 ?? '').trim();
    return _isValidE164(whatsapp);
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
  bool get _isStep2Ready =>
      selectedValue >= 1 && _hasRequesterConfigured && _hasFriendConfigured;
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
      if (_requiresWhatsappChannel && !_hasValidWhatsappForMode) {
        _showMessage(
          'Para usar WhatsApp, completa el numero del amigo en formato +5491112345678.',
        );
        return;
      }
      if (!_hasRequesterConfigured) {
        _showMessage('Completa el campo Solicitante para continuar.');
        return;
      }
      _showMessage('Defini duracion y amigo responsable para continuar.');
      return;
    }
  }

  Future<void> _togglePopularBlockApp(_PopularBlockAppOption option) async {
    if (_isPackageAlreadyBlocked(option.packageName)) {
      final appName = _displayNameForPackage(option.packageName);
      _showMessage('$appName ya esta bloqueada.');
      return;
    }

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

  Future<void> _openReplacementInStore(_ReplacementSuggestion suggestion) async {
    try {
      final marketUri = Uri.parse(
        'market://details?id=${Uri.encodeComponent(suggestion.playStorePackageId)}',
      );
      final webUri = Uri.parse(
        'https://play.google.com/store/apps/details?id=${Uri.encodeComponent(suggestion.playStorePackageId)}',
      );
      final searchUri = Uri.parse(
        'https://play.google.com/store/search?q=${Uri.encodeComponent(suggestion.playStoreQuery)}&c=apps',
      );

      final launchedMarket = await launchUrl(
        marketUri,
        mode: LaunchMode.externalApplication,
      );
      if (launchedMarket) return;

      final launchedWeb = await launchUrl(
        webUri,
        mode: LaunchMode.externalApplication,
      );
      if (launchedWeb) return;

      final launchedSearch = await launchUrl(
        searchUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launchedSearch && mounted) {
        _showMessage('No se pudo abrir Play Store en este momento.');
      }
    } catch (_) {
      if (mounted) {
        _showMessage('No se pudo abrir Play Store en este momento.');
      }
    }
  }

  void _showReplacementIdeas(_ReplacementOption option) {
    final ideas = _replacementSuggestionsByOptionId[option.id] ?? const [];
    if (ideas.isEmpty) return;
    final sortedIdeas = [...ideas]
      ..sort((a, b) {
        if (a.featured == b.featured) return 0;
        return a.featured ? -1 : 1;
      });

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.8,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
              child: Column(
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
                    'Toca una opcion para abrirla en Play Store y usarla ahora.',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 10),
                  ...sortedIdeas.map(
                    (idea) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _openReplacementInStore(idea),
                          child: Ink(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFD5D8E0)),
                              color: Colors.white,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF3FF),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(idea.icon, color: const Color(0xFF3558D6)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              idea.title,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          if (idea.featured)
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 3,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFE7F2E8),
                                                borderRadius: BorderRadius.circular(999),
                                              ),
                                              child: const Text(
                                                'Recomendada',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF1E7B3A),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        idea.action,
                                        style: const TextStyle(color: Colors.black87),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        'Abrir en Play Store',
                                        style: TextStyle(
                                          color: Color(0xFF3558D6),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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
    await prefs.setString(_requesterNameKey, requesterName ?? '');
    await prefs.setString('friendName', friendName ?? '');
    await prefs.setString('friendEmail', friendEmail ?? '');
    await prefs.setString(_friendWhatsappE164Key, friendWhatsappE164 ?? '');
    await prefs.setString(_notificationModeKey, _notificationMode);
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
          initialRequesterName: requesterName,
          initialName: friendName,
          initialEmail: friendEmail,
          initialWhatsappE164: friendWhatsappE164,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        requesterName = result['requesterName'];
        friendName = result['name'];
        friendEmail = result['email'];
        friendWhatsappE164 = result['whatsappE164'];
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
    final pendingByPackage = _parsePendingRequestsCsv(csv);

    // Si una app ya tiene desbloqueo temporal activo, esa solicitud deja de estar pendiente.
    final temporaryCsv = prefs.getString(_temporaryUnlockedKey) ?? '';
    final temporaryByPackage = _parseTemporaryUnlockedCsv(temporaryCsv);
    final now = DateTime.now().millisecondsSinceEpoch;
    final pendingKeys = pendingByPackage.keys.toList();
    var removedResolved = false;
    for (final packageName in pendingKeys) {
      final unlockUntil = temporaryByPackage[packageName];
      if (unlockUntil != null && unlockUntil > now) {
        pendingByPackage.remove(packageName);
        removedResolved = true;
      }
    }

    if (removedResolved) {
      await prefs.setString(
        _pendingRequestsKey,
        _serializePendingRequestsCsv(pendingByPackage),
      );
    }

    final loaded = pendingByPackage.values.toList()
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

  bool _isPermanentUnlock(_TemporaryUnlockInfo info) {
    final permanentThreshold = DateTime.utc(2099, 1, 1).millisecondsSinceEpoch;
    return info.unlockedUntilMillis >= permanentThreshold;
  }

  String _temporaryUnlockLabel(_TemporaryUnlockInfo info) {
    if (_isPermanentUnlock(info)) {
      return 'Permanente';
    }
    final remaining = _remainingMinutes(info);
    if (remaining <= 0) {
      return 'Expirado';
    }
    final until = DateTime.fromMillisecondsSinceEpoch(info.unlockedUntilMillis);
    return _remainingTimeFrom(until);
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

    final safeFriendName = (friendName ?? '').trim();
    final safeFriendEmail = (friendEmail ?? '').trim();

    if (safeFriendName.isEmpty) {
      _showMessage('Primero elegi un amigo responsable.');
      return;
    }

    if (_requiresWhatsappChannel && !_hasValidWhatsappForMode) {
      _showMessage(
        'Para usar WhatsApp, completa el numero del amigo en formato +5491112345678.',
      );
      return;
    }

    if (!_requiresWhatsappChannel && safeFriendEmail.isEmpty) {
      _showMessage('Para usar email, completa el email del amigo responsable.');
      return;
    }

    final now = DateTime.now();
    final selectedPackageSet = selectedApps
        .map((app) => (app['packageName'] ?? '').trim())
        .where((packageName) => packageName.isNotEmpty)
        .toSet();

    DateTime calculateEndDate() {
      return selectedDurationType == _durationDays
          ? now.add(Duration(days: selectedValue.round()))
          : DateTime(
              now.year,
              now.month + selectedValue.round(),
              now.day,
              now.hour,
              now.minute,
              now.second,
            );
    }

    for (final app in selectedApps) {
      final packageName = app['packageName'] ?? '';
      final appName = app['appName'] ?? 'App sin nombre';
      final endDate = calculateEndDate();

      final existingIndex = activeBlocks.indexWhere(
        (block) => block.packageName == packageName,
      );

      final updatedBlock = AppBlock(
        appName: appName,
        packageName: packageName,
        durationType: selectedDurationType,
        durationValue: selectedValue.round(),
        friendName: safeFriendName,
        friendEmail: safeFriendEmail,
        startDate: now,
        endDate: endDate,
      );

      if (existingIndex >= 0) {
        activeBlocks[existingIndex] = updatedBlock;
        continue;
      }

      activeBlocks.add(updatedBlock);
    }

    final prefs = await SharedPreferences.getInstance();
    final ignoredGrantKeys = _parseCsvSet(
      prefs.getString(_ignoredUnlockGrantsKey) ?? '',
    );

    for (final packageName in selectedPackageSet) {
      final matchingGrant = _lastSyncActiveGrants
          .where((grant) => grant.packageName == packageName)
          .fold<UnlockGrantActiveGrant?>(null, (latest, current) {
        if (latest == null) return current;
        return current.unlockUntilMillis > latest.unlockUntilMillis ? current : latest;
      });

      final grantRequestId = matchingGrant?.requestId?.trim();
      if (grantRequestId != null && grantRequestId.isNotEmpty) {
        ignoredGrantKeys.add('$packageName|$grantRequestId');
      }
    }
    await prefs.setString(
      _ignoredUnlockGrantsKey,
      _serializeCsvSet(ignoredGrantKeys),
    );

    final temporaryByPackage = _parseTemporaryUnlockedCsv(
      prefs.getString(_temporaryUnlockedKey) ?? '',
    );
    final temporaryKeys = temporaryByPackage.keys.toList();
    var removedTemporaryUnlocks = false;
    for (final packageName in temporaryKeys) {
      if (selectedPackageSet.contains(packageName)) {
        temporaryByPackage.remove(packageName);
        removedTemporaryUnlocks = true;
      }
    }
    if (removedTemporaryUnlocks) {
      await prefs.setString(
        _temporaryUnlockedKey,
        _serializeTemporaryUnlockedCsv(temporaryByPackage),
      );
    }

    final pendingByPackage = _parsePendingRequestsCsv(
      prefs.getString(_pendingRequestsKey) ?? '',
    );
    final pendingKeys = pendingByPackage.keys.toList();
    var removedPendingRequests = false;
    for (final packageName in pendingKeys) {
      if (selectedPackageSet.contains(packageName)) {
        pendingByPackage.remove(packageName);
        removedPendingRequests = true;
      }
    }
    if (removedPendingRequests) {
      await prefs.setString(
        _pendingRequestsKey,
        _serializePendingRequestsCsv(pendingByPackage),
      );
    }

    await _saveBlocks();
    await _saveBlockedPackagesForAndroid();
    await _loadTemporaryUnlockedApps();
    await _loadPendingRequests();

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
    await prefs.remove(_requesterNameKey);
    await prefs.remove('friendName');
    await prefs.remove('friendEmail');
    await prefs.remove(_friendWhatsappE164Key);
    await prefs.remove(_notificationModeKey);
    await prefs.remove('activeBlocks');
    await prefs.remove('blocked_packages_csv');
    await prefs.remove('pending_unlock_requests_csv');
    await prefs.remove('temporary_unlocked_packages_csv');
    await prefs.remove(_ignoredUnlockGrantsKey);
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
      requesterName = null;
      friendName = null;
      friendEmail = null;
      friendWhatsappE164 = null;
      _notificationMode = _notificationEmailOnly;
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
    if (selectedPackages.isEmpty) {
      return activeBlocks.where((block) => block.endDate.isAfter(now)).toList();
    }
    return activeBlocks.where((block) {
      return selectedPackages.contains(block.packageName) &&
          block.endDate.isAfter(now);
    }).toList();
  }

  List<_TemporaryUnlockInfo> _selectedActiveTemporaryUnlocks() {
    final selectedPackages = selectedApps
        .map((app) => (app['packageName'] ?? '').trim())
        .where((packageName) => packageName.isNotEmpty)
        .toSet();
    final now = DateTime.now().millisecondsSinceEpoch;
    if (selectedPackages.isEmpty) {
      return temporaryUnlockedApps
          .where((unlock) => unlock.unlockedUntilMillis > now)
          .toList();
    }
    return temporaryUnlockedApps.where((unlock) {
      return selectedPackages.contains(unlock.packageName) &&
          unlock.unlockedUntilMillis > now;
    }).toList();
  }

  _TemporaryUnlockInfo? _activeTemporaryUnlockForPackage(String packageName) {
    final normalizedPackage = packageName.trim();
    if (normalizedPackage.isEmpty) return null;
    final now = DateTime.now().millisecondsSinceEpoch;

    _TemporaryUnlockInfo? latest;
    for (final unlock in temporaryUnlockedApps) {
      if (unlock.packageName != normalizedPackage) continue;
      if (unlock.unlockedUntilMillis <= now) continue;
      if (latest == null || unlock.unlockedUntilMillis > latest.unlockedUntilMillis) {
        latest = unlock;
      }
    }
    return latest;
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

  DateTime _addMonthsKeepingClock(DateTime base, int monthsToAdd) {
    final monthIndex = base.month - 1 + monthsToAdd;
    final targetYear = base.year + (monthIndex ~/ 12);
    final targetMonth = (monthIndex % 12) + 1;
    final maxDay = DateTime(targetYear, targetMonth + 1, 0).day;
    final targetDay = base.day > maxDay ? maxDay : base.day;
    return DateTime(
      targetYear,
      targetMonth,
      targetDay,
      base.hour,
      base.minute,
      base.second,
      base.millisecond,
      base.microsecond,
    );
  }

  String _remainingBlockTimeFrom(DateTime endDate) {
    final now = DateTime.now();
    if (!endDate.isAfter(now)) return 'Finalizado';

    var cursor = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
      now.second,
      now.millisecond,
      now.microsecond,
    );
    var months = 0;

    while (months < 2400) {
      final next = _addMonthsKeepingClock(cursor, 1);
      if (next.isAfter(endDate)) break;
      months += 1;
      cursor = next;
    }

    final remainder = endDate.difference(cursor);
    final days = remainder.inDays;
    final hours = remainder.inHours.remainder(24);

    final parts = <String>[];
    if (months > 0) {
      parts.add(months == 1 ? '1 mes' : '$months meses');
    }
    if (days > 0 || months > 0) {
      parts.add('${days}d');
    }
    if (hours > 0 || days > 0 || months > 0) {
      parts.add('${hours}h');
    }

    if (parts.isEmpty) {
      final minutes = remainder.inMinutes <= 0 ? 1 : remainder.inMinutes;
      return '${minutes}m';
    }

    return parts.join(' ');
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

  List<_ReplacementOption> get _selectedReplacementOptions {
    return _replacementOptions
        .where((option) => _selectedReplacementIds.contains(option.id))
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
              final activeBlock = _activeBlockForPackage(option.packageName);
              final isAlreadyBlocked = activeBlock != null;
              final blockedSubtitle = isAlreadyBlocked
                  ? 'Ya bloqueada (${_remainingBlockTimeFrom(activeBlock!.endDate)})'
                  : '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SelectableOptionCard(
                  title: option.appName,
                  subtitle: isAlreadyBlocked
                      ? blockedSubtitle
                      : (isAvailable
                            ? 'Disponible en este dispositivo'
                            : 'No instalada en este dispositivo'),
                  icon: option.icon,
                  selected: isSelected,
                  enabled: !isAlreadyBlocked && (isAvailable || isSelected),
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
                      Text('Solicitante: ${requesterName ?? ''}'),
                      Text('Nombre: ${friendName ?? ''}'),
                      Text('Email: ${friendEmail ?? ''}'),
                      if ((friendWhatsappE164 ?? '').trim().isNotEmpty)
                        Text('WhatsApp: ${friendWhatsappE164 ?? ''}'),
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
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Canal de solicitud',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment<String>(
                          value: _notificationEmailOnly,
                          label: Text('Solo email'),
                          icon: Icon(Icons.email_outlined),
                        ),
                        ButtonSegment<String>(
                          value: _notificationWhatsappOnly,
                          label: Text('Solo WhatsApp'),
                          icon: Icon(Icons.chat_outlined),
                        ),
                      ],
                      selected: {_notificationMode},
                      onSelectionChanged: (newSelection) async {
                        setState(() {
                          _notificationMode = newSelection.first;
                        });
                        await _saveData();
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _requiresWhatsappChannel
                          ? 'Se envia por WhatsApp automaticamente.'
                          : 'Se envia por email automaticamente.',
                      style: const TextStyle(color: Colors.black54),
                    ),
                    if (_requiresWhatsappChannel) ...[
                      const SizedBox(height: 8),
                      if (_hasValidWhatsappForMode)
                        Text(
                          'WhatsApp configurado: ${friendWhatsappE164 ?? ''}',
                          style: const TextStyle(
                            color: Color(0xFF1E7B3A),
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else
                        const Text(
                          'Falta WhatsApp valido del amigo (formato +5491112345678). Editalo en \"Elegir amigo responsable\".',
                          style: TextStyle(
                            color: Color(0xFFB3261E),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
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
        subtitle: 'Elegi categorias para personalizar tus sugerencias y abrir opciones concretas',
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
                    SizedBox(height: 6),
                    Text(
                      'Cuando elegis una categoria, la guardamos en tu plan y ademas podes abrir apps sugeridas al instante.',
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
                child: SelectableOptionCard(
                  title: option.title,
                  subtitle: '${option.subtitle} Toca para ver apps sugeridas.',
                  icon: option.icon,
                  selected: isSelected,
                  onTap: () {
                    _toggleReplacementOption(option.id);
                    _showReplacementIdeas(option);
                  },
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
    final selectedTemporaryUnlocks = _selectedActiveTemporaryUnlocks();
    final isBlockingActive = _hasSelectedAppsActiveBlock;
    final selectedReplacementOptions = _selectedReplacementOptions;
    String remainingOverview = 'Aun no hay un bloqueo activo para las apps elegidas.';
    if (selectedTemporaryUnlocks.isNotEmpty) {
      final unlockCount = selectedTemporaryUnlocks.length;
      if (unlockCount == 1) {
        final unlock = selectedTemporaryUnlocks.first;
        final appName = _displayNameForPackage(unlock.packageName);
        final label = _temporaryUnlockLabel(unlock);
        remainingOverview = 'Desbloqueo temporal activo para $appName ($label).';
      } else {
        remainingOverview = 'Hay $unlockCount apps con desbloqueo temporal activo.';
      }
    } else if (selectedActiveBlocks.isNotEmpty) {
      DateTime nearestEnd = selectedActiveBlocks.first.endDate;
      for (final block in selectedActiveBlocks) {
        if (block.endDate.isBefore(nearestEnd)) {
          nearestEnd = block.endDate;
        }
      }
      remainingOverview = 'Tiempo restante aproximado: ${_remainingBlockTimeFrom(nearestEnd)}';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: WizardStepShell(
        stepLabel: null,
        title: 'Resumen final',
        subtitle: 'Asi quedo configurado tu plan y como vamos a acompanarte.',
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
                      'Plan configurado',
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
                    const Divider(height: 22),
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded, size: 18),
                        const SizedBox(width: 8),
                        Text('Duracion elegida: $durationText'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.group_rounded, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _hasFriendConfigured
                                ? 'Solicitante: ${requesterName ?? ''}\nAmigo responsable: ${friendName ?? ''} - ${friendEmail ?? ''}'
                                : 'Solicitante: ${requesterName ?? ''}\nAmigo responsable: no definido',
                          ),
                        ),
                      ],
                    ),
                    if (_notificationMode == _notificationWhatsappOnly) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.chat_outlined, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              (friendWhatsappE164 ?? '').trim().isEmpty
                                  ? 'Canal: Solo WhatsApp'
                                  : 'Canal: Solo WhatsApp (${friendWhatsappE164 ?? ''})',
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 4),
                      const Row(
                        children: [
                          Icon(Icons.email_outlined, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text('Canal: Solo email'),
                          ),
                        ],
                      ),
                    ],
                    if (selectedActiveBlocks.isNotEmpty) ...[
                      const Divider(height: 22),
                      const Text(
                        'Estado por app',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      ...selectedActiveBlocks.map((block) {
                        final appName = block.appName.trim().isNotEmpty
                            ? block.appName.trim()
                            : _displayNameForPackage(block.packageName);
                        final activeTemporaryUnlock = _activeTemporaryUnlockForPackage(
                          block.packageName,
                        );
                        final isTemporarilyUnlocked = activeTemporaryUnlock != null;
                        final timeLabel = isTemporarilyUnlocked
                            ? (_isPermanentUnlock(activeTemporaryUnlock!)
                                  ? 'Desbloqueada'
                                  : _temporaryUnlockLabel(activeTemporaryUnlock!))
                            : _remainingBlockTimeFrom(block.endDate);
                        final statusLabel = isTemporarilyUnlocked
                            ? 'Desbloqueada temporalmente'
                            : 'Bloqueada';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Icon(
                                isTemporarilyUnlocked
                                    ? Icons.lock_open_rounded
                                    : Icons.lock_clock_rounded,
                                size: 18,
                                color: isTemporarilyUnlocked ? Colors.teal.shade700 : null,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(appName),
                                    Text(
                                      statusLabel,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isTemporarilyUnlocked
                                            ? Colors.teal.shade700
                                            : Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                timeLabel,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
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
                      'Reemplazos elegidos',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    if (selectedReplacementOptions.isEmpty)
                      const Text(
                        'No elegiste categorias todavia. Podes volver al Paso 3 para sumar ideas utiles.',
                      )
                    else
                      ...selectedReplacementOptions.map(
                        (option) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Card(
                            margin: EdgeInsets.zero,
                            child: ListTile(
                              leading: Icon(option.icon),
                              title: Text(option.title),
                              subtitle: const Text(
                                'Abrir sugerencias concretas para esta categoria.',
                              ),
                              trailing: OutlinedButton(
                                onPressed: () => _showReplacementIdeas(option),
                                child: const Text('Ver apps'),
                              ),
                            ),
                          ),
                        ),
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
                      'Solicitudes y desbloqueos temporales',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Aqui ves lo que tu amigo aun debe aprobar y cualquier desbloqueo temporal ya activo.',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _openPendingRequestsScreen,
                      icon: const Icon(Icons.pending_actions_rounded),
                      label: Text(
                        'Solicitudes pendientes (${pendingRequests.length})',
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (pendingRequests.isEmpty)
                      const Text(
                        'No hay solicitudes pendientes en este momento.',
                      )
                    else
                      ...pendingRequests.take(2).map((request) {
                        final appName = _displayNameForPackage(request.packageName);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              const Icon(Icons.mark_email_unread_outlined, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '$appName - ${_pendingRequestedAtText(request)}',
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    const Divider(height: 20),
                    const Text(
                      'Desbloqueos temporales activos',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    if (temporaryUnlockedApps.isEmpty)
                      const Text('No hay desbloqueos temporales activos.')
                    else
                      ...temporaryUnlockedApps.map((item) {
                        final remainingLabel = _temporaryUnlockLabel(item);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              const Icon(Icons.lock_open_rounded, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(_displayNameForPackage(item.packageName)),
                              ),
                              Text(
                                remainingLabel,
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

