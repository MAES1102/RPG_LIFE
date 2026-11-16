from __future__ import annotations

import re
from typing import Optional

from app.config import settings
from app.models.schemas import (
    DifficultyType,
    QuestAIStructuredOutput,
    SphereCodeType,
    TrackingType,
)

SYSTEM_PROMPT = """Ты — ИИ-гейммастер приложения RPG_LIFE (геймифицированный трекер реальной жизни в стиле киберпанк-RPG).
Пользователь вводит желание одной строкой (например: "Бегать по 3 км три раза в неделю" или "Учить алгоритмы по 45 минут").
Твоя задача — за 1 шаг без лишних вопросов распарсить строку в структурированный квест:
1. sphere_code — выбери ровно одну из 4 базовых сфер:
   - "brain" (🧠 Мозг: учеба, книги, программирование, языки, аналитика)
   - "body" (💪 Тело: бег, зал, шаги, отжимания, плавание, спорт)
   - "energy" (⚡ Энергия: сон, вода, режим дня, прогулки, уборка, рутина)
   - "soul" (🎨 Душа: музыка, рисование, медитация, дневник, хобби, творчество)
2. difficulty — оцени сложность: "easy" (простое действие до 15 мин), "normal" (стандартная тренировка/сессия 20-45 мин или 2-5 км), "hardcore" (интенсивный вызов: >5 км, >60 мин фокуса, тяжелая тренировка).
3. tracking_type — определи автоматический способ считывания прогресса:
   - "health_api" — если активность считывается через Apple Health / Google Fit (бег, ходьба, шаги, километры, кардио, тренировка).
   - "timer" — если это фокус-сессия на время (учеба, работа, чтение, медитация в минутах/часах) через встроенный игровой рейд-таймер.
   - "manual" — если это разовая задача или привычка с ручной отметкой / фото-пруфом.
4. target_value и target_unit — выдели числовую цель за 1 выполнение (например, 3.0 и "км", 45 и "мин", 10000 и "шагов", 1 и "раз").
5. title — дай короткое драйвовое название в духе киберпанк/RPG (с сохранением сути задачи).
"""


def _heuristic_parse(
    prompt: str,
    override_difficulty: Optional[DifficultyType] = None,
) -> QuestAIStructuredOutput:
    """
    Детерминированный парсер (фоллбэк, если не задан GEMINI_API_KEY или нет сети),
    позволяющий протестировать однострочный ввод локально из коробки.
    """
    text = prompt.strip()
    lower = text.lower()

    # 1. Определение частоты
    frequency = "daily"
    if any(w in lower for w in ["три раза в неделю", "3 раза в неделю", "через день"]):
        frequency = "3x_week"
    elif any(w in lower for w in ["раз в неделю", "еженедельно", "по выходным"]):
        frequency = "weekly"
    elif any(w in lower for w in ["сегодня", "один раз", "разово"]):
        frequency = "once"

    # 2. Извлечение числа и единицы измерения
    target_value = 1.0
    target_unit = "раз"

    km_match = re.search(r"(\d+(?:[.,]\d+)?)\s*(?:км|километр)", lower)
    steps_match = re.search(r"(\d+(?:\s?\d+)*)\s*(?:шаг)", lower)
    min_match = re.search(r"(\d+(?:[.,]\d+)?)\s*(?:мин|минут)", lower)
    hour_match = re.search(r"(\d+(?:[.,]\d+)?)\s*(?:час|ч\b)", lower)
    page_match = re.search(r"(\d+)\s*(?:стр|страниц)", lower)

    if km_match:
        target_value = float(km_match.group(1).replace(",", "."))
        target_unit = "км"
    elif steps_match:
        target_value = float(steps_match.group(1).replace(" ", ""))
        target_unit = "шагов"
    elif min_match:
        target_value = float(min_match.group(1).replace(",", "."))
        target_unit = "мин"
    elif hour_match:
        target_value = float(hour_match.group(1).replace(",", ".")) * 60.0
        target_unit = "мин"
    elif page_match:
        target_value = float(page_match.group(1))
        target_unit = "стр"

    # 3. Определение сферы и типа трекинга
    sphere_code: SphereCodeType = "energy"
    tracking_type: TrackingType = "manual"
    health_metric_key: Optional[str] = None

    if any(
        w in lower
        for w in ["бег", "пробеж", "шаг", "тренир", "зал", "отжим", "подтяг", "плава", "вело", "спорт", "км"]
    ):
        sphere_code = "body"
        tracking_type = "health_api"
        if target_unit == "км" or "бег" in lower:
            health_metric_key = "distance_km"
        elif target_unit == "шагов" or "шаг" in lower:
            health_metric_key = "steps"
        else:
            health_metric_key = "workout_minutes"
    elif any(
        w in lower
        for w in ["учи", "учеб", "код", "програм", "чита", "книг", "алгоритм", "лекц", "курс", "английск", "язык", "фокус", "работ"]
    ):
        sphere_code = "brain"
        tracking_type = "timer" if target_unit == "мин" or "фокус" in lower or "учи" in lower else "manual"
        if tracking_type == "timer" and target_unit == "раз":
            target_value = 25.0
            target_unit = "мин"
    elif any(
        w in lower
        for w in ["рисов", "музык", "гитар", "медит", "дневник", "творч", "арт", "пиани", "дизайн"]
    ):
        sphere_code = "soul"
        tracking_type = "timer" if target_unit == "мин" or "медит" in lower else "manual"
    else:
        sphere_code = "energy"
        tracking_type = "timer" if target_unit == "мин" else "manual"

    # 4. Определение сложности
    difficulty: DifficultyType = "normal"
    if (
        (target_unit == "км" and target_value >= 5.0)
        or (target_unit == "мин" and target_value >= 60.0)
        or (target_unit == "шагов" and target_value >= 12000)
        or "хардкор" in lower
    ):
        difficulty = "hardcore"
    elif (
        (target_unit == "км" and target_value <= 1.5)
        or (target_unit == "мин" and target_value <= 15.0)
        or (target_unit == "раз" and target_value == 1.0 and tracking_type == "manual")
    ):
        difficulty = "easy"

    if override_difficulty is not None:
        difficulty = override_difficulty

    prefix_map = {
        "brain": "Нейро-рейд",
        "body": "Кибер-атлетика",
        "energy": "Энерго-контур",
        "soul": "Синт-гармония",
    }
    clean_title = text[0].upper() + text[1:] if text else "Новый квест"
    rpg_title = f"{prefix_map[sphere_code]}: {clean_title}"

    tracking_label = {
        "health_api": "Авто-синхронизация с Apple Health / Google Fit",
        "timer": "Встроенный игровой рейд-таймер фокуса",
        "manual": "Быстрая отметка выполнения в 1 тап",
    }[tracking_type]

    return QuestAIStructuredOutput(
        title=rpg_title[:72],
        description=f"{tracking_label}. Цель: {target_value:g} {target_unit}.",
        sphere_code=sphere_code,
        difficulty=difficulty,
        tracking_type=tracking_type,
        target_value=target_value,
        target_unit=target_unit,
        frequency=frequency,
        health_metric_key=health_metric_key,
    )


def parse_quest_with_ai(
    prompt: str,
    override_difficulty: Optional[DifficultyType] = None,
) -> QuestAIStructuredOutput:
    """
    Парсит однострочное желание пользователя через Gemini API (gemini-2.5-flash)
    с использованием Structured Outputs (Pydantic schema).
    При отсутствии ключа или ошибки сети прозрачно переключается на эвристический парсер.
    """
    if settings.has_gemini:
        try:
            from google import genai
            from google.genai import types

            client = genai.Client(api_key=settings.gemini_api_key)
            response = client.models.generate_content(
                model=settings.gemini_model,
                contents=f"Создай RPG-квест из запроса игрока: «{prompt}»",
                config=types.GenerateContentConfig(
                    system_instruction=SYSTEM_PROMPT,
                    response_mime_type="application/json",
                    response_schema=QuestAIStructuredOutput,
                    temperature=0.2,
                ),
            )
            if response.parsed is not None:
                parsed: QuestAIStructuredOutput = response.parsed
                if override_difficulty is not None:
                    parsed.difficulty = override_difficulty
                return parsed
            if response.text:
                parsed = QuestAIStructuredOutput.model_validate_json(response.text)
                if override_difficulty is not None:
                    parsed.difficulty = override_difficulty
                return parsed
        except Exception:
            pass

    return _heuristic_parse(prompt, override_difficulty=override_difficulty)
