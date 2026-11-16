import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../models/rpg_models.dart';
import '../widgets/share_card_sheet.dart';

class _Bullet {
  Offset pos;
  Offset vel;
  double radius;
  Color color;
  bool fromPlayer;

  _Bullet({
    required this.pos,
    required this.vel,
    required this.radius,
    required this.color,
    required this.fromPlayer,
  });
}

/// Экран «Нейро-Арена / Башня Боссов» (60 FPS через Ticker + CustomPainter).
/// Реализует 2 хардкорных режима мини-игр, где решают боевые статы от реальной жизни:
/// 1) «Прорыв Фаервола (Bullet-Hell Boss Fight)»
/// 2) «Кибер-Дуэль (Reflex Parry Strike)»
class NeuroArenaScreen extends StatefulWidget {
  final int heroLevel;
  final int streakDays;
  final EquippedState equipped;
  final CombatStatsModel combatStats;
  final List<SphereModel> spheres;
  final List<ArenaBossModel> bosses;
  final Future<void> Function(ArenaBossModel boss, double remainingHpPercent) onVictoryClaimed;

  const NeuroArenaScreen({
    super.key,
    required this.heroLevel,
    required this.streakDays,
    required this.equipped,
    required this.combatStats,
    required this.spheres,
    required this.bosses,
    required this.onVictoryClaimed,
  });

  @override
  State<NeuroArenaScreen> createState() => _NeuroArenaScreenState();
}

class _NeuroArenaScreenState extends State<NeuroArenaScreen>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  Duration _lastTick = Duration.zero;
  final math.Random _rng = math.Random();

  late ArenaBossModel _selectedBoss;
  late MinigameMode _activeMode;

  bool _inCombat = false;
  bool _victory = false;
  bool _defeat = false;
  String _combatLogText = 'Готов к бою. Проверь свои статы от реальной жизни!';

  // Боевые показатели текущей сессии
  double _playerHp = 135;
  double _playerMaxHp = 135;
  double _petShield = 15;
  double _bossHp = 420;
  double _bossMaxHp = 420;

  // Способности: Нейро-Замедление (Sandevistan от Мозга) и Рывок (Dash от Энергии)
  double _sandevistanRemainingSec = 0.0;
  double _sandevistanCooldownSec = 0.0;
  double _dashInvulnRemainingSec = 0.0;
  double _dashCooldownRemainingSec = 0.0;

  // Состояние режима 1: Bullet-Hell
  Offset _playerPos = const Offset(0.5, 0.82); // нормированные координаты 0..1
  double _bossX = 0.5;
  double _bossTime = 0.0;
  double _playerFireAccum = 0.0;
  double _bossFireAccum = 0.0;
  final List<_Bullet> _bullets = [];

  // Состояние режима 2: Кибер-Дуэль (Reflex Parry Strike)
  double _parryCursor = 0.1; // 0..1
  double _parryDir = 1.0;
  double _targetZoneCenter = 0.5;

  @override
  void initState() {
    super.initState();
    _selectedBoss = widget.bosses.first;
    _activeMode = _selectedBoss.minigameMode;
    _resetCombatEntities();
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _resetCombatEntities() {
    final cs = widget.combatStats;
    _playerMaxHp = cs.maxHp.toDouble();
    _playerHp = _playerMaxHp;
    _petShield = cs.petAssistShield.toDouble();
    _bossMaxHp = _selectedBoss.bossHp.toDouble();
    _bossHp = _bossMaxHp;

    _sandevistanRemainingSec = 0;
    _sandevistanCooldownSec = 0;
    _dashInvulnRemainingSec = 0;
    _dashCooldownRemainingSec = 0;

    _playerPos = const Offset(0.5, 0.82);
    _bossX = 0.5;
    _bossTime = 0;
    _bullets.clear();

    _parryCursor = 0.1;
    _parryDir = 1.0;
    _targetZoneCenter = 0.5;
  }

  void _startBattle() {
    setState(() {
      _resetCombatEntities();
      _inCombat = true;
      _victory = false;
      _defeat = false;
      _combatLogText = _activeMode == MinigameMode.bulletHell
          ? 'Двигай пальцем по арене для уворота! Используй Sandevistan (🧠 Мозг) и Рывок (⚡ Энергия).'
          : 'Жми «ПАРИРОВАТЬ / УДАР», когда курсор в зеленой или золотой зоне!';
      _lastTick = Duration.zero;
    });
    if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  void _stopBattle() {
    if (_ticker.isActive) {
      _ticker.stop();
    }
    setState(() {
      _inCombat = false;
    });
  }

  void _activateSandevistan() {
    if (!_inCombat || _sandevistanCooldownSec > 0) return;
    setState(() {
      // Длительность зависит от уровня Мозга (база 3.5с + бонус от процента замедления)
      _sandevistanRemainingSec = 3.2 + (widget.combatStats.chronoSlowPercent / 25.0);
      _sandevistanCooldownSec = 8.0;
      _combatLogText =
          '🧠 SANDEVISTAN АКТИВИРОВАН! Время замедлено на ${widget.combatStats.chronoSlowPercent}%!';
    });
  }

  void _activateDash() {
    if (!_inCombat || _dashCooldownRemainingSec > 0) return;
    setState(() {
      _dashInvulnRemainingSec = 0.65;
      _dashCooldownRemainingSec = widget.combatStats.dashCooldownSec;
      // Быстрый смещающий рывок в сторону от центра
      final newX = _playerPos.dx < 0.5 ? (_playerPos.dx + 0.24).clamp(0.1, 0.9) : (_playerPos.dx - 0.24).clamp(0.1, 0.9);
      _playerPos = Offset(newX, _playerPos.dy);
      _combatLogText = '⚡ РЫВОК! Неуязвимость 0.65с (КД: ${widget.combatStats.dashCooldownSec}с)';
    });
  }

  void _onTick(Duration elapsed) {
    if (!_inCombat) return;
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }
    final rawDt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    final dt = rawDt.clamp(0.0, 0.05);

    // Обновление таймеров способностей
    if (_sandevistanRemainingSec > 0) {
      _sandevistanRemainingSec = math.max(0, _sandevistanRemainingSec - dt);
    }
    if (_sandevistanCooldownSec > 0) {
      _sandevistanCooldownSec = math.max(0, _sandevistanCooldownSec - dt);
    }
    if (_dashInvulnRemainingSec > 0) {
      _dashInvulnRemainingSec = math.max(0, _dashInvulnRemainingSec - dt);
    }
    if (_dashCooldownRemainingSec > 0) {
      _dashCooldownRemainingSec = math.max(0, _dashCooldownRemainingSec - dt);
    }

    // Коэффициент скорости времени врага с учетом Нейро-Замедления (🧠 Мозг: 10%..50%)
    final slowFactor = _sandevistanRemainingSec > 0
        ? (1.0 - widget.combatStats.chronoSlowPercent / 100.0)
        : 1.0;
    final enemyDt = dt * slowFactor;

    if (_activeMode == MinigameMode.bulletHell) {
      _updateBulletHell(dt, enemyDt);
    } else {
      _updateReflexParry(enemyDt);
    }

    // Проверка победы / поражения
    if (_bossHp <= 0 && !_victory) {
      _bossHp = 0;
      _victory = true;
      _inCombat = false;
      _ticker.stop();
      final remHpPct = ((_playerHp / _playerMaxHp) * 100.0).clamp(1.0, 100.0);
      widget.onVictoryClaimed(_selectedBoss, remHpPct);
      _combatLogText =
          '🏆 ПОБЕДА НАД БОССОМ! Награда: +${_selectedBoss.rewardXp} XP, +${_selectedBoss.rewardGold} 🪙';
    } else if (_playerHp <= 0 && !_defeat) {
      _playerHp = 0;
      _defeat = true;
      _inCombat = false;
      _ticker.stop();
      _combatLogText =
          '💥 ФАЕРВОЛ ПРОБИТ! Закрой пару реальных квестов (прокачай 💪 Тело и 🧠 Мозг) и возьми реванш!';
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _updateBulletHell(double playerDt, double enemyDt) {
    _bossTime += enemyDt;
    _bossX = 0.5 + 0.32 * math.sin(_bossTime * 1.6);

    // Авто-атака игрока по боссу
    _playerFireAccum += playerDt;
    if (_playerFireAccum >= 0.28) {
      _playerFireAccum = 0;
      _bullets.add(
        _Bullet(
          pos: Offset(_playerPos.dx, _playerPos.dy - 0.04),
          vel: const Offset(0, -1.15),
          radius: 0.016,
          color: const Color(0xFF00F5D4),
          fromPlayer: true,
        ),
      );
    }

    // Стрельба босса: плотные веерные и спиральные паттерны (сложность зависит от этажа)
    _bossFireAccum += enemyDt * _selectedBoss.bulletDensity;
    if (_bossFireAccum >= 0.42) {
      _bossFireAccum = 0;
      final count = (3 + _selectedBoss.floor).clamp(4, 8);
      final baseAngle = math.pi / 2 + 0.35 * math.sin(_bossTime * 2.3);
      const spread = 1.15;

      for (int i = 0; i < count; i++) {
        final frac = count == 1 ? 0.0 : (i / (count - 1)) - 0.5;
        final angle = baseAngle + frac * spread;
        final speed = 0.48 + 0.06 * _selectedBoss.floor;
        _bullets.add(
          _Bullet(
            pos: Offset(_bossX, 0.14),
            vel: Offset(math.cos(angle) * speed, math.sin(angle) * speed),
            radius: 0.018,
            color: const Color(0xFFFF2A85),
            fromPlayer: false,
          ),
        );
      }
    }

    // Движение и коллизии снарядов
    final remaining = <_Bullet>[];
    for (final b in _bullets) {
      final stepDt = b.fromPlayer ? playerDt : enemyDt;
      b.pos = Offset(b.pos.dx + b.vel.dx * stepDt, b.pos.dy + b.vel.dy * stepDt);

      if (b.pos.dx < -0.05 || b.pos.dx > 1.05 || b.pos.dy < -0.05 || b.pos.dy > 1.05) {
        continue;
      }

      if (b.fromPlayer) {
        // Проверка попадания в босса
        final dist = (b.pos - Offset(_bossX, 0.12)).distance;
        if (dist < 0.085) {
          final isCrit = _rng.nextDouble() < widget.combatStats.critChance;
          final dmg = widget.combatStats.attackPower *
              (isCrit ? widget.combatStats.critMultiplier : 1.0);
          _bossHp -= dmg;
          if (isCrit) {
            _combatLogText = '🎨 КРИТИЧЕСКИЙ ИМПУЛЬС x2.5! -${dmg.toStringAsFixed(0)} HP боссу!';
          }
          continue;
        }
      } else {
        // Проверка попадания в игрока
        final dist = (b.pos - _playerPos).distance;
        if (dist < 0.046) {
          if (_dashInvulnRemainingSec > 0) {
            // Игрок в рывке — урон игнорируется!
            continue;
          }
          _applyDamageToPlayer(_selectedBoss.bossDps * 0.45);
          continue;
        }
      }

      remaining.add(b);
    }
    _bullets
      ..clear()
      ..addAll(remaining);
  }

  void _updateReflexParry(double enemyDt) {
    // Скорость курсора растет с этажом босса, но замедляется Sandevistan'ом (🧠 Мозг)
    final speed = (0.95 + 0.28 * _selectedBoss.floor) * _parryDir;
    _parryCursor += speed * enemyDt;
    if (_parryCursor >= 0.96) {
      _parryCursor = 0.96;
      _parryDir = -1.0;
    } else if (_parryCursor <= 0.04) {
      _parryCursor = 0.04;
      _parryDir = 1.0;
    }
  }

  void _triggerParryStrike() {
    if (!_inCombat || _activeMode != MinigameMode.reflexParry) return;

    // Ширина окна тайминга напрямую зависит от parryWindowMs (🧠 Мозг)
    final halfWindow = (widget.combatStats.parryWindowMs / 1000.0).clamp(0.08, 0.24);
    final bullseyeHalf = halfWindow * 0.38;
    final diff = (_parryCursor - _targetZoneCenter).abs();

    setState(() {
      if (diff <= bullseyeHalf) {
        // Идеальное парирование (x2.5 крит + бонус)
        final dmg = widget.combatStats.attackPower * widget.combatStats.critMultiplier * 2.2;
        _bossHp -= dmg;
        _combatLogText =
            '⚡ ИДЕАЛЬНОЕ ПАРИРОВАНИЕ! Критический контрудар -${dmg.toStringAsFixed(0)} HP!';
        _targetZoneCenter = 0.22 + _rng.nextDouble() * 0.56;
      } else if (diff <= halfWindow) {
        // Успешное попадание в окно тайминга
        final isCrit = _rng.nextDouble() < widget.combatStats.critChance;
        final dmg = widget.combatStats.attackPower * (isCrit ? 2.5 : 1.35);
        _bossHp -= dmg;
        _combatLogText = '⚔️ Точный удар в тайминг! -${dmg.toStringAsFixed(0)} HP боссу.';
        _targetZoneCenter = 0.22 + _rng.nextDouble() * 0.56;
      } else {
        // Промах по таймингу — босс контратакует!
        final incoming = _selectedBoss.bossDps.toDouble();
        _applyDamageToPlayer(incoming);
        _combatLogText =
            '💥 Срыв тайминга! Контратака босса (-${incoming.toStringAsFixed(0)} урона). Прокачай 🧠 Мозг для расширения окна!';
      }
    });
  }

  void _applyDamageToPlayer(double dmg) {
    var left = dmg;
    if (_petShield > 0) {
      final absorbed = math.min(_petShield, left);
      _petShield -= absorbed;
      left -= absorbed;
    }
    if (left > 0) {
      _playerHp = math.max(0, _playerHp - left);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.combatStats;
    final powerDiff = cs.combatPowerScore - _selectedBoss.bossPowerScore;

    return Scaffold(
      backgroundColor: const Color(0xFF090A14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090A14),
        title: const Text(
          '⚔️ НЕЙРО-АРЕНА // БАШНЯ БОССОВ',
          style: TextStyle(
            color: Color(0xFF00F5D4),
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Выбор этажа / босса Башни
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: widget.bosses.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final b = widget.bosses[i];
                  final selected = b.code == _selectedBoss.code;
                  return ChoiceChip(
                    label: Text(
                      'Этаж ${b.floor}: ${b.icon} ${b.name.split(" ").first}${b.isDefeated ? " ✓" : ""}',
                    ),
                    selected: selected,
                    onSelected: _inCombat
                        ? null
                        : (_) {
                            setState(() {
                              _selectedBoss = b;
                              _activeMode = b.minigameMode;
                              _resetCombatEntities();
                            });
                          },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // Карточка сравнения: «Твои статы от реальной жизни vs Мощь Босса»
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF14172B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: powerDiff >= 0
                      ? const Color(0xFF00F5D4).withOpacity(0.5)
                      : const Color(0xFFFF6B6B).withOpacity(0.6),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '📊 ТВОИ СТАТЫ ОТ ЖИЗНИ VS МОЩЬ БОССА',
                        style: TextStyle(
                          color: Color(0xFF00F5D4),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: powerDiff >= 0
                              ? const Color(0xFF00F5D4).withOpacity(0.18)
                              : const Color(0xFFFF6B6B).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '⚡ Мощь: ${cs.combatPowerScore} vs ${_selectedBoss.bossPowerScore}',
                          style: TextStyle(
                            color: powerDiff >= 0 ? const Color(0xFF00F5D4) : const Color(0xFFFF6B6B),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_selectedBoss.icon} ${_selectedBoss.name} — ${_selectedBoss.description}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      _statLine('💪 Тело → HP/ATK:', '${cs.maxHp} HP / ${cs.attackPower} урон'),
                      _statLine('🧠 Мозг → Хроно/Тайминг:', '-${cs.chronoSlowPercent}% / ${cs.parryWindowMs}мс'),
                      _statLine('⚡ Энергия → Рывок:', 'КД ${cs.dashCooldownSec}с'),
                      _statLine(
                        '🎨 Душа → Крит/Щит:',
                        '${(cs.critChance * 100).toStringAsFixed(0)}% крит / +${cs.petAssistShield} щит',
                      ),
                    ],
                  ),
                  if (powerDiff < 0) ...[
                    const SizedBox(height: 8),
                    const Text(
                      '⚠️ Босс превосходит тебя по статам! На 1 уровне победить крайне сложно — закрывай реальные квесты (спорт, фокус-рейды), чтобы повысить сферы.',
                      style: TextStyle(color: Color(0xFFFEE440), fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Переключатель 2 режимов мини-игры
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('☄️ Режим 1: Прорыв Фаервола (Bullet-Hell)'),
                    selected: _activeMode == MinigameMode.bulletHell,
                    onSelected: _inCombat
                        ? null
                        : (_) => setState(() => _activeMode = MinigameMode.bulletHell),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('⚔️ Режим 2: Кибер-Дуэль (Reflex Parry)'),
                    selected: _activeMode == MinigameMode.reflexParry,
                    onSelected: _inCombat
                        ? null
                        : (_) => setState(() => _activeMode = MinigameMode.reflexParry),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Полоски здоровья Босса и Героя
            _buildHealthBars(),
            const SizedBox(height: 10),

            // Игровой холст 60 FPS (CustomPainter + GestureDetector)
            GestureDetector(
              onPanUpdate: (details) {
                if (!_inCombat || _activeMode != MinigameMode.bulletHell) return;
                final box = context.findRenderObject() as RenderBox?;
                if (box == null) return;
                setState(() {
                  final dx = (_playerPos.dx + details.delta.dx / 320.0).clamp(0.08, 0.92);
                  final dy = (_playerPos.dy + details.delta.dy / 320.0).clamp(0.30, 0.92);
                  _playerPos = Offset(dx, dy);
                });
              },
              onTapDown: (_) {
                if (_inCombat && _activeMode == MinigameMode.reflexParry) {
                  _triggerParryStrike();
                }
              },
              child: Container(
                height: 310,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF070812),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _sandevistanRemainingSec > 0
                        ? const Color(0xFF9B5DE5)
                        : const Color(0xFF00F5D4).withOpacity(0.55),
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: CustomPaint(
                    painter: _ArenaCanvasPainter(
                      mode: _activeMode,
                      bossIcon: _selectedBoss.icon,
                      bossX: _bossX,
                      playerPos: _playerPos,
                      bullets: _bullets,
                      sandevistanActive: _sandevistanRemainingSec > 0,
                      dashInvulnActive: _dashInvulnRemainingSec > 0,
                      petShieldActive: _petShield > 0,
                      parryCursor: _parryCursor,
                      targetZoneCenter: _targetZoneCenter,
                      parryWindowMs: cs.parryWindowMs,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Тактический лог боя
            Text(
              _combatLogText,
              style: const TextStyle(color: Color(0xFFFEE440), fontSize: 12),
            ),
            const SizedBox(height: 12),

            // Кнопки управления боем и активных способностей
            Row(
              children: [
                if (!_inCombat)
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00F5D4),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _startBattle,
                      icon: const Icon(Icons.play_arrow),
                      label: Text(
                        _victory || _defeat ? 'Сразиться снова (60 FPS)' : 'Начать Бой с Боссом',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                else ...[
                  // Кнопка Нейро-Замедления (Sandevistan от Мозга)
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9B5DE5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _sandevistanCooldownSec > 0 ? null : _activateSandevistan,
                      child: Text(
                        _sandevistanRemainingSec > 0
                            ? '🧠 Хроно: ${_sandevistanRemainingSec.toStringAsFixed(1)}с'
                            : (_sandevistanCooldownSec > 0
                                ? '🧠 КД ${_sandevistanCooldownSec.toStringAsFixed(1)}с'
                                : '🧠 Sandevistan (-${cs.chronoSlowPercent}%)'),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_activeMode == MinigameMode.bulletHell)
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00BBF9),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _dashCooldownRemainingSec > 0 ? null : _activateDash,
                        child: Text(
                          _dashCooldownRemainingSec > 0
                              ? '⚡ Рывок КД ${_dashCooldownRemainingSec.toStringAsFixed(1)}с'
                              : '⚡ Рывок (Неуязв.)',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFEE440),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _triggerParryStrike,
                        child: const Text(
                          '⚔️ ПАРИРОВАТЬ / УДАР!',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _stopBattle,
                    icon: const Icon(Icons.stop_circle_outlined, color: Colors.redAccent),
                  ),
                ],
              ],
            ),

            // Кнопка шеринга 9:16 карточки Победы над Боссом с Радар-чартом 4 сфер
            if (_victory) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFEE440),
                    side: const BorderSide(color: Color(0xFFFEE440)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => ShareCardSheet(
                        initialMode: ShareCardMode.heroBossVictory,
                        heroLevel: widget.heroLevel,
                        streakDays: widget.streakDays,
                        equipped: widget.equipped,
                        combatStats: widget.combatStats,
                        spheres: widget.spheres,
                        defeatedBoss: _selectedBoss,
                      ),
                    );
                  },
                  icon: const Icon(Icons.share),
                  label: const Text(
                    '📲 Поделиться Победой в Stories 9:16 (Радар 4 сфер)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHealthBars() {
    final bossPct = _bossMaxHp > 0 ? (_bossHp / _bossMaxHp).clamp(0.0, 1.0) : 0.0;
    final playerPct = _playerMaxHp > 0 ? (_playerHp / _playerMaxHp).clamp(0.0, 1.0) : 0.0;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_selectedBoss.icon} Босс: ${_bossHp.toStringAsFixed(0)} / ${_bossMaxHp.toStringAsFixed(0)} HP',
              style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 12, fontWeight: FontWeight.bold),
            ),
            Text(
              'Награда: +${_selectedBoss.rewardXp} XP • +${_selectedBoss.rewardGold} 🪙',
              style: const TextStyle(color: Color(0xFFFEE440), fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: bossPct,
          minHeight: 8,
          backgroundColor: Colors.white12,
          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF2A85)),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '🧑‍🚀 Герой: ${_playerHp.toStringAsFixed(0)} / ${_playerMaxHp.toStringAsFixed(0)} HP',
              style: const TextStyle(color: Color(0xFF00F5D4), fontSize: 12, fontWeight: FontWeight.bold),
            ),
            Text(
              '🛡️ Щит питомца (Душа): ${_petShield.toStringAsFixed(0)}',
              style: const TextStyle(color: Color(0xFF00BBF9), fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: playerPct,
          minHeight: 8,
          backgroundColor: Colors.white12,
          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00F5D4)),
        ),
      ],
    );
  }

  Widget _statLine(String label, String val) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 11),
        children: [
          TextSpan(text: '$label ', style: const TextStyle(color: Colors.white54)),
          TextSpan(
            text: val,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _ArenaCanvasPainter extends CustomPainter {
  final MinigameMode mode;
  final String bossIcon;
  final double bossX;
  final Offset playerPos;
  final List<_Bullet> bullets;
  final bool sandevistanActive;
  final bool dashInvulnActive;
  final bool petShieldActive;
  final double parryCursor;
  final double targetZoneCenter;
  final int parryWindowMs;

  _ArenaCanvasPainter({
    required this.mode,
    required this.bossIcon,
    required this.bossX,
    required this.playerPos,
    required this.bullets,
    required this.sandevistanActive,
    required this.dashInvulnActive,
    required this.petShieldActive,
    required this.parryCursor,
    required this.targetZoneCenter,
    required this.parryWindowMs,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Кибер-сетка арены
    final gridPaint = Paint()
      ..color = (sandevistanActive ? const Color(0xFF9B5DE5) : const Color(0xFF00F5D4))
          .withOpacity(0.12)
      ..strokeWidth = 1;

    for (double x = 0; x < size.width; x += 36) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 36) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (mode == MinigameMode.bulletHell) {
      _paintBulletHell(canvas, size);
    } else {
      _paintReflexParry(canvas, size);
    }
  }

  void _paintBulletHell(Canvas canvas, Size size) {
    // Босс в верхней части арены
    final bossOffset = Offset(bossX * size.width, 0.14 * size.height);
    final bossGlow = Paint()
      ..color = const Color(0xFFFF2A85).withOpacity(0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(bossOffset, 28, bossGlow);

    final bossTp = TextPainter(
      text: TextSpan(text: bossIcon, style: const TextStyle(fontSize: 32)),
      textDirection: TextDirection.ltr,
    )..layout();
    bossTp.paint(canvas, Offset(bossOffset.dx - bossTp.width / 2, bossOffset.dy - bossTp.height / 2));

    // Ядро игрока
    final pCenter = Offset(playerPos.dx * size.width, playerPos.dy * size.height);
    if (petShieldActive) {
      final shieldPaint = Paint()
        ..color = const Color(0xFF00BBF9).withOpacity(0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawCircle(pCenter, 22, shieldPaint);
    }
    final playerPaint = Paint()
      ..color = dashInvulnActive ? const Color(0xFFFEE440) : const Color(0xFF00F5D4)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pCenter, 12, playerPaint);

    // Снаряды и лазеры
    for (final b in bullets) {
      final bPaint = Paint()
        ..color = b.color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(b.pos.dx * size.width, b.pos.dy * size.height),
        b.radius * size.width * 0.45,
        bPaint,
      );
    }
  }

  void _paintReflexParry(Canvas canvas, Size size) {
    // Визуал дуэли: Босс по центру и скоростная шкала тайминга парирования
    final bossCenter = Offset(size.width / 2, size.height * 0.34);
    final bossRing = Paint()
      ..color = const Color(0xFFFF2A85).withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(bossCenter, 46, bossRing);

    final bossTp = TextPainter(
      text: TextSpan(text: bossIcon, style: const TextStyle(fontSize: 48)),
      textDirection: TextDirection.ltr,
    )..layout();
    bossTp.paint(canvas, Offset(bossCenter.dx - bossTp.width / 2, bossCenter.dy - bossTp.height / 2));

    // Полоса тайминга парирования
    final barTop = size.height * 0.68;
    final barLeft = size.width * 0.08;
    final barWidth = size.width * 0.84;
    const barHeight = 28.0;

    final trackRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(barLeft, barTop, barWidth, barHeight),
      const Radius.circular(14),
    );
    canvas.drawRRect(trackRect, Paint()..color = Colors.white12);

    // Зеленая зона окна парирования (ширина зависит от Мозга)
    final halfWin = (parryWindowMs / 1000.0).clamp(0.08, 0.24);
    final winStart = (targetZoneCenter - halfWin).clamp(0.0, 1.0);
    final winEnd = (targetZoneCenter + halfWin).clamp(0.0, 1.0);

    canvas.drawRect(
      Rect.fromLTWH(
        barLeft + winStart * barWidth,
        barTop,
        (winEnd - winStart) * barWidth,
        barHeight,
      ),
      Paint()..color = const Color(0xFF00F5D4).withOpacity(0.45),
    );

    // Золотой центр идеального крит-парирования
    final bullHalf = halfWin * 0.38;
    canvas.drawRect(
      Rect.fromLTWH(
        barLeft + (targetZoneCenter - bullHalf) * barWidth,
        barTop,
        (bullHalf * 2) * barWidth,
        barHeight,
      ),
      Paint()..color = const Color(0xFFFEE440).withOpacity(0.85),
    );

    // Бегущий курсор удара
    final cursorX = barLeft + parryCursor * barWidth;
    canvas.drawLine(
      Offset(cursorX, barTop - 8),
      Offset(cursorX, barTop + barHeight + 8),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 4,
    );
  }

  @override
  bool shouldRepaint(covariant _ArenaCanvasPainter oldDelegate) => true;
}
