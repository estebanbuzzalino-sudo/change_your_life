import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';

class AppsSelectionScreen extends StatefulWidget {
  final List<Map<String, String>> initialSelectedApps;

  const AppsSelectionScreen({
    super.key,
    required this.initialSelectedApps,
  });

  @override
  State<AppsSelectionScreen> createState() => _AppsSelectionScreenState();
}

class _AppsSelectionScreenState extends State<AppsSelectionScreen> {
  late List<Map<String, String>> tempSelectedApps;
  List<AppInfo> installedApps = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    tempSelectedApps = List<Map<String, String>>.from(widget.initialSelectedApps);
    _loadInstalledApps();
  }

  Future<void> _loadInstalledApps() async {
    try {
      final apps = await InstalledApps.getInstalledApps(
        excludeSystemApps: true,
        excludeNonLaunchableApps: true,
        withIcon: false,
      );

      apps.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

      setState(() {
        installedApps = apps;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando apps: $e')),
      );
    }
  }

  bool _isSelected(AppInfo app) {
    return tempSelectedApps.any(
      (item) => item['packageName'] == app.packageName,
    );
  }

  void _toggleApp(AppInfo app, bool selected) {
    setState(() {
      if (selected) {
        if (!_isSelected(app)) {
          tempSelectedApps.add({
            'appName': app.name,
            'packageName': app.packageName,
          });
        }
      } else {
        tempSelectedApps.removeWhere(
          (item) => item['packageName'] == app.packageName,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar apps'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : installedApps.isEmpty
              ? const Center(child: Text('No se encontraron apps instaladas'))
              : ListView.builder(
                  itemCount: installedApps.length,
                  itemBuilder: (context, index) {
                    final app = installedApps[index];
                    final isSelected = _isSelected(app);

                    return CheckboxListTile(
                      title: Text(app.name),
                      subtitle: Text(app.packageName),
                      value: isSelected,
                      onChanged: (value) {
                        _toggleApp(app, value ?? false);
                      },
                    );
                  },
                ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: () {
            Navigator.pop(context, tempSelectedApps);
          },
          child: const Text('Guardar selección'),
        ),
      ),
    );
  }
}
