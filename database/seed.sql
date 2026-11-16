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
