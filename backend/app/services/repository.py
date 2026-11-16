from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import Dict, List, Optional

from app.models.schemas import (
    ActivityLogSchema,
    EquippedState,
    InventoryItemSchema,
    PresetType,
    QuestCompleteResponse,
    QuestCreateRequest,
    QuestSchema,
    ShopItemSchema,
    SphereCodeType,
    SphereSchema,
    UserProfileSchema,
)
from app.services.progression import (
    apply_xp_and_level_up,
    compute_action_reward,
    compute_xp_next,
)

DEFAULT_SPHERES_TEMPLATE = [
    {"code": "brain", "name": "Мозг", "icon": "🧠", "sort_order": 0},
    {"code": "body", "name": "Тело", "icon": "💪", "sort_order": 1},
    {"code": "energy", "name": "Энергия", "icon": "⚡", "sort_order": 2},
    {"code": "soul", "name": "Душа", "icon": "🎨", "sort_order": 3},
]

PRESET_QUESTS_TEMPLATES = {
    "student": [
        {
            "sphere_code": "brain",
            "title": "Нейро-рейд: Глубокий фокус над учебой",
            "description": "Встроенный игровой рейд-таймер фокуса без отвлечений.",
            "difficulty": "normal",
            "tracking_type": "timer",
            "target_value": 25.0,
            "target_unit": "мин",
            "frequency": "daily",
            "health_metric_key": None,
        },
        {
            "sphere_code": "body",
            "title": "Кибер-атлетика: 8000 шагов за день",
            "description": "Авто-синхронизация с Apple Health / Google Fit.",
            "difficulty": "normal",
            "tracking_type": "health_api",
            "target_value": 8000.0,
            "target_unit": "шагов",
            "frequency": "daily",
            "health_metric_key": "steps",
        },
        {
            "sphere_code": "energy",
            "title": "Энерго-контур: Стакан воды и зарядка утром",
            "description": "Быстрая отметка выполнения в 1 тап.",
            "difficulty": "easy",
            "tracking_type": "manual",
            "target_value": 1.0,
            "target_unit": "раз",
            "frequency": "daily",
            "health_metric_key": None,
        },
    ],
    "athlete": [
        {
            "sphere_code": "body",
            "title": "Кибер-атлетика: Бег 3 км в темпе",
            "description": "Авто-синхронизация дистанции через Apple Health / Google Fit.",
            "difficulty": "normal",
            "tracking_type": "health_api",
            "target_value": 3.0,
            "target_unit": "км",
            "frequency": "3x_week",
            "health_metric_key": "distance_km",
        },
        {
            "sphere_code": "body",
            "title": "Силовой протокол: Интенсивная тренировка",
            "description": "Считывание тренировочных минут из трекера здоровья.",
            "difficulty": "hardcore",
            "tracking_type": "health_api",
            "target_value": 45.0,
            "target_unit": "мин",
            "frequency": "3x_week",
            "health_metric_key": "workout_minutes",
        },
        {
            "sphere_code": "energy",
            "title": "Регенерация: Растяжка и восстановление",
            "description": "Короткий таймер восстановления мышц.",
            "difficulty": "easy",
            "tracking_type": "timer",
            "target_value": 15.0,
            "target_unit": "мин",
            "frequency": "daily",
            "health_metric_key": None,
        },
    ],
    "cyber_nomad": [
        {
            "sphere_code": "brain",
            "title": "Нейро-рейд: Спринт глубокой работы",
            "description": "Рейд-таймер чистого кодинга или проектирования.",
            "difficulty": "hardcore",
            "tracking_type": "timer",
            "target_value": 50.0,
            "target_unit": "мин",
            "frequency": "daily",
            "health_metric_key": None,
        },
        {
            "sphere_code": "soul",
            "title": "Синт-гармония: Цифровой детокс / Медитация",
            "description": "Перезагрузка нейроинтерфейса без экранов.",
            "difficulty": "easy",
            "tracking_type": "timer",
            "target_value": 10.0,
            "target_unit": "мин",
            "frequency": "daily",
            "health_metric_key": None,
        },
        {
            "sphere_code": "body",
            "title": "Кибер-атлетика: Вечерняя пробежка 3 км",
            "description": "Авто-синхронизация с Apple Health / Google Fit.",
            "difficulty": "normal",
            "tracking_type": "health_api",
            "target_value": 3.0,
            "target_unit": "км",
            "frequency": "3x_week",
            "health_metric_key": "distance_km",
        },
    ],
}

INITIAL_SHOP_CATALOG: List[ShopItemSchema] = [
    ShopItemSchema(
        id="item-skin-001",
        code="skin_neon_samurai",
        name="Экзокостюм «Неоновый Самурай»",
        description="Кибернетическая броня с голографической катаной. Подсвечивается при закрытии Хардкор-квестов.",
        category="skin",
        price_gold=120,
        rive_asset_key="skin_neon_samurai",
        icon="🥷",
        metadata={"rarity": "epic", "glow_color": "#00F5D4"},
    ),
    ShopItemSchema(
        id="item-skin-002",
        code="skin_netrunner_hoodie",
        name="Мантия Нетраннера",
        description="Стильный плащ с нейроинтерфейсом для глубоких рейдов фокуса.",
        category="skin",
        price_gold=80,
        rive_asset_key="skin_netrunner_hoodie",
        icon="🧥",
        metadata={"rarity": "rare", "glow_color": "#9B5DE5"},
    ),
    ShopItemSchema(
        id="item-decor-001",
        code="decor_holo_monolith",
        name="Голографический Терминал v2.0",
        description="Превращает рабочий стол базы в трехмерную тактическую станцию с живыми графиками сфер.",
        category="base_decor",
        price_gold=150,
        rive_asset_key="decor_holo_monolith",
        icon="🖥️",
        metadata={"rarity": "epic", "slot": "workstation"},
    ),
    ShopItemSchema(
        id="item-decor-002",
        code="decor_bonsai_synth",
        name="Синт-Бонсай «Дзен-Контур»",
        description="Биолюминесцентное дерево в углу базы, которое расцветает по мере роста сферы Души.",
        category="base_decor",
        price_gold=90,
        rive_asset_key="decor_bonsai_synth",
        icon="🌳",
        metadata={"rarity": "rare", "slot": "ambient"},
    ),
    ShopItemSchema(
        id="item-pet-001",
        code="pet_cyber_fox",
        name="Кибер-Лис «Кицунэ-09»",
        description="Дрон-компаньон, который спит у терминала во время таймера фокуса и празднует твой левел-ап.",
        category="pet",
        price_gold=200,
        rive_asset_key="pet_cyber_fox",
        icon="🦊",
        metadata={"rarity": "legendary"},
    ),
    ShopItemSchema(
        id="item-pet-002",
        code="pet_bot_owl",
        name="Меха-Сова «Афина»",
        description="Спутник исследователя. Реагирует анимацией крыльев на выполнение учебных квестов.",
        category="pet",
        price_gold=140,
        rive_asset_key="pet_bot_owl",
        icon="🦉",
        metadata={"rarity": "epic"},
    ),
    ShopItemSchema(
        id="item-booster-001",
        code="booster_streak_freeze",
        name="Щит заморозки стрика",
        description="Защищает твой стрик (бонус +5%/день) на 1 пропущенный день без потери множителя.",
        category="booster",
        price_gold=60,
        rive_asset_key="booster_streak_freeze",
        icon="🛡️",
        metadata={"consumable": True},
    ),
]


class RPGRepository:
    """Хранилище 6 ключевых сущностей RPG_LIFE с поддержкой пресетов и игровой экономики."""

    def __init__(self) -> None:
        self.users: Dict[str, dict] = {}
        self.spheres: Dict[str, List[SphereSchema]] = {}
        self.quests: Dict[str, List[QuestSchema]] = {}
        self.activity_logs: Dict[str, List[ActivityLogSchema]] = {}
        self.shop_items: Dict[str, ShopItemSchema] = {
            item.code: item for item in INITIAL_SHOP_CATALOG
        }
        self.user_inventory: Dict[str, List[InventoryItemSchema]] = {}

        # Инициализируем демо-героя по умолчанию
        self.initialize_user_with_preset(
            user_id="demo-user-001",
            username="Нео-Искатель",
            preset="student",
        )

    def _enrich_quest_rewards(self, quest: QuestSchema, streak_days: int) -> QuestSchema:
        reward = compute_action_reward(
            difficulty=quest.difficulty,
            streak_days=streak_days,
            actual_value=quest.target_value,
            target_value=quest.target_value,
        )
        quest.estimated_xp = reward.xp_action
        quest.estimated_gold = reward.gold
        return quest

    def initialize_user_with_preset(
        self,
        user_id: str,
        username: str = "Кибер-Путник",
        preset: PresetType = "student",
    ) -> UserProfileSchema:
        """Создает или переключает стартовый пресет игрока с 4 базовыми сферами."""
        existing = self.users.get(user_id)
        if not existing:
            self.users[user_id] = {
                "id": user_id,
                "username": username,
                "hero_preset": preset,
                "level": 1,
                "current_xp": 0,
                "gold": 120,
                "streak_days": 3,
                "streak_freeze_active": False,
                "equipped_state": EquippedState(),
            }
        else:
            existing["username"] = username
            existing["hero_preset"] = preset

        if user_id not in self.spheres or not self.spheres[user_id]:
            user_spheres: List[SphereSchema] = []
            for item in DEFAULT_SPHERES_TEMPLATE:
                user_spheres.append(
                    SphereSchema(
                        id=f"sphere-{user_id}-{item['code']}",
                        user_id=user_id,
                        code=item["code"],  # type: ignore[arg-type]
                        name=item["name"],
                        icon=item["icon"],
                        level=1,
                        current_xp=0,
                        xp_next=compute_xp_next(1),
                        sort_order=item["sort_order"],
                    )
                )
            self.spheres[user_id] = user_spheres

        # Заполняем стартовые квесты выбранного пресета
        sphere_by_code = {s.code: s for s in self.spheres[user_id]}
        preset_quests: List[QuestSchema] = []
        for idx, q_tpl in enumerate(PRESET_QUESTS_TEMPLATES.get(preset, PRESET_QUESTS_TEMPLATES["student"])):
            sp = sphere_by_code[q_tpl["sphere_code"]]
            quest = QuestSchema(
                id=f"quest-{preset}-{idx + 1}",
                user_id=user_id,
                sphere_id=sp.id,
                sphere_code=sp.code,
                sphere_name=sp.name,
                sphere_icon=sp.icon,
                title=q_tpl["title"],
                raw_input=q_tpl["title"],
                description=q_tpl["description"],
                difficulty=q_tpl["difficulty"],
                tracking_type=q_tpl["tracking_type"],
                target_value=q_tpl["target_value"],
                target_unit=q_tpl["target_unit"],
                frequency=q_tpl["frequency"],
                health_metric_key=q_tpl["health_metric_key"],
                is_active=True,
            )
            preset_quests.append(
                self._enrich_quest_rewards(quest, self.users[user_id]["streak_days"])
            )

        self.quests[user_id] = preset_quests
        self.user_inventory.setdefault(user_id, [])
        self.activity_logs.setdefault(user_id, [])
        return self.get_profile(user_id)

    def get_profile(self, user_id: str) -> UserProfileSchema:
        if user_id not in self.users:
            return self.initialize_user_with_preset(user_id=user_id)

        u = self.users[user_id]
        spheres = self.spheres.get(user_id, [])
        for s in spheres:
            s.xp_next = compute_xp_next(s.level)

        active_quests = [
            self._enrich_quest_rewards(q, u["streak_days"])
            for q in self.quests.get(user_id, [])
            if q.is_active
        ]

        return UserProfileSchema(
            id=u["id"],
            username=u["username"],
            hero_preset=u["hero_preset"],
            level=u["level"],
            current_xp=u["current_xp"],
            xp_next=compute_xp_next(u["level"]),
            gold=u["gold"],
            streak_days=u["streak_days"],
            streak_freeze_active=u["streak_freeze_active"],
            equipped_state=u["equipped_state"],
            spheres=spheres,
            active_quests=active_quests,
            inventory=self.user_inventory.get(user_id, []),
            recent_logs=self.activity_logs.get(user_id, [])[:15],
        )

    def update_sphere(self, user_id: str, sphere_id: str, name: str, icon: str) -> SphereSchema:
        profile = self.get_profile(user_id)
        for sp in profile.spheres:
            if sp.id == sphere_id:
                sp.name = name.strip()
                sp.icon = icon.strip()
                # Обновляем отображение в квестах этой сферы
                for q in self.quests.get(user_id, []):
                    if q.sphere_id == sphere_id:
                        q.sphere_name = sp.name
                        q.sphere_icon = sp.icon
                return sp
        raise ValueError(f"Сфера {sphere_id} не найдена")

    def create_quest(self, req: QuestCreateRequest) -> QuestSchema:
        profile = self.get_profile(req.user_id)
        target_sphere: Optional[SphereSchema] = None

        if req.sphere_id:
            target_sphere = next((s for s in profile.spheres if s.id == req.sphere_id), None)
        if target_sphere is None:
            target_sphere = next(
                (s for s in profile.spheres if s.code == req.sphere_code),
                profile.spheres[0],
            )

        new_quest = QuestSchema(
            id=f"quest-{uuid.uuid4().hex[:8]}",
            user_id=req.user_id,
            sphere_id=target_sphere.id,
            sphere_code=target_sphere.code,
            sphere_name=target_sphere.name,
            sphere_icon=target_sphere.icon,
            title=req.title,
            raw_input=req.raw_input or req.title,
            description=req.description or "",
            difficulty=req.difficulty,
            tracking_type=req.tracking_type,
            target_value=req.target_value,
            target_unit=req.target_unit,
            frequency=req.frequency,
            health_metric_key=req.health_metric_key,
            is_active=True,
        )
        new_quest = self._enrich_quest_rewards(new_quest, profile.streak_days)
        self.quests.setdefault(req.user_id, []).insert(0, new_quest)
        return new_quest

    def complete_quest(
        self,
        user_id: str,
        quest_id: str,
        actual_value: Optional[float] = None,
        proof_url: Optional[str] = None,
    ) -> QuestCompleteResponse:
        profile = self.get_profile(user_id)
        user_quests = self.quests.get(user_id, [])
        quest = next((q for q in user_quests if q.id == quest_id), None)
        if quest is None:
            raise ValueError(f"Квест {quest_id} не найден")

        effective_actual = actual_value if actual_value is not None else quest.target_value
        u = self.users[user_id]

        reward = compute_action_reward(
            difficulty=quest.difficulty,
            streak_days=u["streak_days"],
            actual_value=effective_actual,
            target_value=quest.target_value,
        )

        # Прокачка героя
        new_hero_lvl, new_hero_xp, hero_leveled_up = apply_xp_and_level_up(
            current_level=u["level"],
            current_xp=u["current_xp"],
            added_xp=reward.xp_action,
        )
        u["level"] = new_hero_lvl
        u["current_xp"] = new_hero_xp
        u["gold"] += reward.gold

        # Прокачка соответствующей сферы
        sphere_leveled_up = False
        new_sphere_lvl = 1
        for sp in self.spheres.get(user_id, []):
            if sp.id == quest.sphere_id:
                sp_lvl, sp_xp, sp_up = apply_xp_and_level_up(
                    current_level=sp.level,
                    current_xp=sp.current_xp,
                    added_xp=reward.xp_action,
                )
                sp.level = sp_lvl
                sp.current_xp = sp_xp
                sp.xp_next = compute_xp_next(sp_lvl)
                sphere_leveled_up = sp_up
                new_sphere_lvl = sp_lvl
                break

        log_entry = ActivityLogSchema(
            id=f"log-{uuid.uuid4().hex[:8]}",
            user_id=user_id,
            quest_id=quest.id,
            sphere_id=quest.sphere_id,
            quest_title=quest.title,
            actual_value=effective_actual,
            target_value=quest.target_value,
            difficulty=quest.difficulty,
            streak_multiplier=reward.streak_multiplier,
            overachieve_multiplier=reward.overachieve_multiplier,
            xp_earned=reward.xp_action,
            gold_earned=reward.gold,
            proof_url=proof_url,
            completed_at=datetime.now(timezone.utc).isoformat(),
        )
        self.activity_logs.setdefault(user_id, []).insert(0, log_entry)

        updated_profile = self.get_profile(user_id)
        return QuestCompleteResponse(
            log=log_entry,
            xp_earned=reward.xp_action,
            gold_earned=reward.gold,
            hero_leveled_up=hero_leveled_up,
            new_hero_level=new_hero_lvl,
            sphere_leveled_up=sphere_leveled_up,
            new_sphere_level=new_sphere_lvl,
            profile=updated_profile,
        )

    def list_shop_items(self) -> List[ShopItemSchema]:
        return list(self.shop_items.values())

    def buy_item(self, user_id: str, item_code: str) -> UserProfileSchema:
        self.get_profile(user_id)
        item = self.shop_items.get(item_code)
        if item is None:
            raise ValueError(f"Предмет {item_code} не найден в магазине")

        u = self.users[user_id]
        if u["gold"] < item.price_gold:
            raise ValueError(
                f"Недостаточно золота: нужно {item.price_gold}, у героя {u['gold']}"
            )

        inv = self.user_inventory.setdefault(user_id, [])
        existing = next((entry for entry in inv if entry.item.code == item_code), None)

        if item.category != "booster" and existing is not None:
            raise ValueError("Этот косметический предмет уже куплен")

        u["gold"] -= item.price_gold

        if item.category == "booster" and item.code == "booster_streak_freeze":
            u["streak_freeze_active"] = True

        if existing is not None:
            existing.quantity += 1
        else:
            inv.append(
                InventoryItemSchema(
                    id=f"inv-{uuid.uuid4().hex[:8]}",
                    user_id=user_id,
                    item_id=item.id,
                    item=item,
                    quantity=1,
                    is_equipped=(item.category != "booster"),
                )
            )
            if item.category != "booster":
                self.equip_item(user_id, item_code)

        return self.get_profile(user_id)

    def equip_item(self, user_id: str, item_code: str) -> UserProfileSchema:
        self.get_profile(user_id)
        inv = self.user_inventory.get(user_id, [])
        target = next((entry for entry in inv if entry.item.code == item_code), None)
        if target is None:
            raise ValueError("Предмет не найден в инвентаре героя")

        category = target.item.category
        for entry in inv:
            if entry.item.category == category:
                entry.is_equipped = entry.item.code == item_code

        eq: EquippedState = self.users[user_id]["equipped_state"]
        if category == "skin":
            eq.skin = target.item.rive_asset_key
        elif category == "base_decor":
            eq.base_decor = target.item.rive_asset_key
        elif category == "pet":
            eq.pet = target.item.rive_asset_key

        return self.get_profile(user_id)


repo = RPGRepository()
