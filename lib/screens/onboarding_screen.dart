import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/accessibility_service_status.dart';
import '../services/usage_access_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with WidgetsBindingObserver {
  final _pageController = PageController();
  int _currentPage = 0;

  final _accessibilityStatus = AccessibilityServiceStatus();
  final _usageAccessService = UsageAccessService();

  bool _accessibilityEnabled = false;
  bool _usageAccessEnabled = false;
  bool _checkingPermissions = false;

  static const _totalPages = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    if (!Platform.isAndroid) {
      setState(() {
        _accessibilityEnabled = true;
        _usageAccessEnabled = true;
      });
      return;
    }
    setState(() => _checkingPermissions = true);
    final a = await _accessibilityStatus.isEnabled();
    final u = await _usageAccessService.hasPermission();
    if (!mounted) return;
    setState(() {
      _accessibilityEnabled = a;
      _usageAccessEnabled = u;
      _checkingPermissions = false;
    });
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Barra de progreso superior
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: List.generate(_totalPages, (i) {
                  final isActive = i <= _currentPage;
                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.only(right: i < _totalPages - 1 ? 6 : 0),
                      height: 3,
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.primary : AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Contenido de páginas
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _buildWelcomePage(),
                  _buildAccessibilityPage(),
                  _buildUsageAccessPage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Página 1: Bienvenida ─────────────────────────
  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          // Logo / ícono central
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.30),
              ),
            ),
            child: const Icon(
              Icons.bolt_rounded,
              size: 52,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Bienvenido a\nUnscroll',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Esta app te ayuda a bloquear redes sociales y recuperar tu tiempo, con el apoyo de un amigo responsable.',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          _buildFeatureRow(
            icon: Icons.block_rounded,
            text: 'Bloqueá apps que te distraen',
          ),
          const SizedBox(height: 12),
          _buildFeatureRow(
            icon: Icons.group_rounded,
            text: 'Tu amigo aprueba cada desbloqueo',
          ),
          const SizedBox(height: 12),
          _buildFeatureRow(
            icon: Icons.self_improvement_rounded,
            text: 'Reemplazá el tiempo con actividades que suman',
          ),
          const Spacer(flex: 2),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: () => _goToPage(1),
            child: const Text('Empezar configuración'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _completeOnboarding,
            child: const Text(
              'Saltar por ahora',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  // ── Página 2: Accessibility Service ─────────────
  Widget _buildAccessibilityPage() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          _buildPermissionIcon(
            icon: Icons.accessibility_new_rounded,
            enabled: _accessibilityEnabled,
          ),
          const SizedBox(height: 32),
          const Text(
            'Permiso de\nAccesibilidad',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Este permiso permite a la app detectar cuándo abrís una app bloqueada y mostrar la pantalla de pausa.',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          _buildPermissionSteps(const [
            'Tocá "Activar permiso" abajo',
            'Buscá "Unscroll" en la lista de servicios',
            'Tocá "Unscroll" y activá el interruptor que aparece arriba a la derecha',
            'Confirmá en el diálogo y volvé aquí',
          ]),
          const Spacer(flex: 2),
          if (_checkingPermissions)
            const Center(child: CircularProgressIndicator())
          else if (_accessibilityEnabled)
            _buildPermissionGranted('Permiso de accesibilidad activado')
          else
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () async {
                await _accessibilityStatus.openSettings();
                await Future.delayed(const Duration(seconds: 2));
                await _checkPermissions();
              },
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Activar permiso'),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _goToPage(0),
                  child: const Text('Volver'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: _accessibilityEnabled
                        ? AppColors.primary
                        : AppColors.surface,
                    foregroundColor: _accessibilityEnabled
                        ? Colors.white
                        : AppColors.textMuted,
                  ),
                  onPressed: () async {
                    await _checkPermissions();
                    if (mounted) _goToPage(2);
                  },
                  child: Text(
                    _accessibilityEnabled ? 'Continuar' : 'Saltar este paso',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Página 3: Usage Access ───────────────────────
  Widget _buildUsageAccessPage() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          _buildPermissionIcon(
            icon: Icons.bar_chart_rounded,
            enabled: _usageAccessEnabled,
          ),
          const SizedBox(height: 32),
          const Text(
            'Acceso al uso\nde apps',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Este permiso permite detectar qué app está en primer plano para activar el bloqueo en el momento exacto.',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          _buildPermissionSteps(const [
            'Tocá "Activar permiso" abajo',
            'Buscá "Unscroll" en la lista',
            'Activá el interruptor junto a "Unscroll"',
            'Confirmá y volvé aquí',
          ]),
          const Spacer(flex: 2),
          if (_checkingPermissions)
            const Center(child: CircularProgressIndicator())
          else if (_usageAccessEnabled)
            _buildPermissionGranted('Acceso de uso activado')
          else
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () async {
                await _usageAccessService.requestPermission();
                await Future.delayed(const Duration(seconds: 2));
                await _checkPermissions();
              },
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Activar permiso'),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _goToPage(1),
                  child: const Text('Volver'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _completeOnboarding,
                  child: const Text('Ir a la app'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Widgets auxiliares ───────────────────────────

  Widget _buildFeatureRow({required IconData icon, required String text}) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionIcon({
    required IconData icon,
    required bool enabled,
  }) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: enabled
            ? AppColors.primary.withValues(alpha: 0.12)
            : AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: enabled
              ? AppColors.primary.withValues(alpha: 0.30)
              : AppColors.borderStrong,
        ),
      ),
      child: Icon(
        icon,
        size: 46,
        color: enabled ? AppColors.primary : AppColors.textMuted,
      ),
    );
  }

  Widget _buildPermissionSteps(List<String> steps) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: steps.asMap().entries.map((e) {
          final i = e.key;
          final step = e.value;
          return Padding(
            padding: EdgeInsets.only(bottom: i < steps.length - 1 ? 10 : 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    step,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPermissionGranted(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.primaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
