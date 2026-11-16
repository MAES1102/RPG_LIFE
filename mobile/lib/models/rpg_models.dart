import 'dart:math' as math;

enum QuestDifficulty { easy, normal, hardcore }

enum TrackingType { manual, timer, healthApi }

class EquippedState {
  final String skin;
  final String baseDecor;
  final String? pet;

  const EquippedState({
    this.skin = 'skin_default_runner',
    this.baseDecor = 'decor_cyber_terminal_v1',
    this.pet,
  });

  factory EquippedState.fromJson(Map<String, dynamic> json) {
    return EquippedState(
      skin: json['skin'] as String? ?? 'skin_default_runner',
      baseDecor: json['base_decor'] as String? ?? 'decor_cyber_terminal_v1',
      pet: json['pet'] as String?,
    );
  }
}

class SphereModel {
  final String id;
  final String code;
  String name;
  String icon;
  int level;
  int currentXp;
  int xpNext;

  SphereModel({
    required this.id,
    required this.code,
    required this.name,
    required this.icon,
    this.level = 1,
    this.currentXp = 0,
    this.xpNext = 500,
  });

  double get progress => xpNext > 0 ? (currentXp / xpNext).clamp(0.0, 1.0) : 0.0;

  factory SphereModel.fromJson(Map<String, dynamic> json) {
    return SphereModel(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String,
      level: json['level'] as int? ?? 1,
      currentXp: json['current_xp'] as int? ?? 0,
      xpNext: json['xp_next'] as int? ?? 500,
    );
  }
}

class QuestModel {
  final String id;
  final String sphereId;
  final String sphereCode;
  String sphereName;
  String sphereIcon;
  final String title;
  final String description;
  final QuestDifficulty difficulty;
  final TrackingType trackingType;
  final double targetValue;
  final String targetUnit;
  final String frequency;
  final String? healthMetricKey;
  final int estimatedXp;
  final int estimatedGold;

  QuestModel({
    required this.id,
    required this.sphereId,
    required this.sphereCode,
    required this.sphereName,
    required this.sphereIcon,
    required this.title,
    required this.description,
    required this.difficulty,
    required this.trackingType,
    required this.targetValue,
    required this.targetUnit,
    this.frequency = 'daily',
    this.healthMetricKey,
    required this.estimatedXp,
    required this.estimatedGold,
  });

  static QuestDifficulty parseDifficulty(String raw) {
    switch (raw) {
      case 'easy':
        return QuestDifficulty.easy;
      case 'hardcore':
        return QuestDifficulty.hardcore;
      default:
        return QuestDifficulty.normal;
    }
  }

  static String difficultyToApi(QuestDifficulty d) {
    switch (d) {
      case QuestDifficulty.easy:
        return 'easy';
      case QuestDifficulty.normal:
        return 'normal';
      case QuestDifficulty.hardcore:
        return 'hardcore';
    }
  }

  static String difficultyLabelRu(QuestDifficulty d) {
    switch (d) {
      case QuestDifficulty.easy:
        return 'Легко (1.0x)';
      case QuestDifficulty.normal:
        return 'Нормально (1.5x)';
      case QuestDifficulty.hardcore:
        return 'Хардкор (2.5x)';
    }
  }

  static TrackingType parseTracking(String raw) {
    switch (raw) {
      case 'timer':
        return TrackingType.timer;
      case 'health_api':
        return TrackingType.healthApi;
      default:
        return TrackingType.manual;
    }
  }

  factory QuestModel.fromJson(Map<String, dynamic> json) {
    return QuestModel(
      id: json['id'] as String,
      sphereId: json['sphere_id'] as String,
      sphereCode: json['sphere_code'] as String,
      sphereName: json['sphere_name'] as String? ?? 'Сфера',
      sphereIcon: json['sphere_icon'] as String? ?? '⚡',
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      difficulty: parseDifficulty(json['difficulty'] as String? ?? 'normal'),
      trackingType: parseTracking(json['tracking_type'] as String? ?? 'manual'),
      targetValue: (json['target_value'] as num?)?.toDouble() ?? 1.0,
      targetUnit: json['target_unit'] as String? ?? 'раз',
      frequency: json['frequency'] as String? ?? 'daily',
      healthMetricKey: json['health_metric_key'] as String?,
      estimatedXp: json['estimated_xp'] as int? ?? 150,
      estimatedGold: json['estimated_gold'] as int? ?? 30,
    );
  }
}

class ShopItemModel {
  final String id;
  final String code;
  final String name;
  final String description;
  final String category; // 'skin' | 'base_decor' | 'pet' | 'booster'
  final int priceGold;
  final String riveAssetKey;
  final String icon;

  const ShopItemModel({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.category,
    required this.priceGold,
    required this.riveAssetKey,
    required this.icon,
  });

  factory ShopItemModel.fromJson(Map<String, dynamic> json) {
    return ShopItemModel(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      priceGold: json['price_gold'] as int,
      riveAssetKey: json['rive_asset_key'] as String,
      icon: json['icon'] as String? ?? '🎁',
    );
  }
}

enum MinigameMode { bulletHell, reflexParry }

/// Боевые характеристики аватара, рассчитанные из уровней 4 сфер реальной жизни и экипировки.
class CombatStatsModel {
  final int maxHp;
  final int attackPower;
  final int chronoSlowPercent;
  final int parryWindowMs;
  final double dashCooldownSec;
  final double staminaRegen;
  final double critChance;
  final double critMultiplier;
  final int petAssistShield;
  final int combatPowerScore;

  const CombatStatsModel({
    required this.maxHp,
    required this.attackPower,
    required this.chronoSlowPercent,
    required this.parryWindowMs,
    required this.dashCooldownSec,
    required this.staminaRegen,
    required this.critChance,
    this.critMultiplier = 2.5,
    required this.petAssistShield,
    required this.combatPowerScore,
  });

  factory CombatStatsModel.fromJson(Map<String, dynamic> json) {
    return CombatStatsModel(
      maxHp: json['max_hp'] as int? ?? 135,
      attackPower: json['attack_power'] as int? ?? 15,
      chronoSlowPercent: json['chrono_slow_percent'] as int? ?? 10,
      parryWindowMs: json['parry_window_ms'] as int? ?? 113,
      dashCooldownSec: (json['dash_cooldown_sec'] as num?)?.toDouble() ?? 3.85,
      staminaRegen: (json['stamina_regen'] as num?)?.toDouble() ?? 19.5,
      critChance: (json['crit_chance'] as num?)?.toDouble() ?? 0.085,
      critMultiplier: (json['crit_multiplier'] as num?)?.toDouble() ?? 2.5,
      petAssistShield: json['pet_assist_shield'] as int? ?? 15,
      combatPowerScore: json['combat_power_score'] as int? ?? 240,
    );
  }
}

class ArenaBossModel {
  final String id;
  final String code;
  final int floor;
  final String name;
  final String title;
  final String description;
  final MinigameMode minigameMode;
  final int recommendedHeroLevel;
  final int bossHp;
  final int bossDps;
  final double bulletDensity;
  final int bossPowerScore;
  final int rewardXp;
  final int rewardGold;
  final String trophyCode;
  final String trophyName;
  final String icon;
  bool isDefeated;

  ArenaBossModel({
    required this.id,
    required this.code,
    required this.floor,
    required this.name,
    required this.title,
    required this.description,
    required this.minigameMode,
    required this.recommendedHeroLevel,
    required this.bossHp,
    required this.bossDps,
    required this.bulletDensity,
    required this.bossPowerScore,
    required this.rewardXp,
    required this.rewardGold,
    required this.trophyCode,
    required this.trophyName,
    required this.icon,
    this.isDefeated = false,
  });

  factory ArenaBossModel.fromJson(Map<String, dynamic> json) {
    final modeRaw = json['minigame_mode'] as String? ?? 'bullet_hell';
    return ArenaBossModel(
      id: json['id'] as String? ?? 'boss',
      code: json['code'] as String,
      floor: json['floor'] as int? ?? 1,
      name: json['name'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      minigameMode: modeRaw == 'reflex_parry' ? MinigameMode.reflexParry : MinigameMode.bulletHell,
      recommendedHeroLevel: json['recommended_hero_level'] as int? ?? 1,
      bossHp: json['boss_hp'] as int? ?? 420,
      bossDps: json['boss_dps'] as int? ?? 24,
      bulletDensity: (json['bullet_density'] as num?)?.toDouble() ?? 1.0,
      bossPowerScore: json['boss_power_score'] as int? ?? 260,
      rewardXp: json['reward_xp'] as int? ?? 250,
      rewardGold: json['reward_gold'] as int? ?? 65,
      trophyCode: json['trophy_code'] as String? ?? 'trophy',
      trophyName: json['trophy_name'] as String? ?? 'Трофей Арены',
      icon: json['icon'] as String? ?? '👾',
      isDefeated: json['is_defeated'] as bool? ?? false,
    );
  }

  static List<ArenaBossModel> defaultTowerBosses() => [
        ArenaBossModel(
          id: 'boss-floor-1',
          code: 'boss_floor_1_warden',
          floor: 1,
          name: 'Цербер Прокрастинации v1.0',
          title: 'Страж Первого Контура',
          description:
              'Атакует веерными импульсами рассеянного внимания. Прокачай Мозг для замедления времени и Тело для пробития щита.',
          minigameMode: MinigameMode.bulletHell,
          recommendedHeroLevel: 1,
          bossHp: 420,
          bossDps: 24,
          bulletDensity: 1.0,
          bossPowerScore: 260,
          rewardXp: 250,
          rewardGold: 65,
          trophyCode: 'trophy_warden_core',
          trophyName: 'Ядро Цербера (Этаж 1)',
          icon: '👾',
        ),
        ArenaBossModel(
          id: 'boss-floor-2',
          code: 'boss_floor_2_ronin',
          floor: 2,
          name: 'Хроно-Ронин «Акаги»',
          title: 'Мастер Сверхзвукового Парирования',
          description:
              'Молниеносная дуэль на реакцию. Без прокачанного окна парирования (Мозг) и мощного удара (Тело) пробить его защиту почти невозможно.',
          minigameMode: MinigameMode.reflexParry,
          recommendedHeroLevel: 2,
          bossHp: 720,
          bossDps: 36,
          bulletDensity: 1.3,
          bossPowerScore: 390,
          rewardXp: 400,
          rewardGold: 110,
          trophyCode: 'trophy_ronin_katana',
          trophyName: 'Клинок Акаги (Этаж 2)',
          icon: '👹',
        ),
        ArenaBossModel(
          id: 'boss-floor-3',
          code: 'boss_floor_3_leviathan',
          floor: 3,
          name: 'Нейро-Левиафан «Омега-Сеть»',
          title: 'Архитектор Плотного Фаервола',
          description:
              'Генерирует спиральные штормы лазеров. Требуется высокий уровень Энергии для частых рывков и Души для щита компаньона.',
          minigameMode: MinigameMode.bulletHell,
          recommendedHeroLevel: 4,
          bossHp: 1250,
          bossDps: 52,
          bulletDensity: 1.7,
          bossPowerScore: 560,
          rewardXp: 650,
          rewardGold: 180,
          trophyCode: 'trophy_leviathan_matrix',
          trophyName: 'Матрица Левиафана (Этаж 3)',
          icon: '🐉',
        ),
        ArenaBossModel(
          id: 'boss-floor-4',
          code: 'boss_floor_4_architect',
          floor: 4,
          name: 'Абсолютный Архитектор Энтропии',
          title: 'Финальный Босс Кибер-Башни',
          description:
              'Экстремальная проверка всех 4 сфер жизни: максимальная скорость зон парирования и сокрушительные контратаки.',
          minigameMode: MinigameMode.reflexParry,
          recommendedHeroLevel: 6,
          bossHp: 2100,
          bossDps: 75,
          bulletDensity: 2.2,
          bossPowerScore: 780,
          rewardXp: 1000,
          rewardGold: 300,
          trophyCode: 'trophy_entropy_crown',
          trophyName: 'Корона Архитектора (Этаж 4)',
          icon: '👑',
        ),
      ];
}

/// Математическая модель прогрессии и баланса на клиенте (для мгновенного превью)
class ProgressionMath {
  static double difficultyMultiplier(QuestDifficulty d) {
    switch (d) {
      case QuestDifficulty.easy:
        return 1.0;
      case QuestDifficulty.normal:
        return 1.5;
      case QuestDifficulty.hardcore:
        return 2.5;
    }
  }

  static double streakMultiplier(int streakDays) {
    final bonus = 1.0 + 0.05 * math.max(0, streakDays);
    return math.min(1.5, bonus);
  }

  static double overachieveMultiplier(double actual, double target) {
    if (target <= 0) return 1.0;
    return math.min(1.5, math.max(0.0, actual) / target);
  }

  static int xpNextForLevel(int level) {
    final safeLevel = math.max(1, level);
    return (500.0 * math.pow(safeLevel, 1.4)).round();
  }

  static int computeXpAction({
    required QuestDifficulty difficulty,
    required int streakDays,
    required double actualValue,
    required double targetValue,
  }) {
    final d = difficultyMultiplier(difficulty);
    final mStreak = streakMultiplier(streakDays);
    final mOver = overachieveMultiplier(actualValue, targetValue);
    return (100.0 * d * mStreak * mOver).round();
  }

  static int computeGold(int xpAction) {
    return (xpAction * 0.2).floor();
  }

  /// Расчет боевых характеристик аватара напрямую из уровней 4 сфер и экипировки.
  static CombatStatsModel computeCombatStats({
    required int bodyLevel,
    required int brainLevel,
    required int energyLevel,
    required int soulLevel,
    required EquippedState equipped,
  }) {
    final bLvl = math.max(1, bodyLevel);
    final brLvl = math.max(1, brainLevel);
    final eLvl = math.max(1, energyLevel);
    final sLvl = math.max(1, soulLevel);

    final skinHpBonus = equipped.skin == 'skin_neon_samurai' ? 25 : 0;
    final skinAtkBonus = equipped.skin == 'skin_neon_samurai' ? 4 : 0;
    final skinChronoBonus = equipped.skin == 'skin_netrunner_hoodie' ? 5 : 0;
    final petBonusShield = equipped.pet != null ? 40 : 0;

    final maxHp = 100 + 35 * bLvl + skinHpBonus;
    final attackPower = 10 + 5 * bLvl + skinAtkBonus;
    final chronoSlowPercent = (10 + 5 * (brLvl - 1) + skinChronoBonus).clamp(10, 50);
    final parryWindowMs = (95 + 18 * brLvl).clamp(95, 260);
    final dashCooldownSec =
        double.parse(math.max(1.1, 4.2 - 0.35 * eLvl).toStringAsFixed(2));
    final staminaRegen = double.parse((15.0 + 4.5 * eLvl).toStringAsFixed(1));
    final critChance =
        double.parse(math.min(0.50, 0.05 + 0.035 * sLvl).toStringAsFixed(3));
    final petAssistShield = 15 * sLvl + petBonusShield;

    final powerScore = ((maxHp + petAssistShield) * 0.8 +
            attackPower * 6.5 +
            chronoSlowPercent * 3.0 +
            (1000.0 / math.max(1.0, dashCooldownSec)) * 0.15 +
            critChance * 250.0)
        .round();

    return CombatStatsModel(
      maxHp: maxHp,
      attackPower: attackPower,
      chronoSlowPercent: chronoSlowPercent,
      parryWindowMs: parryWindowMs,
      dashCooldownSec: dashCooldownSec,
      staminaRegen: staminaRegen,
      critChance: critChance,
      critMultiplier: 2.5,
      petAssistShield: petAssistShield,
      combatPowerScore: powerScore,
    );
  }
}
