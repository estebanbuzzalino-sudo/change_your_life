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
  bool isUsingFallbackMode = false;
  static const String _ownPackage = 'com.example.change_your_life';
  static const Set<String> _blockedExactPackages = {
    'android',
    'com.android.settings',
    'com.android.systemui',
    'com.google.android.gms',
    'com.android.permissioncontroller',
    'com.google.android.permissioncontroller',
    'com.android.launcher3',
    'com.google.android.apps.nexuslauncher',
    'com.sec.android.app.launcher',
    'com.miui.home',
    'com.huawei.android.launcher',
    'com.oppo.launcher',
    'com.oneplus.launcher',
  };
  static const List<String> _blockedPrefixes = [
    'com.android.',
    'android.',
    'com.google.android.',
    'com.samsung.',
    'com.sec.',
    'com.miui.',
    'com.huawei.',
    'com.oppo.',
    'com.oneplus.',
    'com.qualcomm.',
  ];
  static const Set<String> _socialExactPackages = {
    'com.instagram.android',
    'com.facebook.katana',
    'com.facebook.orca',
    'com.twitter.android',
    'com.snapchat.android',
    'com.zhiliaoapp.musically',
    'com.ss.android.ugc.trill',
    'org.telegram.messenger',
    'org.telegram.plus',
    'com.whatsapp',
    'com.whatsapp.w4b',
    'com.discord',
    'com.reddit.frontpage',
    'com.pinterest',
    'com.linkedin.android',
    'com.vkontakte.android',
    'com.tencent.mm',
    'com.bereal.ft',
    'com.ss.android.ugc.aweme',
    'com.threads.android',
  };
  static const List<String> _socialPackageTokens = [
    'instagram',
    'facebook',
    'messenger',
    'twitter',
    'x.',
    'snapchat',
    'telegram',
    'whatsapp',
    'discord',
    'reddit',
    'pinterest',
    'linkedin',
    'tiktok',
    'musically',
    'threads',
    'bereal',
  ];
  static const List<String> _socialNameKeywords = [
    'instagram',
    'facebook',
    'messenger',
    'twitter',
    'snapchat',
    'telegram',
    'whatsapp',
    'discord',
    'reddit',
    'pinterest',
    'linkedin',
    'tiktok',
    'threads',
    'be real',
    'bereal',
  ];

  @override
  void initState() {
    super.initState();
    tempSelectedApps = List<Map<String, String>>.from(widget.initialSelectedApps);
    _loadInstalledApps();
  }

  Future<void> _loadInstalledApps() async {
    try {
      var usedFallbackMode = false;
      var apps = await InstalledApps.getInstalledApps(
        excludeSystemApps: true,
        excludeNonLaunchableApps: true,
        withIcon: false,
      );

      apps = apps.where((app) => app.packageName.trim() != _ownPackage).toList();
      apps = apps.where(_isSocialApp).toList();

      // Fallback for devices where system-app detection is too aggressive.
      if (apps.isEmpty) {
        usedFallbackMode = true;
        final fallbackApps = await InstalledApps.getInstalledApps(
          excludeSystemApps: false,
          excludeNonLaunchableApps: true,
          withIcon: false,
        );
        apps = fallbackApps
            .where(_isSelectableFallbackApp)
            .where(_isSocialApp)
            .toList();
      }

      apps.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

      setState(() {
        installedApps = apps;
        isUsingFallbackMode = usedFallbackMode;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isUsingFallbackMode = false;
        isLoading = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando apps: $e')),
      );
    }
  }

  bool _isSelectableFallbackApp(AppInfo app) {
    final packageName = app.packageName.trim();
    if (packageName.isEmpty || packageName == _ownPackage) {
      return false;
    }

    if (_blockedExactPackages.contains(packageName)) {
      return false;
    }

    for (final prefix in _blockedPrefixes) {
      if (packageName.startsWith(prefix)) {
        return false;
      }
    }

    return true;
  }

  bool _isSocialApp(AppInfo app) {
    final packageName = app.packageName.trim().toLowerCase();
    final appName = app.name.trim().toLowerCase();

    if (_socialExactPackages.contains(packageName)) {
      return true;
    }

    for (final token in _socialPackageTokens) {
      if (packageName.contains(token)) {
        return true;
      }
    }

    for (final keyword in _socialNameKeywords) {
      if (appName.contains(keyword)) {
        return true;
      }
    }

    return false;
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
              ? const Center(child: Text('No se encontraron redes sociales instaladas'))
              : Column(
                  children: [
                    if (isUsingFallbackMode)
                      Container(
                        width: double.infinity,
                        color: Colors.amber.shade100,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.info_outline,
                                size: 20, color: Color(0xFF8B5C00)),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'En este dispositivo no pudimos detectar bien el listado. '
                                'Es posible que falten algunas apps; si no encontrás la que '
                                'querés bloquear, contactanos.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF6B4400),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: installedApps.length,
                        itemBuilder: (context, index) {
                          final app = installedApps[index];
                          final isSelected = _isSelected(app);

                          return CheckboxListTile(
                            title: Text(app.name),
                            value: isSelected,
                            onChanged: (value) {
                              _toggleApp(app, value ?? false);
                            },
                          );
                        },
                      ),
                    ),
                  ],
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

