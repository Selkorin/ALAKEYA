#!/bin/bash

# Скрипт для запуска RouteLLM сервера

echo "🚀 Запуск RouteLLM сервера для Алакеи..."

# Проверка наличия .env файла
if [ ! -f .env ]; then
    echo "⚠️  Файл .env не найден. Создайте его из .env.example:"
    echo "   cp .env.example .env"
    echo "   Затем отредактируйте .env и добавьте ваш OPENAI_API_KEY"
    exit 1
fi

# Проверка Python
if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 не установлен. Установите его:"
    echo "   brew install python3"
    exit 1
fi

# Создание виртуального окружения если его нет
if [ ! -d "venv" ]; then
    echo "📦 Создание виртуального окружения..."
    python3 -m venv venv
fi

# Активация виртуального окружения
echo "🔧 Активация виртуального окружения..."
source venv/bin/activate

# Установка зависимостей
echo "📥 Установка зависимостей..."
pip install -q -r requirements.txt

# Запуск сервера
echo "🌐 Запуск сервера на порту 8000..."
python3 server.py
