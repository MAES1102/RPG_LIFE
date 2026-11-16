from __future__ import annotations

from typing import Any, Dict, List, Literal, Optional
from pydantic import BaseModel, Field

DifficultyType = Literal["easy", "normal", "hardcore"]
TrackingType = Literal["manual", "timer", "health_api"]
SphereCodeType = Literal["brain", "body", "energy", "soul"]
ItemCategoryType = Literal["skin", "base_decor", "pet", "booster"]
PresetType = Literal["student", "athlete", "cyber_nomad"]


class EquippedState(BaseModel):
    skin: str = "skin_default_runner"
    base_decor: str = "decor_cyber_terminal_v1"
    pet: Optional[str] = None


class SphereSchema(BaseModel):
    id: str
    user_id: str
    code: SphereCodeType
    name: str
    icon: str
    level: int = 1
    current_xp: int = 0
    xp_next: int = 500
    sort_order: int = 0


class SphereUpdateRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=24, description="Кастомное название сферы")
    icon: str = Field(..., min_length=1, max_length=8, description="Эмодзи или иконка сферы")


class QuestAIStructuredOutput(BaseModel):
    """Схема Structured Output для Gemini API (gemini-2.5-flash)."""

    title: str = Field(
        ...,
        description="Короткое игровое название квеста в стиле RPG (например, 'Спринт Неонового Бегуна: 3 км')",
    )
    description: str = Field(
        ...,
        description="Краткое мотивирующее описание задачи на 1 предложение без перегруза",
    )
    sphere_code: SphereCodeType = Field(
        ...,
        description="Сфера развития: brain (Мозг/учеба), body (Тело/спорт), energy (Энергия/режим/быт), soul (Душа/творчество/хобби)",
    )
    difficulty: DifficultyType = Field(
        ...,
        description="Сложность квеста: easy (1.0), normal (1.5), hardcore (2.5)",
    )
    tracking_type: TrackingType = Field(
        ...,
        description="Способ трекинга: health_api (бег, шаги, тренировки), timer (учеба, фокус, чтение по времени), manual (разовые дела, привычки)",
    )
    target_value: float = Field(
        ...,
        gt=0,
        description="Числовое целевое значение за одно выполнение (например, 3.0 для 3 км или 25 для 25 минут таймера, или 1 для разового действия)",
    )
    target_unit: str = Field(
        ...,
        description="Единица измерения (например: 'км', 'мин', 'шагов', 'раз', 'стр')",
    )
    frequency: str = Field(
        default="daily",
        description="Частота выполнения: 'daily', '3x_week', 'weekly', 'once'",
    )
    health_metric_key: Optional[str] = Field(
        default=None,
        description="Для health_api: 'distance_km', 'steps', 'workout_minutes' или null",
    )


class QuestAIParseRequest(BaseModel):
    user_id: str = "demo-user-001"
    prompt: str = Field(
        ...,
        min_length=2,
        max_length=280,
        description="Желание пользователя одной строкой, например: 'Бегать по 3 км три раза в неделю'",
    )
    override_difficulty: Optional[DifficultyType] = Field(
        default=None,
        description="Опциональный выбор одной из 3 кнопок сложности: easy / normal / hardcore",
    )


class QuestCreateRequest(BaseModel):
    user_id: str = "demo-user-001"
    sphere_id: Optional[str] = None
    sphere_code: SphereCodeType = "body"
    title: str
    raw_input: Optional[str] = None
    description: Optional[str] = ""
    difficulty: DifficultyType = "normal"
    tracking_type: TrackingType = "manual"
    target_value: float = 1.0
    target_unit: str = "раз"
    frequency: str = "daily"
    health_metric_key: Optional[str] = None


class QuestSchema(BaseModel):
    id: str
    user_id: str
    sphere_id: str
    sphere_code: SphereCodeType
    sphere_name: str
    sphere_icon: str
    title: str
    raw_input: Optional[str] = None
    description: Optional[str] = ""
    difficulty: DifficultyType
    tracking_type: TrackingType
    target_value: float
    target_unit: str
    frequency: str
    health_metric_key: Optional[str] = None
    is_active: bool = True
    estimated_xp: int = 100
    estimated_gold: int = 20


class QuestCompleteRequest(BaseModel):
    user_id: str = "demo-user-001"
    actual_value: Optional[float] = Field(
        default=None,
        gt=0,
        description="Фактическое выполнение (например, пробежал 4 км вместо 3 км или 30 мин таймера). Если не передано — равно target_value.",
    )
    proof_url: Optional[str] = Field(
        default=None,
        description="Опциональная ссылка на фото-пруф для manual квестов",
    )


class ActivityLogSchema(BaseModel):
    id: str
    user_id: str
    quest_id: Optional[str]
    sphere_id: Optional[str]
    quest_title: str
    actual_value: float
    target_value: float
    difficulty: DifficultyType
    streak_multiplier: float
    overachieve_multiplier: float
    xp_earned: int
    gold_earned: int
    proof_url: Optional[str] = None
    completed_at: str


class ShopItemSchema(BaseModel):
    id: str
    code: str
    name: str
    description: str
    category: ItemCategoryType
    price_gold: int
    rive_asset_key: str
    icon: str
    metadata: Dict[str, Any] = Field(default_factory=dict)


class InventoryItemSchema(BaseModel):
    id: str
    user_id: str
    item_id: str
    item: ShopItemSchema
    quantity: int = 1
    is_equipped: bool = False


class UserProfileSchema(BaseModel):
    id: str
    username: str
    hero_preset: PresetType
    level: int
    current_xp: int
    xp_next: int
    gold: int
    streak_days: int
    streak_freeze_active: bool
    equipped_state: EquippedState
    spheres: List[SphereSchema]
    active_quests: List[QuestSchema]
    inventory: List[InventoryItemSchema]
    recent_logs: List[ActivityLogSchema]


class QuestCompleteResponse(BaseModel):
    log: ActivityLogSchema
    xp_earned: int
    gold_earned: int
    hero_leveled_up: bool
    new_hero_level: int
    sphere_leveled_up: bool
    new_sphere_level: int
    profile: UserProfileSchema


class PresetOnboardingRequest(BaseModel):
    user_id: str = "demo-user-001"
    username: str = "Кибер-Путник"
    preset: PresetType = "student"


class ShopBuyRequest(BaseModel):
    user_id: str = "demo-user-001"
    item_code: str


class ShopEquipRequest(BaseModel):
    user_id: str = "demo-user-001"
    item_code: str
