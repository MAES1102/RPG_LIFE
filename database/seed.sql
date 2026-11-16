-- ============================================================================
-- RPG_LIFE: Initial Seed Data
-- Внутриигровой магазин (скины, апгрейд базы, питомцы, бустеры — никакого «отдыха за деньги»)
-- ============================================================================

INSERT INTO public.shop_items (code, name, description, category, price_gold, rive_asset_key, icon, metadata)
VALUES
    -- Скины / Экипировка персонажа
    (
        'skin_neon_samurai',
        'Экзокостюм «Неоновый Самурай»',
        'Кибернетическая броня с голографической катаной. Подсвечивается при закрытии Хардкор-квестов.',
        'skin',
        120,
        'skin_neon_samurai',
        '🥷',
        '{"rarity": "epic", "glow_color": "#00F5D4"}'::jsonb
    ),
    (
        'skin_netrunner_hoodie',
        'Мантия Нетраннера',
        'Стильный плащ с нейроинтерфейсом для глубоких рейдов фокуса.',
        'skin',
        80,
        'skin_netrunner_hoodie',
        '🧥',
        '{"rarity": "rare", "glow_color": "#9B5DE5"}'::jsonb
    ),
    -- Декор и апгрейды комнаты / базы
    (
        'decor_holo_monolith',
        'Голографический Терминал v2.0',
        'Превращает рабочий стол базы в трехмерную тактическую станцию с живыми графиками сфер.',
        'base_decor',
        150,
        'decor_holo_monolith',
        '🖥️',
        '{"rarity": "epic", "slot": "workstation"}'::jsonb
    ),
    (
        'decor_bonsai_synth',
        'Синт-Бонсай «Дзен-Контур»',
        'Биолюминесцентное дерево в углу базы, которое расцветает по мере роста сферы Души.',
        'base_decor',
        90,
        'decor_bonsai_synth',
        '🌳',
        '{"rarity": "rare", "slot": "ambient"}'::jsonb
    ),
    -- Питомцы-компаньоны
    (
        'pet_cyber_fox',
        'Кибер-Лис «Кицунэ-09»',
        'Дрон-компаньон, который спит у терминала во время таймера фокуса и празднует твой левел-ап.',
        'pet',
        200,
        'pet_cyber_fox',
        '🦊',
        '{"rarity": "legendary", "idle_animation": "tail_pulse"}'::jsonb
    ),
    (
        'pet_bot_owl',
        'Меха-Сова «Афина»',
        'Спутник исследователя. Реагирует анимацией крыльев на выполнение учебных квестов.',
        'pet',
        140,
        'pet_bot_owl',
        '🦉',
        '{"rarity": "epic", "idle_animation": "head_tilt"}'::jsonb
    ),
    -- Игровые бустеры
    (
        'booster_streak_freeze',
        'Щит заморозки стрика',
        'Автоматически защищает твой стрик (бонус +5%/день) на 1 пропущенный день без потери множителя.',
        'booster',
        60,
        'booster_streak_freeze',
        '🛡️',
        '{"consumable": true, "effect": "streak_freeze_1d"}'::jsonb
    )
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    price_gold = EXCLUDED.price_gold,
    rive_asset_key = EXCLUDED.rive_asset_key,
    icon = EXCLUDED.icon,
    metadata = EXCLUDED.metadata;

-- ----------------------------------------------------------------------------
-- Стартовые этажи Башни Боссов / Нейро-Арены
-- ----------------------------------------------------------------------------
INSERT INTO public.arena_bosses (
    code, floor, name, title, description, minigame_mode,
    recommended_hero_level, boss_hp, boss_dps, bullet_density,
    reward_xp, reward_gold, trophy_code, trophy_name, icon
)
VALUES
    (
        'boss_floor_1_warden',
        1,
        'Цербер Прокрастинации v1.0',
        'Страж Первого Контура',
        'Атакует веерными импульсами рассеянного внимания. Прокачай Мозг для замедления времени и Тело для пробития щита.',
        'bullet_hell',
        1,
        420,
        24,
        1.0,
        250,
        65,
        'trophy_warden_core',
        'Ядро Цербера (Этаж 1)',
        '👾'
    ),
    (
        'boss_floor_2_ronin',
        2,
        'Хроно-Ронин «Акаги»',
        'Мастер Сверхзвукового Парирования',
        'Молниеносная дуэль на реакцию. Без прокачанного окна парирования (Мозг) и мощного удара (Тело) пробить его защиту почти невозможно.',
        'reflex_parry',
        2,
        720,
        36,
        1.3,
        400,
        110,
        'trophy_ronin_katana',
        'Клинок Акаги (Этаж 2)',
        '👹'
    ),
    (
        'boss_floor_3_leviathan',
        3,
        'Нейро-Левиафан «Омега-Сеть»',
        'Архитектор Плотного Фаервола',
        'Генерирует спиральные штормы лазеров. Требуется высокий уровень Энергии для частых рывков и Души для щита компаньона.',
        'bullet_hell',
        4,
        1250,
        52,
        1.7,
        650,
        180,
        'trophy_leviathan_matrix',
        'Матрица Левиафана (Этаж 3)',
        '🐉'
    ),
    (
        'boss_floor_4_architect',
        4,
        'Абсолютный Архитектор Энтропии',
        'Финальный Босс Кибер-Башни',
        'Экстремальная проверка всех 4 сфер жизни: максимальная скорость зон парирования и сокрушительные контратаки.',
        'reflex_parry',
        6,
        2100,
        75,
        2.2,
        1000,
        300,
        'trophy_entropy_crown',
        'Корона Архитектора (Этаж 4)',
        '👑'
    )
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    boss_hp = EXCLUDED.boss_hp,
    boss_dps = EXCLUDED.boss_dps,
    reward_xp = EXCLUDED.reward_xp,
    reward_gold = EXCLUDED.reward_gold;
