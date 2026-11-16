import 'dart:async';
import 'package:flutter/material.dart';
import '../models/rpg_models.dart';

/// Встроенный игровой таймер фокуса («Рейд») для учебных и рабочих квестов.
class RaidFocusTimerSheet extends StatefulWidget {
  final QuestModel quest;
  final ValueChanged<double> onRaidCompleted;

  const RaidFocusTimerSheet({
    super.key,
    required this.quest,
    required this.onRaidCompleted,
  });

  @override
  State<RaidFocusTimerSheet> createState() => _RaidFocusTimerSheetState();
}

class _RaidFocusTimerSheetState extends State<RaidFocusTimerSheet> {
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _running = true;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_running && mounted) {
        setState(() {
          _elapsedSeconds++;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final targetMinutes = widget.quest.targetValue;
    final mins = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (_elapsedSeconds % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF121324),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '⚔️ РЕЙД ФОКУСА АКТИВЕН',
            style: TextStyle(
              color: Color(0xFF00F5D4),
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.quest.title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          Text(
            '$mins:$secs',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          Text(
            'Цель рейда: ${targetMinutes.toStringAsFixed(0)} ${widget.quest.targetUnit}',
            style: const TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  setState(() => _running = !_running);
                },
                icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                label: Text(_running ? 'Пауза' : 'Продолжить'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00F5D4),
                  foregroundColor: Colors.black,
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onRaidCompleted(targetMinutes);
                },
                icon: const Icon(Icons.bolt),
                label: const Text('Завершить рейд (100%)'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Сверхплановый рейд (+25% времени -> бонус M_overachieve = 1.25)
              widget.onRaidCompleted(targetMinutes * 1.25);
            },
            child: const Text(
              '🔥 Завершить с перевыполнением (+25% времени → бонус XP)',
              style: TextStyle(color: Color(0xFFFEE440), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
