from __future__ import annotations

import math
from dataclasses import dataclass
from typing import Dict, Literal, Optional, Tuple

DifficultyType = Literal["easy", "normal", "hardcore"]

DIFFICULTY_MULTIPLIERS: Dict[DifficultyType, float] = {
    "easy": 1.0,
    "normal": 1.5,
    "hardcore": 2.5,
}


@dataclass(frozen=True)
class ActionReward:
    xp_action: int
    gold: int
    difficulty_multiplier: float
    streak_multiplier: float
    overachieve_multiplier: float


def compute_difficulty_multiplier(difficulty: DifficultyType) -> float:
    """D (сложность): Легко = 1.0, Нормально = 1.5, Хардкор = 2.5."""
    return DIFFICULTY_MULTIPLIERS.get(difficulty, 1.5)


def compute_streak_multiplier(streak_days: int) -> float:
    """
    M_streak (бонус за стабильность):
    +5% за каждый день подряд, максимум +50% (от 1.0 до 1.5).
    """
    clamped_days = max(0, streak_days)
    multiplier = 1.0 + 0.05 * clamped_days
    return round(min(1.5, multiplier), 4)


def compute_overachieve_multiplier(actual_value: float, target_value: float) -> float:
    """
    M_overachieve (перевыполнение цели):
    отношение факта к цели, ограничено сверху 1.5.
    """
    if target_value <= 0:
        return 1.0
    ratio = max(0.0, actual_value) / target_value
    return round(min(1.5, ratio), 4)


def compute_xp_next(level: int) -> int:
    """
    Порог следующего уровня:
    XP_next = round(500 * Level^1.4)
    (Для Level=1 порог равен 500 XP).
    """
    safe_level = max(1, level)
    return int(round(500.0 * (safe_level ** 1.4)))


def compute_action_reward(
    difficulty: DifficultyType,
    streak_days: int = 0,
    actual_value: float = 1.0,
    target_value: float = 1.0,
) -> ActionReward:
    """
    Математическая модель прогрессии и баланса:
    XP_action = 100 * D * M_streak * M_overachieve
    Gold = floor(XP_action * 0.2)
    """
    d_mult = compute_difficulty_multiplier(difficulty)
    m_streak = compute_streak_multiplier(streak_days)
    m_over = compute_overachieve_multiplier(actual_value, target_value)

    raw_xp = 100.0 * d_mult * m_streak * m_over
    xp_action = int(round(raw_xp))
    gold = int(math.floor(xp_action * 0.2))

    return ActionReward(
        xp_action=xp_action,
        gold=gold,
        difficulty_multiplier=d_mult,
        streak_multiplier=m_streak,
        overachieve_multiplier=m_over,
    )


def apply_xp_and_level_up(current_level: int, current_xp: int, added_xp: int) -> Tuple[int, int, bool]:
    """
    Применяет полученный опыт с учетом возможных переходов на новый уровень.
    Возвращает кортеж (new_level, new_current_xp, leveled_up).
    """
    level = max(1, current_level)
    xp = max(0, current_xp) + max(0, added_xp)
    leveled_up = False

    while True:
        threshold = compute_xp_next(level)
        if xp >= threshold:
            xp -= threshold
            level += 1
            leveled_up = True
        else:
            break

    return level, xp, leveled_up


@dataclass(frozen=True)
class CombatStatsResult:
    """
    Боевые характеристики аватара для «Нейро-Арены / Башни Боссов»,
    рассчитываемые напрямую из уровней 4 сфер реальной жизни и экипировки.
    """

    max_hp: int
    attack_power: int
    chrono_slow_percent: int
    parry_window_ms: int
    dash_cooldown_sec: float
    stamina_regen: float
    crit_chance: float
    crit_multiplier: float
    pet_assist_shield: int
    combat_power_score: int


def compute_combat_stats(
    body_level: int = 1,
    brain_level: int = 1,
    energy_level: int = 1,
    soul_level: int = 1,
    equipped_skin: str = "skin_default_runner",
    equipped_pet: Optional[str] = None,
) -> CombatStatsResult:
    """
    Связка «Прогресс в реальной жизни -> Боевые статы аватара»:
    - 💪 Тело (body_level): max_hp (база 100 + 35 за уровень), attack_power (база 10 + 5 за уровень).
    - 🧠 Мозг (brain_level): chrono_slow_percent (от 10% до 50%), parry_window_ms (окно тайминга).
    - ⚡ Энергия (energy_level): dash_cooldown_sec (уменьшение КД рывка), stamina_regen.
    - 🎨 Душа (soul_level): crit_chance (шанс крита x2.5) и pet_assist_shield (щит от питомца).
    """
    b_lvl = max(1, body_level)
    br_lvl = max(1, brain_level)
    e_lvl = max(1, energy_level)
    s_lvl = max(1, soul_level)

    # Бонусы от внутриигровой экипировки
    skin_hp_bonus = 25 if equipped_skin == "skin_neon_samurai" else 0
    skin_atk_bonus = 4 if equipped_skin == "skin_neon_samurai" else 0
    skin_chrono_bonus = 5 if equipped_skin == "skin_netrunner_hoodie" else 0
    pet_bonus_shield = 40 if equipped_pet else 0

    # 💪 Тело -> Выживаемость и Урон
    max_hp = 100 + 35 * b_lvl + skin_hp_bonus
    attack_power = 10 + 5 * b_lvl + skin_atk_bonus

    # 🧠 Мозг -> Нейро-Замедление (Sandevistan 10%..50%) и Окно Парирования (мс)
    raw_chrono = 10 + 5 * (br_lvl - 1) + skin_chrono_bonus
    chrono_slow_percent = int(min(50, max(10, raw_chrono)))
    parry_window_ms = int(min(260, 95 + 18 * br_lvl))

    # ⚡ Энергия -> КД рывка/уворота и регенерация стамины
    dash_cooldown_sec = round(max(1.1, 4.2 - 0.35 * e_lvl), 2)
    stamina_regen = round(15.0 + 4.5 * e_lvl, 1)

    # 🎨 Душа -> Шанс крита (x2.5) и Щит компаньона
    crit_chance = round(min(0.50, 0.05 + 0.035 * s_lvl), 3)
    crit_multiplier = 2.5
    pet_assist_shield = 15 * s_lvl + pet_bonus_shield

    # Интегральный индекс Боевой Мощи героя
    combat_power_score = int(
        round(
            (max_hp + pet_assist_shield) * 0.8
            + attack_power * 6.5
            + chrono_slow_percent * 3.0
            + (1000.0 / max(1.0, dash_cooldown_sec)) * 0.15
            + crit_chance * 250.0
        )
    )

    return CombatStatsResult(
        max_hp=max_hp,
        attack_power=attack_power,
        chrono_slow_percent=chrono_slow_percent,
        parry_window_ms=parry_window_ms,
        dash_cooldown_sec=dash_cooldown_sec,
        stamina_regen=stamina_regen,
        crit_chance=crit_chance,
        crit_multiplier=crit_multiplier,
        pet_assist_shield=pet_assist_shield,
        combat_power_score=combat_power_score,
    )
