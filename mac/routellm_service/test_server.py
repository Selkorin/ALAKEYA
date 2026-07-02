#!/usr/bin/env python3
"""
Тестовый скрипт для RouteLLM сервера
"""
import requests
import json
import time

SERVER_URL = "http://127.0.0.1:8000"

def test_health():
    """Тест проверки здоровья"""
    print("🏥 Тест здоровья сервера...")
    try:
        response = requests.get(f"{SERVER_URL}/health")
        assert response.status_code == 200
        data = response.json()
        print(f"✅ Сервер здоров: {data['status']}")
        return True
    except Exception as e:
        print(f"❌ Ошибка здоровья: {e}")
        return False

def test_routing():
    """Тест маршрутизации"""
    print("\n🧪 Тест маршрутизации...")

    test_cases = [
        {
            "name": "Простой запрос",
            "messages": [
                {"role": "user", "content": "Привет, как дела?"}
            ],
            "expected_weak": True
        },
        {
            "name": "Сложный запрос",
            "messages": [
                {"role": "user", "content": "Объясни квантовую механику с точки зрения Эйнштейна, включая основные принципы неопределенности и их влияние на современные технологии."}
            ],
            "expected_weak": False
        }
    ]

    for test_case in test_cases:
        print(f"\n📝 {test_case['name']}")

        try:
            start_time = time.time()

            response = requests.post(
                f"{SERVER_URL}/route",
                json={
                    "messages": test_case["messages"],
                    "threshold": 0.15,
                    "temperature": 0.7,
                    "max_tokens": 1000,
                    "user_id": "test_user"
                }
            )

            elapsed = time.time() - start_time

            if response.status_code == 200:
                data = response.json()
                print(f"✅ Успех за {elapsed:.2f}s")
                print(f"   Модель: {data['model_used']}")
                print(f"   Стоимость: ${data['cost']:.6f}")
                print(f"   Токены: {data['tokens_used']}")
                print(f"   Ответ: {data['response'][:100]}...")
            else:
                print(f"❌ Ошибка {response.status_code}: {response.text}")

        except Exception as e:
            print(f"❌ Исключение: {e}")

def test_stats():
    """Тест статистики"""
    print("\n📊 Тест статистики...")
    try:
        response = requests.get(f"{SERVER_URL}/stats")
        assert response.status_code == 200
        data = response.json()
        print("✅ Статистика:")
        print(f"   Всего запросов: {data['total_requests']}")
        print(f"   Сильные: {data.get('routed_to_strong', 0)}")
        print(f"   Слабые: {data.get('routed_to_weak', 0)}")
        print(f"   Общая стоимость: ${data.get('total_cost', 0):.6f}")
    except Exception as e:
        print(f"❌ Ошибка статистики: {e}")

if __name__ == "__main__":
    print("🚀 Тестирование RouteLLM сервера\n")

    if test_health():
        test_routing()
        test_stats()

    print("\n✅ Тестирование завершено!")
