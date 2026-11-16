from __future__ import annotations

from typing import List
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.models.schemas import (
    ArenaBossSchema,
    ArenaClaimVictoryRequest,
    ArenaClaimVictoryResponse,
    PresetOnboardingRequest,
    QuestAIParseRequest,
    QuestAIStructuredOutput,
    QuestCompleteRequest,
    QuestCompleteResponse,
    QuestCreateRequest,
    QuestSchema,
    ShopBuyRequest,
    ShopEquipRequest,
    ShopItemSchema,
    SphereSchema,
    SphereUpdateRequest,
    UserProfileSchema,
)
from app.services.ai_quest_parser import parse_quest_with_ai
from app.services.repository import repo

app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    description=(
        "RPG_LIFE — Геймифицированный трекер реальной жизни. "
        "Однострочное создание квестов через Gemini 2.5 Flash (Structured Outputs), "
        "4 кастомные сферы, математическая модель прогрессии и внутриигровой магазин."
    ),
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health_check() -> dict:
    return {
        "status": "ok",
        "service": settings.app_name,
        "version": settings.app_version,
        "gemini_model": settings.gemini_model,
        "gemini_configured": settings.has_gemini,
        "supabase_configured": settings.has_supabase,
    }


@app.get("/api/v1/profile/{user_id}", response_model=UserProfileSchema)
def get_user_profile(user_id: str) -> UserProfileSchema:
    return repo.get_profile(user_id)


@app.post("/api/v1/onboarding/preset", response_model=UserProfileSchema)
def apply_onboarding_preset(payload: PresetOnboardingRequest) -> UserProfileSchema:
    """Настройка стартового пресета («Студент», «Спортсмен», «Кибер-Кочевник») за 1 клик."""
    return repo.initialize_user_with_preset(
        user_id=payload.user_id,
        username=payload.username,
        preset=payload.preset,
    )


@app.put("/api/v1/spheres/{sphere_id}", response_model=SphereSchema)
def update_sphere_customization(
    sphere_id: str,
    payload: SphereUpdateRequest,
    user_id: str = Query(default="demo-user-001"),
) -> SphereSchema:
    """Кастомизация названия и иконки одной из 4 сфер игрока."""
    try:
        return repo.update_sphere(
            user_id=user_id,
            sphere_id=sphere_id,
            name=payload.name,
            icon=payload.icon,
        )
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@app.post("/api/v1/quests/parse-ai", response_model=QuestAIStructuredOutput)
def parse_quest_via_ai(payload: QuestAIParseRequest) -> QuestAIStructuredOutput:
    """
    Парсинг однострочного желания пользователя (например, «Бегать по 3 км три раза в неделю»)
    в структурированный квест через Gemini 2.5 Flash (Structured Outputs).
    """
    return parse_quest_with_ai(
        prompt=payload.prompt,
        override_difficulty=payload.override_difficulty,
    )


@app.post("/api/v1/quests/create-from-ai", response_model=QuestSchema)
def create_quest_from_ai_prompt(payload: QuestAIParseRequest) -> QuestSchema:
    """
    Создание квеста за 10 секунд: принимает одну строку текста и опциональную кнопку сложности,
    вызывает ИИ-парсер и сразу сохраняет готовый квест в профиль игрока.
    """
    parsed = parse_quest_with_ai(
        prompt=payload.prompt,
        override_difficulty=payload.override_difficulty,
    )
    create_req = QuestCreateRequest(
        user_id=payload.user_id,
        sphere_code=parsed.sphere_code,
        title=parsed.title,
        raw_input=payload.prompt,
        description=parsed.description,
        difficulty=parsed.difficulty,
        tracking_type=parsed.tracking_type,
        target_value=parsed.target_value,
        target_unit=parsed.target_unit,
        frequency=parsed.frequency,
        health_metric_key=parsed.health_metric_key,
    )
    return repo.create_quest(create_req)


@app.post("/api/v1/quests", response_model=QuestSchema)
def create_quest(payload: QuestCreateRequest) -> QuestSchema:
    return repo.create_quest(payload)


@app.post("/api/v1/quests/{quest_id}/complete", response_model=QuestCompleteResponse)
def complete_quest(quest_id: str, payload: QuestCompleteRequest) -> QuestCompleteResponse:
    """
    Завершение квеста (вручную, по окончании рейд-таймера или по данным Apple Health / Google Fit).
    Рассчитывает XP_action = 100 * D * M_streak * M_overachieve и Gold = floor(XP_action * 0.2).
    """
    try:
        return repo.complete_quest(
            user_id=payload.user_id,
            quest_id=quest_id,
            actual_value=payload.actual_value,
            proof_url=payload.proof_url,
        )
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@app.get("/api/v1/shop/items", response_model=List[ShopItemSchema])
def get_shop_catalog() -> List[ShopItemSchema]:
    """Каталог внутриигровых предметов (скины, апгрейды базы, питомцы, щит стрика)."""
    return repo.list_shop_items()


@app.post("/api/v1/shop/buy", response_model=UserProfileSchema)
def buy_shop_item(payload: ShopBuyRequest) -> UserProfileSchema:
    try:
        return repo.buy_item(user_id=payload.user_id, item_code=payload.item_code)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@app.post("/api/v1/shop/equip", response_model=UserProfileSchema)
def equip_inventory_item(payload: ShopEquipRequest) -> UserProfileSchema:
    try:
        return repo.equip_item(user_id=payload.user_id, item_code=payload.item_code)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@app.get("/api/v1/arena/bosses", response_model=List[ArenaBossSchema])
def get_arena_bosses(user_id: str = Query(default="demo-user-001")) -> List[ArenaBossSchema]:
    """
    Список этажей и боссов «Нейро-Арены / Башни Боссов» с рекомендуемым уровнем героя,
    боевой мощью и наградой (золото, XP, эксклюзивные трофеи).
    """
    return repo.list_arena_bosses(user_id=user_id)


@app.post("/api/v1/arena/claim-victory", response_model=ArenaClaimVictoryResponse)
def claim_arena_victory(payload: ArenaClaimVictoryRequest) -> ArenaClaimVictoryResponse:
    """
    Фиксация победы над боссом этажа в мини-игре (Bullet-Hell / Reflex Parry)
    с выдачей награды (XP, золота и трофея) в профиль героя.
    """
    try:
        return repo.claim_boss_victory(
            user_id=payload.user_id,
            boss_code=payload.boss_code,
            remaining_hp_percent=payload.remaining_hp_percent,
        )
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
