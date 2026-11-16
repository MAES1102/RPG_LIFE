import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/rpg_models.dart';

enum ShareCardMode { stravaQuest, heroBossVictory }

/// Генератор карточек 9:16 для шеринга в Instagram / Telegram Stories:
/// 1) Карточка закрытого квеста / тренировки со статами (как в Strava).
/// 2) Карточка Героя и Победы над Боссом Арены (радар-чарт 4 сфер, уровень героя, боевые статы, побежденный босс и стрик).
class ShareCardSheet extends StatefulWidget {
  final ShareCardMode initialMode;
  final int heroLevel;
  final int streakDays;
  final EquippedState equipped;
  final CombatStatsModel combatStats;
  final List<SphereModel> spheres;

  // Данные для Strava-карточки квеста/тренировки
  final String? questTitle;
  final String? metricLabel;
  final int? xpEarned;
  final int? goldEarned;

  // Данные для карточки победы над Боссом Арены
  final ArenaBossModel? defeatedBoss;

  const ShareCardSheet({
    super.key,
    this.initialMode = ShareCardMode.stravaQuest,
    required this.heroLevel,
    required this.streakDays,
    required this.equipped,
    required this.combatStats,
    required this.spheres,
    this.questTitle,
    this.metricLabel,
    this.xpEarned,
    this.goldEarned,
    this.defeatedBoss,
  });

  @override
  State<ShareCardSheet> createState() => _ShareCardSheetState();
}

class _ShareCardSheetState extends State<ShareCardSheet> {
  late ShareCardMode _mode;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      decoration: const BoxDecoration(
        color: Color(0xFF0E1020),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '📲 STORIES 9:16 // КАРТОЧКА ШЕРИНГА',
                  style: TextStyle(
                    color: Color(0xFF00F5D4),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 1.1,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white54),
                ),
              ],
            ),
            // Переключатель 2 форматов 9:16 карточек
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('⚡ Strava-Квест 9:16'),
                  selected: _mode == ShareCardMode.stravaQuest,
                  onSelected: (_) => setState(() => _mode = ShareCardMode.stravaQuest),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('🏆 Герой & Босс (Радар 4 сфер)'),
                  selected: _mode == ShareCardMode.heroBossVictory,
                  onSelected: (_) => setState(() => _mode = ShareCardMode.heroBossVictory),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Холст карточки строго в пропорции 9:16 для Stories
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 315),
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF0B0D1D),
                          Color(0xFF1A1438),
                          Color(0xFF092334),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: const Color(0xFF00F5D4).withOpacity(0.65),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00F5D4).withOpacity(0.22),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: _mode == ShareCardMode.stravaQuest
                        ? _buildStravaQuestCard()
                        : _buildHeroBossRadarCard(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00F5D4),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: Color(0xFF1F2238),
                      content: Text(
                        '📸 Карточка 9:16 готова к публикации в Instagram / Telegram Stories!',
                        style: TextStyle(color: Color(0xFF00F5D4), fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.ios_share),
                label: const Text(
                  'Поделиться в Instagram / Telegram Stories',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Вариант 1: Карточка закрытого квеста / тренировки со статами (в стиле Strava)
  Widget _buildStravaQuestCard() {
    final title = widget.questTitle ?? 'Кибер-атлетика: Пробежка 3.45 км';
    final metric = widget.metricLabel ?? '3.45 КМ • ТЕМП 4:50 /КМ';
    final xp = widget.xpEarned ?? 198;
    final gold = widget.goldEarned ?? 39;
    final streakBonus = (widget.streakDays * 5).clamp(0, 50);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Верхний штамп терминала
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF00F5D4).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF00F5D4)),
              ),
              child: const Text(
                'RPG_LIFE // STRAVA HUD',
                style: TextStyle(
                  color: Color(0xFF00F5D4),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              '🔥 СТРИК ${widget.streakDays} ДН.',
              style: const TextStyle(
                color: Color(0xFFFF6B6B),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),

        // Центральный блок результата тренировки / квеста
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'КВЕСТ ВЫПОЛНЕН В РЕАЛЬНОСТИ',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF9B5DE5).withOpacity(0.6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ЗАФИКСИРОВАННЫЙ РЕЗУЛЬТАТ',
                    style: TextStyle(color: Colors.white60, fontSize: 10),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    metric,
                    style: const TextStyle(
                      color: Color(0xFFFEE440),
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _statPill('⚡ ОПЫТ', '+$xp XP', const Color(0xFF00F5D4)),
                      _statPill('🪙 ЗОЛОТО', '+$gold', const Color(0xFFFEE440)),
                      _statPill('🔥 МНОЖИТЕЛЬ', '+$streakBonus%', const Color(0xFFFF6B6B)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),

        // Блок трансформации реального действия в боевые статы героя
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'АПГРЕЙД БОЕВОГО АВАТАРА (УР. ${widget.heroLevel})',
                style: const TextStyle(
                  color: Color(0xFF00F5D4),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '❤️ HP: ${widget.combatStats.maxHp}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  Text(
                    '⚔️ ATK: ${widget.combatStats.attackPower}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  Text(
                    '🧠 Slow: ${widget.combatStats.chronoSlowPercent}%',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '⚡ Боевая мощь в Нейро-Арене: ${widget.combatStats.combatPowerScore} PTS',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Вариант 2: Карточка Героя и Победы над Боссом Арены с Радар-чартом 4 сфер
  Widget _buildHeroBossRadarCard() {
    final boss = widget.defeatedBoss ?? ArenaBossModel.defaultTowerBosses().first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Заголовок Героя и Босса
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ГЕРОЙ УР. ${widget.heroLevel}',
              style: const TextStyle(
                color: Color(0xFF00F5D4),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            Text(
              '🔥 Стрик ${widget.streakDays} дн.',
              style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 12),
            ),
          ],
        ),

        // Бейдж поверженного Босса Арены
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF9B5DE5).withOpacity(0.18),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF9B5DE5)),
          ),
          child: Row(
            children: [
              Text(boss.icon, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🏆 БОСС БАШНИ ПОВЕРЖЕН',
                      style: TextStyle(
                        color: Color(0xFFFEE440),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      boss.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'Трофей: ${boss.trophyName}',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Радар-чарт 4 сфер реальной жизни (Мозг, Тело, Энергия, Душа)
        SizedBox(
          height: 155,
          width: double.infinity,
          child: CustomPaint(
            painter: _SphereRadarChartPainter(spheres: widget.spheres),
          ),
        ),

        // Сетка боевых статов от реальной жизни
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black45,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statPill(
                    '💪 HP+Щит',
                    '${widget.combatStats.maxHp + widget.combatStats.petAssistShield}',
                    const Color(0xFF00F5D4),
                  ),
                  _statPill(
                    '⚔️ Урон',
                    '${widget.combatStats.attackPower}',
                    const Color(0xFFFF6B6B),
                  ),
                  _statPill(
                    '🧠 Хроно',
                    '-${widget.combatStats.chronoSlowPercent}%',
                    const Color(0xFF9B5DE5),
                  ),
                  _statPill(
                    '🎨 Крит',
                    '${(widget.combatStats.critChance * 100).toStringAsFixed(0)}%',
                    const Color(0xFFFEE440),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'БОЕВАЯ МОЩЬ АВАТАРА: ${widget.combatStats.combatPowerScore} PTS',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statPill(String label, String value, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }
}

/// Кастомный Radar Chart для 4 сфер игрока (🧠 Мозг, 💪 Тело, ⚡ Энергия, 🎨 Душа).
class _SphereRadarChartPainter extends CustomPainter {
  final List<SphereModel> spheres;

  _SphereRadarChartPainter({required this.spheres});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.34;

    final gridPaint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Рисуем 3 концентрических ромба сетки
    for (int ring = 1; ring <= 3; ring++) {
      final r = radius * (ring / 3.0);
      final path = Path()
        ..moveTo(center.dx, center.dy - r)
        ..lineTo(center.dx + r, center.dy)
        ..lineTo(center.dx, center.dy + r)
        ..lineTo(center.dx - r, center.dy)
        ..close();
      canvas.drawPath(path, gridPaint);
    }

    // Оси
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      gridPaint,
    );
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      gridPaint,
    );

    // Значения 4 сфер (нормируем уровень от 1 до 6+)
    final angles = [-math.pi / 2, 0.0, math.pi / 2, math.pi];
    final polyPath = Path();

    for (int i = 0; i < 4; i++) {
      final sp = i < spheres.length
          ? spheres[i]
          : SphereModel(id: '$i', code: 'brain', name: 'Сфера', icon: '⚡');
      final normalized = ((sp.level + sp.progress) / 6.0).clamp(0.22, 1.0);
      final pt = Offset(
        center.dx + math.cos(angles[i]) * radius * normalized,
        center.dy + math.sin(angles[i]) * radius * normalized,
      );
      if (i == 0) {
        polyPath.moveTo(pt.dx, pt.dy);
      } else {
        polyPath.lineTo(pt.dx, pt.dy);
      }
    }
    polyPath.close();

    final fillPaint = Paint()
      ..color = const Color(0xFF00F5D4).withOpacity(0.28)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = const Color(0xFF00F5D4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    canvas.drawPath(polyPath, fillPaint);
    canvas.drawPath(polyPath, strokePaint);

    // Подписи 4 вершин
    for (int i = 0; i < 4 && i < spheres.length; i++) {
      final sp = spheres[i];
      final labelOffset = Offset(
        center.dx + math.cos(angles[i]) * (radius + 22),
        center.dy + math.sin(angles[i]) * (radius + 16),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: '${sp.icon} ${sp.name} Ур.${sp.level}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(labelOffset.dx - tp.width / 2, labelOffset.dy - tp.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SphereRadarChartPainter oldDelegate) => true;
}
