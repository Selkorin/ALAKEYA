#!/usr/bin/env python3
"""
RouteLLM Server for Alakeya
Локальный сервер для интеллектуальной маршрутизации LLM запросов
"""
import os
import json
import logging
from typing import List, Dict, Any, Optional
from datetime import datetime

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from dotenv import load_dotenv
from hermes_hub import HermesHub

# Настройка логирования
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

load_dotenv()

# Модели для API запросов
class Message(BaseModel):
    role: str = Field(..., description="Роль сообщения: user, assistant, system")
    content: str = Field(..., description="Содержание сообщения")

class RouteRequest(BaseModel):
    messages: List[Message] = Field(..., description="Список сообщений")
    threshold: float = Field(default=0.15, ge=0.0, le=1.0, description="Порог маршрутизации")
    temperature: float = Field(default=0.7, ge=0.0, le=2.0, description="Temperature для генерации")
    max_tokens: int = Field(default=2000, ge=1, le=32000, description="Максимальное количество токенов")
    user_id: Optional[str] = Field(None, description="ID пользователя для логирования")

class RouteResponse(BaseModel):
    response: str = Field(..., description="Ответ модели")
    model_used: str = Field(..., description="Какая модель была использована")
    cost: float = Field(..., description="Стоимость запроса в USD")
    tokens_used: Dict[str, int] = Field(..., description="Использованные токены")
    routing_decision: Dict[str, Any] = Field(..., description="Детали маршрутизации")

class HealthResponse(BaseModel):
    status: str
    version: str
    timestamp: str

# Инициализация FastAPI
app = FastAPI(
    title="RouteLLM Server for Alakeya",
    description="Интеллектуальная маршрутизация LLM запросов",
    version="1.0.0"
)

# CORS middleware для Swift клиента
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Глобальная переменная для роутера
router_instance = None

class RouteLLMManager:
    """Менеджер RouteLLM роутера"""

    def __init__(self):
        self.router = None
        self.strong_model = os.getenv("ROUTE_LLM_STRONG_MODEL", "gpt-4o")
        self.weak_model = os.getenv("ROUTE_LLM_WEAK_MODEL", "gpt-4o-mini")
        self.api_key = os.getenv("OPENAI_API_KEY")
        self.stats = {
            "total_requests": 0,
            "routed_to_strong": 0,
            "routed_to_weak": 0,
            "total_cost": 0.0
        }

    def initialize(self):
        """Инициализация RouteLLM роутера"""
        try:
            from routellm.controller import Controller

            logger.info(f"Инициализация RouteLLM: strong={self.strong_model}, weak={self.weak_model}")

            # Установка API ключа
            if self.api_key:
                os.environ["OPENAI_API_KEY"] = self.api_key

            self.router = Controller(
                routers=["mf"],  # Matrix Factorization routing
                strong_model=self.strong_model,
                weak_model=self.weak_model,
            )

            logger.info("✅ RouteLLM инициализирован успешно")
            return True

        except Exception as e:
            logger.error(f"❌ Ошибка инициализации RouteLLM: {e}")
            return False

    def route_request(self, request: RouteRequest) -> RouteResponse:
        """Маршрутизация запроса"""
        try:
            self.stats["total_requests"] += 1

            # Преобразование сообщений в формат RouteLLM
            messages = [
                {"role": msg.role, "content": msg.content}
                for msg in request.messages
            ]

            # Создание имени селектора модели
            model_selector = f"router-mf-{request.threshold}"

            logger.info(f"Маршрутизация запроса с threshold={request.threshold}")

            # Вызов RouteLLM
            response = self.router.chat.completions.create(
                model=model_selector,
                messages=messages,
                temperature=request.temperature,
                max_tokens=request.max_tokens,
            )

            # Извлечение информации из ответа
            content = response.choices[0].message.content
            model_used = getattr(response, 'model', self.strong_model)

            # Определение сложности (эвристика)
            is_strong = self._estimate_complexity(messages, request.threshold)

            if is_strong:
                self.stats["routed_to_strong"] += 1
                actual_model = self.strong_model
                logger.info(f"🧠 Использована сильная модель: {self.strong_model}")
            else:
                self.stats["routed_to_weak"] += 1
                actual_model = self.weak_model
                logger.info(f"⚡ Использована слабая модель: {self.weak_model}")

            # Подсчёт стоимости
            prompt_tokens = response.usage.prompt_tokens
            completion_tokens = response.usage.completion_tokens
            cost = self._calculate_cost(prompt_tokens, completion_tokens, actual_model)
            self.stats["total_cost"] += cost

            return RouteResponse(
                response=content,
                model_used=actual_model,
                cost=cost,
                tokens_used={
                    "prompt": prompt_tokens,
                    "completion": completion_tokens,
                    "total": prompt_tokens + completion_tokens
                },
                routing_decision={
                    "threshold": request.threshold,
                    "is_strong_model": is_strong,
                    "complexity_score": self._calculate_complexity_score(messages),
                    "user_id": request.user_id
                }
            )

        except Exception as e:
            logger.error(f"❌ Ошибка при маршрутизации: {e}")
            raise HTTPException(status_code=500, detail=str(e))

    def _estimate_complexity(self, messages: List[Dict], threshold: float) -> bool:
        """Оценка сложности запроса (эвристика)"""
        # Комбинированный текст всех сообщений
        combined_text = " ".join([msg.get("content", "") for msg in messages])

        # Простая эвристика на основе длины и сложности
        word_count = len(combined_text.split())
        complexity_score = min(word_count / 100, 1.0)  # Нормализация 0-1

        return complexity_score > threshold

    def _calculate_complexity_score(self, messages: List[Dict]) -> float:
        """Вычисление оценки сложности"""
        combined_text = " ".join([msg.get("content", "") for msg in messages])
        word_count = len(combined_text.split())
        return min(word_count / 100, 1.0)

    def _calculate_cost(self, prompt_tokens: int, completion_tokens: int, model: str) -> float:
        """Подсчёт стоимости запроса"""
        # Цены за 1K токенов (примерные)
        prices = {
            "gpt-4o": {"input": 0.005, "output": 0.015},
            "gpt-4o-mini": {"input": 0.00015, "output": 0.0006},
            "gpt-3.5-turbo": {"input": 0.0005, "output": 0.0015},
        }

        if model not in prices:
            # Цена по умолчанию
            prices[model] = {"input": 0.001, "output": 0.002}

        input_cost = (prompt_tokens / 1000) * prices[model]["input"]
        output_cost = (completion_tokens / 1000) * prices[model]["output"]

        return input_cost + output_cost

    def get_stats(self) -> Dict[str, Any]:
        """Получение статистики"""
        total = self.stats["total_requests"]
        if total == 0:
            return self.stats

        return {
            **self.stats,
            "strong_percentage": (self.stats["routed_to_strong"] / total) * 100,
            "weak_percentage": (self.stats["routed_to_weak"] / total) * 100,
            "average_cost_per_request": self.stats["total_cost"] / total,
            "total_saved": self._calculate_savings()
        }

    def _calculate_savings(self) -> float:
        """Подсчёт экономии"""
        # Если бы все запросы шли на сильную модель
        strong_cost_per_request = 0.02  # Примерно
        total_if_all_strong = self.stats["total_requests"] * strong_cost_per_request
        return total_if_all_strong - self.stats["total_cost"]

# Глобальный менеджер
manager = RouteLLMManager()

# Гермес хаб
hermes_hub = None

@app.on_event("startup")
async def startup_event():
    """Инициализация при старте сервера"""
    logger.info("🚀 Запуск RouteLLM + Гермес сервера...")

    # Инициализация RouteLLM
    if manager.initialize():
        logger.info("✅ RouteLLM готов к работе")
    else:
        logger.error("❌ Не удалось инициализировать RouteLLM")

    # Инициализация Гермес
    global hermes_hub
    hermes_hub = HermesHub()
    logger.info("✅ Гермес готов к работе")

@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Проверка здоровья сервера"""
    return HealthResponse(
        status="healthy",
        version="1.0.0",
        timestamp=datetime.now().isoformat()
    )

@app.post("/route", response_model=RouteResponse)
async def route_request(request: RouteRequest):
    """Основной эндпоинт для маршрутизации"""
    return manager.route_request(request)

@app.get("/stats")
async def get_stats():
    """Получение статистики маршрутизации"""
    return manager.get_stats()

@app.post("/stats/reset")
async def reset_stats():
    """Сброс статистики"""
    manager.stats = {
        "total_requests": 0,
        "routed_to_strong": 0,
        "routed_to_weak": 0,
        "total_cost": 0.0
    }
    return {"status": "reset"}

# ── Гермес эндпоинты ─────────────────────────────────────

@app.post("/hermes/process")
async def hermes_process(request: dict):
    """Обработка запроса через Гермес"""
    if hermes_hub is None:
        raise HTTPException(status_code=503, detail="Гермес не инициализирован")

    query = request.get("query", "")
    user_context = request.get("user_context")

    result = hermes_hub.process_query(query, user_context)
    return result

@app.post("/hermes/feedback")
async def hermes_feedback(request: dict):
    """Запись feedback и обучение"""
    if hermes_hub is None:
        raise HTTPException(status_code=503, detail="Гермес не инициализирован")

    query = request.get("query", "")
    agent_id = request.get("agent_id", "")
    rating = request.get("rating", "")
    result = request.get("result", {})

    hermes_hub.record_feedback(query, agent_id, rating, result)
    return {"status": "feedback_recorded"}

@app.get("/hermes/report")
async def hermes_report(user_id: str = "default"):
    """Получить отчет о производительности"""
    if hermes_hub is None:
        raise HTTPException(status_code=503, detail="Гермес не инициализирован")

    report = hermes_hub.generate_user_report(user_id)
    return report

@app.post("/hermes/cost-analysis")
async def hermes_cost_analysis(request: dict):
    """Анализ экономической выгоды"""
    if hermes_hub is None:
        raise HTTPException(status_code=503, detail="Гермес не инициализирован")

    monthly_requests = request.get("monthly_requests", 100)
    company_size = request.get("company_size", "small")
    industry = request.get("industry", "general")

    analysis = hermes_hub.cost_optimizer.generate_business_case(company_size, industry)
    return analysis

if __name__ == "__main__":
    import uvicorn

    # Запуск сервера
    port = int(os.getenv("ROUTE_LLM_PORT", 8000))
    logger.info(f"🌐 Запуск сервера на порту {port}")

    uvicorn.run(
        "server:app",
        host="127.0.0.1",
        port=port,
        reload=True,
        log_level="info"
    )
