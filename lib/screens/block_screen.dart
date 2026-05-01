import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BlockScreen extends StatelessWidget {
  final String appName;
  final String packageName;
  final String friendName;
  final DateTime endDate;
  final List<String> replacementCategories;

  const BlockScreen({
    super.key,
    required this.appName,
    required this.packageName,
    required this.friendName,
    required this.endDate,
    this.replacementCategories = const [],
  });

  String get _formattedDate {
    final day = endDate.day.toString().padLeft(2, '0');
    final month = endDate.month.toString().padLeft(2, '0');
    final year = endDate.year;
    return '$day/$month/$year';
  }

  String _remainingLabel() {
    final now = DateTime.now();
    final diff = endDate.difference(now);
    if (diff.isNegative) return '';
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    if (days > 0) return '$days d ${hours}h restantes';
    final minutes = diff.inMinutes % 60;
    if (hours > 0) return '${hours}h ${minutes}m restantes';
    return '${diff.inMinutes}m restantes';
  }

  static const Map<String, List<_Replacement>> _replacementsByCategory = {
    'reading_learning': [
      _Replacement(icon: Icons.chrome_reader_mode_rounded, text: 'Lee 10 minutos de un libro o artículo'),
      _Replacement(icon: Icons.school_rounded, text: 'Avanzá una lección de tu curso guardado'),
      _Replacement(icon: Icons.translate_rounded, text: 'Practicá vocabulario en otro idioma'),
    ],
    'wellbeing_training': [
      _Replacement(icon: Icons.air_rounded, text: 'Hacé 3 min de respiración profunda'),
      _Replacement(icon: Icons.directions_walk_rounded, text: 'Salí a caminar 15 minutos'),
      _Replacement(icon: Icons.fitness_center_rounded, text: 'Completá una mini rutina de ejercicio'),
    ],
    'music_creativity': [
      _Replacement(icon: Icons.queue_music_rounded, text: 'Escuchá una playlist instrumental'),
      _Replacement(icon: Icons.edit_note_rounded, text: 'Anotá ideas o escribí 10 minutos'),
      _Replacement(icon: Icons.brush_rounded, text: 'Dibujá un boceto libre'),
    ],
    'focus_games': [
      _Replacement(icon: Icons.psychology_alt_rounded, text: 'Jugá un juego mental o de lógica'),
      _Replacement(icon: Icons.extension_rounded, text: 'Resolvé un puzzle o crucigrama'),
    ],
  };

  static const List<_Replacement> _defaultReplacements = [
    _Replacement(icon: Icons.menu_book_rounded, text: 'Leé algo interesante'),
    _Replacement(icon: Icons.fitness_center_rounded, text: 'Hacé ejercicio o estirá'),
    _Replacement(icon: Icons.air_rounded, text: 'Meditá unos minutos'),
    _Replacement(icon: Icons.edit_note_rounded, text: 'Escribí algo que tengas en mente'),
  ];

  List<_Replacement> get _suggestions {
    if (replacementCategories.isEmpty) return _defaultReplacements;
    final result = <_Replacement>[];
    for (final cat in replacementCategories) {
      final items = _replacementsByCategory[cat];
      if (items != null) result.addAll(items.take(2));
    }
    return result.isEmpty ? _defaultReplacements : result.take(4).toList();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _remainingLabel();
    final suggestions = _suggestions;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Momento de pausa'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Ícono + título
            Icon(
              Icons.self_improvement_rounded,
              size: 72,
              color: AppColors.orange,
            ),
            const SizedBox(height: 16),
            Text(
              'Pusiste $appName en pausa',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Estás eligiendo hacer algo mejor con este tiempo.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 20),

            // Card de tiempo restante
            Card(
              elevation: 0,
              color: AppColors.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppColors.orange.withValues(alpha: 0.30)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.schedule_rounded,
                            size: 18,
                            color: AppColors.orange),
                        const SizedBox(width: 6),
                        Text(
                          'Activo hasta el $_formattedDate',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    if (remaining.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        remaining,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.person_rounded,
                            size: 16,
                            color: AppColors.textMuted),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Aprobación a cargo de: $friendName',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Sugerencias de reemplazos
            Card(
              elevation: 0,
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.25)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lightbulb_rounded,
                            size: 18,
                            color: AppColors.primary),
                        SizedBox(width: 8),
                        Text(
                          'Aprovechá este momento',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryLight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...suggestions.map(
                      (s) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Icon(s.icon,
                                size: 20,
                                color: AppColors.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                s.text,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Volver', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Replacement {
  final IconData icon;
  final String text;

  const _Replacement({required this.icon, required this.text});
}
