import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/accessibility_service_status.dart';
import '../services/usage_access_service.dart';
import '../theme/colors.dart';
import '../widgets/sr_widgets.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _pageController = PageController();

  final _accessibilityStatus = AccessibilityServiceStatus();
  final _usageAccessService = UsageAccessService();

  bool _accessibilityEnabled = false;
  bool _usageAccessEnabled = false;
  bool _checkingPermissions = false;

  // Float animation for slide A app icons
  late final AnimationController _floatController;
  late final Animation<double> _floatAnim;

  // Pulse animation for slide B anchor avatar
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  // Glow animation for slide C lock
  late final AnimationController _glowController;
  late final Animation<double> _glowAnim;

  // Stagger animation for slide C checklist
  late final AnimationController _staggerController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();

    // Float animation — looping 3s, vertical offset ±6px
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
    _floatAnim = CurvedAnimation(
      parent: _floatController,
      curve: Curves.linear,
    );

    // Pulse animation for anchor avatar — 1.0→1.04→1.0 loop
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Glow animation for lock — 0→18px every 2.4s
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.0, end: 18.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Stagger controller for slide C checklist items
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _floatController.dispose();
    _pulseController.dispose();
    _glowController.dispose();
    _staggerController.dispose();
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
    if (page == 2) {
      _staggerController.forward(from: 0);
    }
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  // ── Top-right skip button ────────────────────────
  Widget _buildSkipRow() {
    return Row(
      children: [
        const Spacer(),
        TextButton(
          onPressed: _completeOnboarding,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            'Saltar →',
            style: GoogleFonts.plusJakartaSans(
              color: SRColors.ink2,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SRColors.bg,
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (_) {},
          children: [
            _buildSlideA(),
            _buildSlideB(),
            _buildSlideC(),
            _buildPermissionsPage(),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────
  //  Page 0 — SlideA: "Decidí qué te gasta el día"
  // ─────────────────────────────────────────────────
  Widget _buildSlideA() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSkipRow(),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App icons composition
                  Center(child: _buildSlideAHero()),
                  const SizedBox(height: 28),
                  // Display title
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Decidí qué te\n',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            height: 1.1,
                            color: SRColors.ink,
                          ),
                        ),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.baseline,
                          baseline: TextBaseline.alphabetic,
                          child: ShaderMask(
                            blendMode: BlendMode.srcIn,
                            shaderCallback: (bounds) =>
                                const LinearGradient(
                              colors: [SRColors.primary, SRColors.secondary],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ).createShader(Rect.fromLTWH(
                                0, 0, bounds.width, bounds.height)),
                            child: Text(
                              'gasta el día',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.6,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ),
                        TextSpan(
                          text: '.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            height: 1.1,
                            color: SRColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 270),
                    child: Text(
                      'Elegís las apps que querés bloquear. No te limitamos: vos elegís qué silenciar.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: SRColors.ink2,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SRDots(active: 0, total: 3),
          const SizedBox(height: 12),
          SRBtn(
            'Siguiente',
            icon: Icons.arrow_forward_rounded,
            onPressed: () => _goToPage(1),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSlideAHero() {
    return AnimatedBuilder(
      animation: _floatAnim,
      builder: (context, child) {
        // Each icon gets a slightly different phase for organic float
        final t = _floatAnim.value;
        final offTop = sin(t * 2 * pi) * 6;
        final offRight = sin(t * 2 * pi + pi / 2) * 6;
        final offBottom = sin(t * 2 * pi + pi) * 6;
        final offLeft = sin(t * 2 * pi + 3 * pi / 2) * 6;

        return SizedBox(
          width: 240,
          height: 240,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // White circle background
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 44,
                      offset: const Offset(0, 18),
                      color: const Color(0x1FFF5B3A),
                    ),
                  ],
                ),
              ),
              // Top — Instagram
              Positioned(
                top: 10 + offTop,
                child: _buildAppIcon(
                  label: 'IG',
                  gradient: const [Color(0xFFE1306C), Color(0xFF833AB4)],
                ),
              ),
              // Right — TikTok
              Positioned(
                right: 10,
                top: 90 + offRight,
                child: _buildAppIcon(
                  label: 'TT',
                  color: Colors.black,
                ),
              ),
              // Bottom — YouTube
              Positioned(
                bottom: 10 + (-offBottom),
                child: _buildAppIcon(
                  label: 'YT',
                  color: const Color(0xFFFF0000),
                ),
              ),
              // Left — X/Twitter
              Positioned(
                left: 10,
                top: 90 + offLeft,
                child: _buildAppIcon(
                  label: 'X',
                  color: const Color(0xFF1DA1F2),
                ),
              ),
              // Center shield
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [SRColors.primary, SRColors.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 30,
                      offset: const Offset(0, 14),
                      color: SRColors.primary.withValues(alpha: 0.4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAppIcon({
    required String label,
    Color? color,
    List<Color>? gradient,
  }) {
    return Stack(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: gradient == null ? color : null,
            gradient: gradient != null
                ? LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ),
        // Diagonal slash overlay
        Positioned.fill(
          child: CustomPaint(
            painter: _SlashPainter(),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────
  //  Page 1 — SlideB: "No lo hacés solo."
  // ─────────────────────────────────────────────────
  Widget _buildSlideB() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSkipRow(),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: _buildSlideBHero()),
                  const SizedBox(height: 30),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'No lo hacés solo.\n',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            height: 1.1,
                            color: SRColors.ink,
                          ),
                        ),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.baseline,
                          baseline: TextBaseline.alphabetic,
                          child: ShaderMask(
                            blendMode: BlendMode.srcIn,
                            shaderCallback: (bounds) =>
                                const LinearGradient(
                              colors: [SRColors.primary, SRColors.secondary],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ).createShader(Rect.fromLTWH(
                                0, 0, bounds.width, bounds.height)),
                            child: Text(
                              'Pedile a alguien',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.6,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ),
                        TextSpan(
                          text: ' que te ancle.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            height: 1.1,
                            color: SRColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 270),
                    child: Text(
                      'Una persona de confianza. Le avisamos por WhatsApp y solo ella puede liberarte.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: SRColors.ink2,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SRDots(active: 1, total: 3),
          const SizedBox(height: 12),
          SRBtn(
            'Siguiente',
            icon: Icons.arrow_forward_rounded,
            onPressed: () => _goToPage(2),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSlideBHero() {
    return SizedBox(
      width: 280,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Dashed curve connection
          Positioned.fill(
            child: CustomPaint(
              painter: _DashedCurvePainter(),
            ),
          ),
          // Left avatar — user "ER"
          Positioned(
            left: 16,
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: SRColors.ink,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Center(
                    child: Text(
                      'ER',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'VOS',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: SRColors.ink,
                  ),
                ),
              ],
            ),
          ),
          // Right avatar — anchor "CB" with pulse
          Positioned(
            right: 16,
            child: Column(
              children: [
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnim.value,
                      child: child,
                    );
                  },
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [SRColors.primary, SRColors.accent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Center(
                      child: Text(
                        'CB',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'TU ANCLA',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: SRColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────
  //  Page 2 — SlideC: "Sin tu ancla, no abre nadie."
  // ─────────────────────────────────────────────────
  Widget _buildSlideC() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSkipRow(),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: _buildSlideCHero()),
                  const SizedBox(height: 26),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Sin tu ancla,\n',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            height: 1.1,
                            color: SRColors.ink,
                          ),
                        ),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.baseline,
                          baseline: TextBaseline.alphabetic,
                          child: ShaderMask(
                            blendMode: BlendMode.srcIn,
                            shaderCallback: (bounds) =>
                                const LinearGradient(
                              colors: [SRColors.primary, SRColors.secondary],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ).createShader(Rect.fromLTWH(
                                0, 0, bounds.width, bounds.height)),
                            child: Text(
                              'no abre nadie',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.6,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ),
                        TextSpan(
                          text: '.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            height: 1.1,
                            color: SRColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 270),
                    child: Text(
                      'Ni vos. Ni desinstalando. Ni reiniciando el celu. Esa es la idea.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: SRColors.ink2,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildChecklistCards(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SRDots(active: 2, total: 3),
          const SizedBox(height: 12),
          SRBtn(
            'Empezar a bloquear',
            onPressed: () => _goToPage(3),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSlideCHero() {
    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (context, _) {
        return Stack(
          alignment: Alignment.topRight,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [SRColors.primary, SRColors.accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    blurRadius: _glowAnim.value,
                    spreadRadius: _glowAnim.value / 3,
                    color: SRColors.primary.withValues(alpha: 0.35),
                  ),
                ],
              ),
              child: const Icon(
                Icons.lock_rounded,
                size: 56,
                color: Colors.white,
              ),
            ),
            // "×" badge
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: SRColors.line, width: 1.5),
              ),
              child: Center(
                child: Text(
                  '×',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: SRColors.ink2,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildChecklistCards() {
    final items = [
      'Podés pedir desbloqueo cuando quieras',
      'Tu ancla aprueba o niega',
      'Mientras esperás, te ofrecemos otra cosa',
    ];

    return AnimatedBuilder(
      animation: _staggerController,
      builder: (context, _) {
        return Column(
          children: items.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            final start = i * 0.2;
            final end = start + 0.6;
            final progress = _staggerController.value < start
                ? 0.0
                : _staggerController.value > end
                    ? 1.0
                    : (_staggerController.value - start) / (end - start);

            return Padding(
              padding: EdgeInsets.only(bottom: i < items.length - 1 ? 8 : 0),
              child: Opacity(
                opacity: progress,
                child: Transform.translate(
                  offset: Offset(0, 12 * (1 - progress)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: SRColors.line),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: SRColors.success,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '✓',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: SRColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────
  //  Page 3 — Permissions
  // ─────────────────────────────────────────────────
  Widget _buildPermissionsPage() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Activá los\npermisos',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              height: 1.1,
              color: SRColors.ink,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Para que el bloqueo funcione de verdad, necesitamos dos permisos del sistema.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: SRColors.ink2,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          _buildPermissionCard(
            icon: Icons.accessibility_new_rounded,
            iconColor: SRColors.primary,
            title: 'Servicio de accesibilidad',
            subtitle: 'Detecta cuándo abrís una app bloqueada',
            enabled: _accessibilityEnabled,
            onActivate: () async {
              await _accessibilityStatus.openSettings();
              await Future.delayed(const Duration(seconds: 2));
              await _checkPermissions();
            },
          ),
          const SizedBox(height: 12),
          _buildPermissionCard(
            icon: Icons.bar_chart_rounded,
            iconColor: const Color(0xFF5B6CF0),
            title: 'Acceso al uso de apps',
            subtitle: 'Detecta qué app está en primer plano',
            enabled: _usageAccessEnabled,
            onActivate: () async {
              await _usageAccessService.requestPermission();
              await Future.delayed(const Duration(seconds: 2));
              await _checkPermissions();
            },
          ),
          const Spacer(),
          if (_checkingPermissions)
            const Center(
              child: CircularProgressIndicator(color: SRColors.primary),
            )
          else
            SRBtn(
              'Listo, empezar',
              onPressed: _completeOnboarding,
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool enabled,
    required VoidCallback onActivate,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SRColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: SRColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: SRColors.ink2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          enabled
              ? Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: SRColors.success,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 16),
                )
              : GestureDetector(
                  onTap: onActivate,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: SRColors.primary,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      'Activar',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────
//  CustomPainter: diagonal slash on app icons
// ─────────────────────────────────────────────────
class _SlashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = SRColors.primary
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.15, size.height * 0.85),
      Offset(size.width * 0.85, size.height * 0.15),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────
//  CustomPainter: dashed Q-curve between avatars
// ─────────────────────────────────────────────────
class _DashedCurvePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    // From center of left avatar to center of right avatar, quadratic curve upward
    const leftX = 52.0; // 16 (padding) + 36 (half 72)
    final leftY = size.height / 2 - 15;
    final rightX = size.width - 52.0;
    final rightY = size.height / 2 - 15;
    final ctrlX = size.width / 2;
    const ctrlY = 10.0;

    path.moveTo(leftX, leftY);
    path.quadraticBezierTo(ctrlX, ctrlY, rightX, rightY);

    // Draw dashed path
    final dashedPaint = Paint()
      ..color = SRColors.primary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    _drawDashedPath(canvas, path, dashedPaint, dashLength: 6, gapLength: 5);

    // Heart circle at center of curve
    final heartCenter = Offset(size.width / 2, _getQuadPoint(leftY, ctrlY, rightY, 0.5));
    final heartPaint = Paint()..color = SRColors.primary;
    canvas.drawCircle(heartCenter, 14, heartPaint);

    final textPainter = TextPainter(
      text: const TextSpan(
        text: '♥',
        style: TextStyle(fontSize: 14, color: Colors.white),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(heartCenter.dx - textPainter.width / 2,
          heartCenter.dy - textPainter.height / 2),
    );
  }

  double _getQuadPoint(double p0, double p1, double p2, double t) {
    return (1 - t) * (1 - t) * p0 + 2 * (1 - t) * t * p1 + t * t * p2;
  }

  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint, {
    required double dashLength,
    required double gapLength,
  }) {
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0.0;
      bool draw = true;
      while (distance < metric.length) {
        final length = draw ? dashLength : gapLength;
        if (draw) {
          canvas.drawPath(
            metric.extractPath(distance, distance + length),
            paint,
          );
        }
        distance += length;
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
