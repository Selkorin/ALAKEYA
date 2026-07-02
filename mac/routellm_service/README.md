# RouteLLM Server for Alakeya

Локальный сервер для интеллектуальной маршрутизации LLM запросов между сильными и слабыми моделями.

## 🚀 Установка и запуск

### 1. Настройка окружения

```bash
cd routellm_service
cp .env.example .env
```

Отредактируйте `.env` и добавьте ваш OpenAI API ключ:

```env
OPENAI_API_KEY=your_actual_api_key_here
ROUTE_LLM_STRONG_MODEL=gpt-4o
ROUTE_LLM_WEAK_MODEL=gpt-4o-mini
ROUTE_LLM_PORT=8000
```

### 2. Запуск сервера

```bash
./start_server.sh
```

Или вручную:

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python3 server.py
```

### 3. Тестирование

В отдельном терминале:

```bash
python3 test_server.py
```

## 📡 API Эндпоинты

### POST /route
Основной эндпоинт для маршрутизации запросов.

**Request:**
```json
{
  "messages": [
    {"role": "user", "content": "Привет, как дела?"}
  ],
  "threshold": 0.15,
  "temperature": 0.7,
  "max_tokens": 2000,
  "user_id": "user123"
}
```

**Response:**
```json
{
  "response": "Ответ модели...",
  "model_used": "gpt-4o-mini",
  "cost": 0.000123,
  "tokens_used": {
    "prompt": 10,
    "completion": 20,
    "total": 30
  },
  "routing_decision": {
    "threshold": 0.15,
    "is_strong_model": false,
    "complexity_score": 0.1
  }
}
```

### GET /health
Проверка здоровья сервера.

### GET /stats
Получение статистики маршрутизации.

## 🔧 Принцип работы

1. **Matrix Factorization Routing**: RouteLLM анализирует сложность запроса
2. **Intelligent Selection**: Простые запросы → слабая модель, Сложные → сильная
3. **Cost Optimization**: Экономия 50-85% на стоимости
4. **Quality Retention**: Качество на уровне GPT-4

## 📊 Метрики

- **threshold**: Порог маршрутизации (0.0-1.0)
  - Ниже порога → слабая модель
  - Выше порога → сильная модель
- **complexity_score**: Оценка сложности (0.0-1.0)
- **cost**: Стоимость в USD
- **tokens_used**: Количество токенов

## 🛠️ Troubleshooting

### Сервер не запускается:
```bash
# Проверьте Python 3
python3 --version

# Переустановите зависимости
pip install -r requirements.txt --force-reinstall
```

### Ошибка API ключа:
```bash
# Проверьте .env файл
cat .env | grep OPENAI_API_KEY
```

### Порт занят:
```bash
# Измените порт в .env
ROUTE_LLM_PORT=8001
```
