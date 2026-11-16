import 'package:flutter/material.dart';
import '../models/rpg_models.dart';

/// Опциональный режим «Кибер-Камера (Workout HUD)»:
/// Интерактивный счетчик отжиманий/приседаний с неоновым игровым оверлеем поверх экрана
/// (+XP за каждый повтор) и режимом фото-снапа результата без принуждения.
class CyberCameraHudSheet extends StatefulWidget {
  final int streakDays;
  final void Function(String exerciseTitle, int reps, int xpEarned, int goldEarned)
      onWorkoutCompleted;

  const CyberCameraHudSheet({
    super.key,
    required this.streakDays,
    required this.onWorkoutCompleted,
  });

  @override
  State<CyberCameraHudSheet> createState() => _CyberCameraHudSheetState();
}

class _CyberCameraHudSheetState extends State<CyberCameraHudSheet> {
  String _selectedExercise = 'Отжимания';
  int _reps = 0;
  int _targetReps = 20;
  bool _snapshotCaptured = false;

  static const List<Map<String, dynamic>> _exercises = [
    {'name': 'Отжимания', 'target': 20, 'icon': '💪'},
    {'name': 'Приседания', 'target': 30, 'icon': '🦵'},
    {'name': 'Бёрпи (Хардкор)', 'target': 15, 'icon': '🔥'},
    {'name': 'Подтягивания', 'target': 10, 'icon': '⚡'},
  ];

  int get _currentXp {
    if (_reps == 0) return 0;
    final diff = _selectedExercise.contains('Хардкор')
        ? QuestDifficulty.hardcore
        : QuestDifficulty.normal;
    return ProgressionMath.computeXpAction(
      difficulty: diff,
      streakDays: widget.streakDays,
      actualValue: _reps.toDouble(),
      targetValue: _targetReps.toDouble(),
    );
  }

  int get _currentGold => ProgressionMath.computeGold(_currentXp);

  @override
  Widget build(BuildContext context) {
    final xpPerRep = (_currentXp / (_reps == 0 ? 1 : _reps)).round();

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      decoration: const BoxDecoration(
        color: Color(0xFF0C0E1C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Верхняя плашка HUD
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '📷 КИБЕР-КАМЕРА // WORKOUT HUD (ОПЦИОНАЛЬНО)',
                style: TextStyle(
                  color: Color(0xFF00F5D4),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white54),
              ),
            ],
          ),

          // Выбор упражнения
          Wrap(
            spacing: 8,
            children: _exercises.map((ex) {
              final name = ex['name'] as String;
              final isSelected = _selectedExercise == name;
              return ChoiceChip(
                label: Text('${ex['icon']} $name'),
                selected: isSelected,
                onSelected: (_) {
                  setState(() {
                    _selectedExercise = name;
                    _targetReps = ex['target'] as int;
                    _reps = 0;
                    _snapshotCaptured = false;
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Видоискатель камеры с неоновым HUD-оверлеем
          GestureDetector(
            onTap: () {
              setState(() {
                _reps += 1;
              });
            },
            child: Container(
              height: 240,
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF1E2246),
                    const Color(0xFF090B14),
                  ],
                  radius: 1.1,
                ),
                border: Border.all(
                  color: _snapshotCaptured
                      ? const Color(0xFFFEE440)
                      : const Color(0xFF00F5D4).withOpacity(0.7),
                  width: 2,
                ),
              ),
              child: Stack(
                children: [
                  // Угловые прицелы HUD
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Text(
                      _snapshotCaptured ? '📸 SNAPSHOT LOCKED' : '🔴 REC // AI-POSE HUD READY',
                      style: TextStyle(
                        color: _snapshotCaptured ? const Color(0xFFFEE440) : const Color(0xFFFF6B6B),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Text(
                      'ЦЕЛЬ: $_targetReps ПОВТ.',
                      style: const TextStyle(
                        color: Color(0xFF00F5D4),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // Центральный счетчик повторений
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$_reps',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 64,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                          ),
                        ),
                        Text(
                          '$_selectedExercise (тапни по экрану +1 повтор)',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00F5D4).withOpacity(0.18),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF00F5D4)),
                          ),
                          child: Text(
                            '⚡ +$_currentXp XP  •  🪙 +$_currentGold золота (~$xpPerRep XP/повтор)',
                            style: const TextStyle(
                              color: Color(0xFF00F5D4),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Нижняя строка HUD: быстрые кнопки +5 и Снап фото-пруфа
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white30),
                          ),
                          onPressed: () => setState(() => _reps += 5),
                          child: const Text('+5 повторов'),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFFEE440),
                            side: const BorderSide(color: Color(0xFFFEE440)),
                          ),
                          onPressed: () {
                            setState(() {
                              if (_reps == 0) _reps = _targetReps;
                              _snapshotCaptured = true;
                            });
                          },
                          icon: const Icon(Icons.camera_alt, size: 16),
                          label: Text(_snapshotCaptured ? 'Снап готов!' : 'Фото-снап HUD'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Кнопка фиксации тренировки и шеринга
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00F5D4),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () {
                final effectiveReps = _reps > 0 ? _reps : _targetReps;
                setState(() => _reps = effectiveReps);
                final xp = _currentXp;
                final gold = _currentGold;
                Navigator.of(context).pop();
                widget.onWorkoutCompleted(
                  'Кибер-Камера: $_selectedExercise',
                  effectiveReps,
                  xp,
                  gold,
                );
              },
              icon: const Icon(Icons.bolt),
              label: Text(
                'Зафиксировать ($_reps повт.) → Прокачать 💪 Тело и открыть 9:16 карточку',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
