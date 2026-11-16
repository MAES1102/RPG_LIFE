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
}
