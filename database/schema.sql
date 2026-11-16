-- ============================================================================
-- RPG_LIFE: Supabase (PostgreSQL) Schema
-- 6 Core Entities: users, spheres, quests, activity_logs, shop_items, user_inventory
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ----------------------------------------------------------------------------
-- 1. users — Профиль героя
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username TEXT NOT NULL DEFAULT 'Кибер-Путник',
    hero_preset TEXT NOT NULL DEFAULT 'student', -- 'student' | 'athlete' | 'cyber_nomad'
    level INTEGER NOT NULL DEFAULT 1 CHECK (level >= 1),
    current_xp INTEGER NOT NULL DEFAULT 0 CHECK (current_xp >= 0),
    gold INTEGER NOT NULL DEFAULT 100 CHECK (gold >= 0),
    streak_days INTEGER NOT NULL DEFAULT 0 CHECK (streak_days >= 0),
    streak_freeze_active BOOLEAN NOT NULL DEFAULT FALSE,
    last_activity_date DATE,
    equipped_state JSONB NOT NULL DEFAULT '{
        "skin": "skin_default_runner",
        "base_decor": "decor_cyber_terminal_v1",
        "pet": null
    }'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- 2. spheres — Кастомные сферы развития пользователя (до 4 штук)
-- Базово: 🧠 Мозг, 💪 Тело, ⚡ Энергия, 🎨 Душа
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.spheres (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    code TEXT NOT NULL DEFAULT 'custom', -- 'brain' | 'body' | 'energy' | 'soul'
    name TEXT NOT NULL,
    icon TEXT NOT NULL DEFAULT '⚡',
    level INTEGER NOT NULL DEFAULT 1 CHECK (level >= 1),
    current_xp INTEGER NOT NULL DEFAULT 0 CHECK (current_xp >= 0),
    sort_order SMALLINT NOT NULL DEFAULT 0 CHECK (sort_order BETWEEN 0 AND 3),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, sort_order)
);

-- Триггер ограничения: максимум 4 сферы развития на одного игрока
CREATE OR REPLACE FUNCTION public.enforce_max_four_spheres()
RETURNS TRIGGER AS $$
DECLARE
    sphere_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO sphere_count
    FROM public.spheres
    WHERE user_id = NEW.user_id;

    IF TG_OP = 'INSERT' AND sphere_count >= 4 THEN
        RAISE EXCEPTION 'У игрока может быть максимум 4 сферы развития (уже создано: %)', sphere_count;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_enforce_max_four_spheres ON public.spheres;
CREATE TRIGGER trg_enforce_max_four_spheres
BEFORE INSERT ON public.spheres
FOR EACH ROW EXECUTE FUNCTION public.enforce_max_four_spheres();

-- ----------------------------------------------------------------------------
-- 3. quests — Активные привычки/квесты
-- Сложность: easy (1.0), normal (1.5), hardcore (2.5)
-- Тип трекинга: manual (ручной/фото-пруф), timer (рейд-таймер фокуса), health_api (Apple Health / Google Fit)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.quests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    sphere_id UUID NOT NULL REFERENCES public.spheres(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    raw_input TEXT,
    description TEXT,
    difficulty TEXT NOT NULL DEFAULT 'normal' CHECK (difficulty IN ('easy', 'normal', 'hardcore')),
    tracking_type TEXT NOT NULL DEFAULT 'manual' CHECK (tracking_type IN ('manual', 'timer', 'health_api')),
    target_value NUMERIC(10, 2) NOT NULL DEFAULT 1.0 CHECK (target_value > 0),
    target_unit TEXT NOT NULL DEFAULT 'раз',
    frequency TEXT NOT NULL DEFAULT 'daily', -- 'daily' | '3x_week' | 'weekly' | 'once'
    health_metric_key TEXT,                  -- 'distance_km' | 'steps' | 'workout_minutes' | null
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- 4. activity_logs — История выполнений с зафиксированным опытом и золотом
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.activity_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    quest_id UUID REFERENCES public.quests(id) ON DELETE SET NULL,
    sphere_id UUID REFERENCES public.spheres(id) ON DELETE SET NULL,
    actual_value NUMERIC(10, 2) NOT NULL DEFAULT 1.0,
    target_value NUMERIC(10, 2) NOT NULL DEFAULT 1.0,
    difficulty TEXT NOT NULL,
    streak_multiplier NUMERIC(4, 2) NOT NULL DEFAULT 1.0,
    overachieve_multiplier NUMERIC(4, 2) NOT NULL DEFAULT 1.0,
    xp_earned INTEGER NOT NULL CHECK (xp_earned >= 0),
    gold_earned INTEGER NOT NULL CHECK (gold_earned >= 0),
    proof_url TEXT,
    completed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- 5. shop_items — Каталог внутриигровых предметов
-- Только внутриигровые награды: скины, декор базы, питомцы, бустеры
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.shop_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    category TEXT NOT NULL CHECK (category IN ('skin', 'base_decor', 'pet', 'booster')),
    price_gold INTEGER NOT NULL CHECK (price_gold >= 0),
    rive_asset_key TEXT NOT NULL,
    icon TEXT NOT NULL DEFAULT '🎁',
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- 6. user_inventory — Купленные пользователем предметы
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_inventory (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    item_id UUID NOT NULL REFERENCES public.shop_items(id) ON DELETE CASCADE,
    quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity >= 0),
    is_equipped BOOLEAN NOT NULL DEFAULT FALSE,
    acquired_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, item_id)
);

-- ----------------------------------------------------------------------------
-- Индексы для быстрых выборок
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_spheres_user_id ON public.spheres(user_id);
CREATE INDEX IF NOT EXISTS idx_quests_user_active ON public.quests(user_id, is_active);
CREATE INDEX IF NOT EXISTS idx_activity_logs_user_date ON public.activity_logs(user_id, completed_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_inventory_user_id ON public.user_inventory(user_id);

-- ----------------------------------------------------------------------------
-- Row Level Security (RLS) для Supabase Auth
-- ----------------------------------------------------------------------------
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.spheres ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shop_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_inventory ENABLE ROW LEVEL SECURITY;

-- Политики доступа: пользователь управляет только своими данными, магазин доступен всем на чтение
CREATE POLICY "Users can view and update own profile"
    ON public.users FOR ALL USING (auth.uid() = id);

CREATE POLICY "Users can manage own spheres"
    ON public.spheres FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own quests"
    ON public.quests FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own activity logs"
    ON public.activity_logs FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Anyone can view shop items"
    ON public.shop_items FOR SELECT USING (true);

CREATE POLICY "Users can manage own inventory"
    ON public.user_inventory FOR ALL USING (auth.uid() = user_id);
