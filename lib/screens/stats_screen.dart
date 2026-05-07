import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_block.dart';
import '../theme/app_theme.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  List<AppBlock> _allBlocks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBlocks();
  }

  Future<void> _loadBlocks() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('activeBlocks') ?? [];
    final blocks = saved
        .map((item) => AppBlock.fromMap(jsonDecode(item) as Map<String, dynamic>))
        .toList();
    blocks.sort((a, b) => b.startDate.compareTo(a.startDate));
    if (!mounted) return;
    setState(() {
      _allBlocks = blocks;
      _loading = false;
    });
  }

  // ── Datos derivados ───────────────────────────────

  DateTime get _now => DateTime.now();

  List<AppBlock> get _activeBlocks =>
      _allBlocks.where((b) => b.endDate.isAfter(_now)).toList();

  List<AppBlock> get _completedBlocks =>
      _allBlocks.where((b) => !b.endDate.isAfter(_now)).toList();

  int get _totalDaysSaved {
    return _allBlocks.fold(0, (sum, b) {
      final duration = b.endDate.difference(b.startDate);
      return sum + duration.inDays.clamp(0, 9999);
    });
  }

  String? get _mostBlockedApp {
    if (_allBlocks.isEmpty) return null;
    final counts = <String, int>{};
    for (final b in _allBlocks) {
      final name = b.appName.isNotEmpty ? b.appName : b.packageName;
      counts[name] = (counts[name] ?? 0) + 1;
    }
    return counts.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
  }

  // ── Build ─────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estadísticas e historial'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _allBlocks.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _loadBlocks,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      _buildSummaryCards(),
                      const SizedBox(height: 20),
                      if (_activeBlocks.isNotEmpty) ...[
                        _buildSectionTitle(
                          icon: Icons.lock_clock_rounded,
                          label: 'Bloqueo activo',
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 10),
                        ..._activeBlocks.map(_buildBlockCard),
                        const SizedBox(height: 20),
                      ],
                      if (_completedBlocks.isNotEmpty) ...[
                        _buildSectionTitle(
                          icon: Icons.history_rounded,
                          label: 'Historial de bloqueos',
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 10),
                        ..._completedBlocks.map(_buildBlockCard),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bar_chart_rounded,
              size: 72,
              color: AppColors.textMuted.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 20),
            const Text(
              'Todavía no hay datos',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Cuando actives tu primer bloqueo, acá vas a ver tu progreso y el historial.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    final completed = _completedBlocks.length;
    final active = _activeBlocks.length;
    final topApp = _mostBlockedApp;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.calendar_today_rounded,
                label: 'Días en modo bloqueo',
                value: '$_totalDaysSaved',
                accent: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.check_circle_outline_rounded,
                label: 'Bloqueos completados',
                value: '$completed',
                accent: AppColors.primaryLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.lock_rounded,
                label: 'Bloqueos activos',
                value: '$active',
                accent: active > 0 ? AppColors.orange : AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.smartphone_rounded,
                label: 'App más bloqueada',
                value: topApp ?? '—',
                isText: true,
                accent: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color accent,
    bool isText = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: accent),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: isText ? 16 : 28,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildBlockCard(AppBlock block) {
    final now = DateTime.now();
    final isActive = block.endDate.isAfter(now);
    final duration = block.endDate.difference(block.startDate);
    final durationLabel = _durationLabel(duration);
    final appName = block.appName.isNotEmpty ? block.appName : block.packageName;

    String statusLabel;
    Color statusColor;
    IconData statusIcon;

    if (isActive) {
      final remaining = block.endDate.difference(now);
      statusLabel = 'Activo · ${_durationLabel(remaining)} restantes';
      statusColor = AppColors.primary;
      statusIcon = Icons.lock_clock_rounded;
    } else {
      statusLabel = 'Completado';
      statusColor = AppColors.textMuted;
      statusIcon = Icons.check_circle_outline_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.25)
              : AppColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              statusIcon,
              size: 20,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded,
                        size: 13, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      'Duración: $durationLabel',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textMuted),
                    ),
                    if (block.friendName.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      const Icon(Icons.person_outline_rounded,
                          size: 13, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          block.friendName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textMuted),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Inicio: ${_formatDate(block.startDate)}',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSubtle),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _durationLabel(Duration d) {
    if (d.inDays >= 1) {
      final days = d.inDays;
      final hours = d.inHours % 24;
      return hours > 0 ? '${days}d ${hours}h' : '${days}d';
    }
    if (d.inHours >= 1) return '${d.inHours}h ${d.inMinutes % 60}m';
    return '${d.inMinutes}m';
  }

  String _formatDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d/$m/${dt.year}';
  }
}
