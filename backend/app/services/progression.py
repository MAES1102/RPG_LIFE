from __future__ import annotations

import math
from dataclasses import dataclass
from typing import Dict, Literal, Tuple

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
