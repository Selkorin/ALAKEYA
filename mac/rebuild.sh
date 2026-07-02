#!/bin/bash
# Скрипт для пересборки приложения Alakeya

set -e

echo "🔨 Пересборка Alakeya..."
swift build

echo "📦 Копирование исполняемого файла..."
cp .build/x86_64-apple-macosx/debug/Alakeya /Applications/Alakeya.app/Contents/MacOS/

echo "✅ Готово! Приложение пересобрано."
echo "ℹ️  После включения Accessibility в настройках macOS необходимо перезапустить Alakeya"
