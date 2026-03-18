import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_block.dart';
import '../services/usage_access_service.dart';
import 'apps_selection_screen.dart';
import 'friend_screen.dart';
import 'block_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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

  bool _isBlockScreenOpen = false;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
    _checkUsagePermission();
    _startMonitoring();
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedBlocks = prefs.getStringList('activeBlocks') ?? [];
    final savedApps = prefs.getStringList('selectedApps') ?? [];

    setState(() {
      selectedDurationType = prefs.getString('durationType') ?? 'Días';
      selectedValue = prefs.getDouble('durationValue') ?? 7;

      selectedApps
        ..clear()
        ..addAll(
          savedApps.map(
            (item) => Map<String, String>.from(jsonDecode(item)),
          ),
        );

      friendName = prefs.getString('friendName');
      friendEmail = prefs.getString('friendEmail');

      activeBlocks = savedBlocks
          .map((item) => AppBlock.fromMap(jsonDecode(item)))
          .toList();

      isLoading = false;
    });
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

    _checkIfDetectedAppIsBlocked(packageName);
  }

  void _checkIfDetectedAppIsBlocked(String? packageName) {
    if (packageName == null) return;
    if (_isBlockScreenOpen) return;

    AppBlock? matchedBlock;

    for (final block in activeBlocks) {
      if (block.packageName == packageName) {
        matchedBlock = block;
        break;
      }
    }

    if (matchedBlock != null) {
      _openBlockScreen(matchedBlock);
    }
  }

  void _openBlockScreen(AppBlock block) {
    _isBlockScreenOpen = true;

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
    ).then((_) {
      _isBlockScreenOpen = false;
    });
  }

  void _startMonitoring() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 3));

      if (!mounted) return false;

      if (hasUsagePermission) {
        await _detectCurrentApp();
      }

      return true;
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
    if (!mounted) return;
    setState(() {});

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

    setState(() {
      selectedDurationType = 'Días';
      selectedValue = 7;
      selectedApps.clear();
      friendName = null;
      friendEmail = null;
      activeBlocks.clear();
      currentForegroundApp = 'No detectada';
    });

    _showMessage('Datos borrados.');
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