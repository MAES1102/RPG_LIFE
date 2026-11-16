import 'package:flutter/material.dart';
import '../models/rpg_models.dart';

/// Интерактивная 2D/Rive-сцена персонажа и базы в киберпанк-стиле.
/// Отображает экипированный скин героя, апгрейд комнаты/базы и питомца-компаньона.
class RiveHeroStage extends StatelessWidget {
  final int heroLevel;
  final EquippedState equipped;
  final bool streakFreezeActive;
  final VoidCallback onOpenShop;

  const RiveHeroStage({
    super.key,
    required this.heroLevel,
    required this.equipped,
    required this.streakFreezeActive,
    required this.onOpenShop,
  });

  String _skinAvatar(String skinCode) {
    switch (skinCode) {
      case 'skin_neon_samurai':
        return '🥷';
      case 'skin_netrunner_hoodie':
        return '🧥';
      default:
        return '🧑‍🚀';
    }
  }

  String _skinTitle(String skinCode) {
    switch (skinCode) {
      case 'skin_neon_samurai':
        return 'Неоновый Самурай';
      case 'skin_netrunner_hoodie':
        return 'Мантия Нетраннера';
      default:
        return 'Базовый Кибер-Раннер';
    }
  }

  String _decorTitle(String decorCode) {
    switch (decorCode) {
      case 'decor_holo_monolith':
        return '🖥️ Голографический Терминал v2.0';
      case 'decor_bonsai_synth':
        return '🌳 Синт-Бонсай «Дзен-Контур»';
      default:
        return '🎛️ Кибер-отсек Ур. 1';
    }
  }

  String? _petEmoji(String? petCode) {
    switch (petCode) {
      case 'pet_cyber_fox':
        return '🦊 Кицунэ-09';
      case 'pet_bot_owl':
        return '🦉 Меха-Сова Афина';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final petBadge = _petEmoji(equipped.pet);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF131629), Color(0xFF1E1B3A), Color(0xFF0E273C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFF00F5D4).withOpacity(0.45), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00F5D4).withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  _decorTitle(equipped.baseDecor),
                  style: const TextStyle(color: Color(0xFF00F5D4), fontSize: 12),
                ),
              ),
              if (streakFreezeActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00BBF9).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF00BBF9)),
                  ),
                  child: const Text(
                    '🛡️ Щит стрика активен',
                    style: TextStyle(color: Color(0xFF00BBF9), fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Аватар героя (Rive Artboard / Интерактивный узел)
              Container(
                width: 84,
                height: 84,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF9B5DE5).withOpacity(0.45),
                      Colors.transparent,
                    ],
                  ),
                  border: Border.all(color: const Color(0xFF9B5DE5), width: 2),
                ),
                child: Text(
                  _skinAvatar(equipped.skin),
                  style: const TextStyle(fontSize: 44),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Герой Уровня $heroLevel',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Экипировка: ${_skinTitle(equipped.skin)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      petBadge != null
                          ? 'Компаньон рядом: $petBadge'
                          : 'Компаньон: не выбран (доступен в магазине)',
                      style: const TextStyle(color: Color(0xFFFEE440), fontSize: 12),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: onOpenShop,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFEE440),
                  side: const BorderSide(color: Color(0xFFFEE440)),
                ),
                icon: const Icon(Icons.storefront, size: 18),
                label: const Text('База / Скины'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
