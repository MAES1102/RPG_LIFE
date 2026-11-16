from __future__ import annotations

import unittest

from app.services.progression import (
    apply_xp_and_level_up,
    compute_action_reward,
    compute_combat_stats,
    compute_overachieve_multiplier,
    compute_streak_multiplier,
    compute_xp_next,
)


class ProgressionMathTestCase(unittest.TestCase):
    def test_xp_next_level_1_is_500(self) -> None:
        """Первый левел-ап происходит за 500 XP — уже в первый день для удержания."""
        self.assertEqual(compute_xp_next(1), 500)
        # Level 2: round(500 * 2^1.4) = round(1319.5079) = 1320
        self.assertEqual(compute_xp_next(2), 1320)

    def test_streak_multiplier_caps_at_1_5(self) -> None:
        """M_streak: +5% за каждый день подряд, максимум +50% (от 1.0 до 1.5)."""
        self.assertAlmostEqual(compute_streak_multiplier(0), 1.0)
        self.assertAlmostEqual(compute_streak_multiplier(2), 1.10)
        self.assertAlmostEqual(compute_streak_multiplier(10), 1.50)
        self.assertAlmostEqual(compute_streak_multiplier(25), 1.50)

    def test_overachieve_multiplier_caps_at_1_5(self) -> None:
        """M_overachieve: отношение факта к цели, ограничено сверху 1.5."""
        self.assertAlmostEqual(compute_overachieve_multiplier(3.0, 3.0), 1.0)
        self.assertAlmostEqual(compute_overachieve_multiplier(3.6, 3.0), 1.2)
        self.assertAlmostEqual(compute_overachieve_multiplier(6.0, 3.0), 1.5)

    def test_action_reward_and_gold_formula(self) -> None:
        """
        XP_action = 100 * D * M_streak * M_overachieve
        Gold = floor(XP_action * 0.2)
        """
        # Easy (1.0), streak 0 (1.0), exact target (1.0) -> 100 XP, 20 Gold
        r_easy = compute_action_reward("easy", streak_days=0, actual_value=1, target_value=1)
        self.assertEqual(r_easy.xp_action, 100)
        self.assertEqual(r_easy.gold, 20)

        # Hardcore (2.5), streak 10 days (1.5), overachieve 1.5x -> 100 * 2.5 * 1.5 * 1.5 = 562.5 -> 562 XP, 112 Gold
        r_max = compute_action_reward("hardcore", streak_days=10, actual_value=4.5, target_value=3.0)
        self.assertEqual(r_max.xp_action, 562)
        self.assertEqual(r_max.gold, 112)

    def test_level_up_progression(self) -> None:
        new_lvl, rem_xp, leveled = apply_xp_and_level_up(current_level=1, current_xp=300, added_xp=250)
        self.assertTrue(leveled)
        self.assertEqual(new_lvl, 2)
        self.assertEqual(rem_xp, 50)

    def test_combat_stats_from_four_spheres_and_equipment(self) -> None:
        """
        Проверяет связку «Прогресс в реальной жизни -> Боевые статы аватара»:
        - Тело (body=1 -> HP=135, ATK=15; body=4 -> HP=240, ATK=30)
        - Мозг (brain=1 -> chrono=10%, parry=113ms; brain=5 -> chrono=30%, parry=185ms)
        - Энергия (energy=1 -> dash=3.85s; energy=5 -> dash=2.45s)
        - Душа (soul=1 -> crit=0.085, shield=15; с питомцем +40 щита)
        """
        base_stats = compute_combat_stats(
            body_level=1,
            brain_level=1,
            energy_level=1,
            soul_level=1,
        )
        self.assertEqual(base_stats.max_hp, 135)
        self.assertEqual(base_stats.attack_power, 15)
        self.assertEqual(base_stats.chrono_slow_percent, 10)
        self.assertEqual(base_stats.parry_window_ms, 113)
        self.assertAlmostEqual(base_stats.dash_cooldown_sec, 3.85)
        self.assertEqual(base_stats.pet_assist_shield, 15)

        upgraded_stats = compute_combat_stats(
            body_level=4,
            brain_level=5,
            energy_level=5,
            soul_level=4,
            equipped_skin="skin_neon_samurai",
            equipped_pet="pet_cyber_fox",
        )
        self.assertEqual(upgraded_stats.max_hp, 100 + 35 * 4 + 25)
        self.assertEqual(upgraded_stats.attack_power, 10 + 5 * 4 + 4)
        self.assertEqual(upgraded_stats.chrono_slow_percent, 30)
        self.assertEqual(upgraded_stats.pet_assist_shield, 15 * 4 + 40)
        self.assertGreater(upgraded_stats.combat_power_score, base_stats.combat_power_score)


if __name__ == "__main__":
    unittest.main()
