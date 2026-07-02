#!/usr/bin/env python3
"""
Гермес QualityLearner - обучение на основе feedback из Алакеи
"""
import json
import os
from typing import Dict, List, Any
from datetime import datetime
from collections import defaultdict

class HermesQualityLearner:
    """
    Обучается на лайках/дизлайках пользователей Алакеи
    для предсказания лучших агентов и моделей
    """

    def __init__(self, feedback_path: str = None):
        self.feedback_path = feedback_path or self._find_feedback_file()
        self.agent_profiles_path = self._find_agent_profiles_file()
        self.learning_data = defaultdict(list)
        self.agent_performance = defaultdict(dict)
        self.load_feedback()
        self.load_agent_profiles()

    def _find_feedback_file(self) -> str:
        """Находит файл feedback Алакеи"""
        base = os.path.expanduser("~/Library/Application Support/Alakeya")
        feedback_file = os.path.join(base, "message_feedback.json")

        if os.path.exists(feedback_file):
            return feedback_file
        return "message_feedback.json"  # Fallback

    def _find_agent_profiles_file(self) -> str:
        """Находит файл профилей агентов"""
        base = os.path.expanduser("~/Library/Application Support/Alakeya/Agents")
        agents_file = os.path.join(base, "agents.json")

        if os.path.exists(agents_file):
            return agents_file
        return "agents.json"  # Fallback

    def load_feedback(self):
        """Загружает feedback из Алакеи"""
        try:
            if os.path.exists(self.feedback_path):
                with open(self.feedback_path, 'r', encoding='utf-8') as f:
                    feedback_data = json.load(f)

                for message_id, rating in feedback_data.items():
                    self.learning_data[rating].append({
                        'message_id': message_id,
                        'timestamp': datetime.now().isoformat()
                    })

                print(f"✅ Загружено {len(feedback_data)} feedback записей")
                print(f"   👍 Good: {len(self.learning_data['good'])}")
                print(f"   👎 Bad: {len(self.learning_data['bad'])}")
        except Exception as e:
            print(f"⚠️  Ошибка загрузки feedback: {e}")

    def load_agent_profiles(self):
        """Загружает профили агентов"""
        try:
            if os.path.exists(self.agent_profiles_path):
                with open(self.agent_profiles_path, 'r', encoding='utf-8') as f:
                    agents = json.load(f)

                for agent in agents:
                    agent_id = agent['id']
                    self.agent_performance[agent_id] = {
                        'name': agent['name'],
                        'instructions': agent['instructions'],
                        'model': agent['modelName'],
                        'total_messages': 0,
                        'good_ratings': 0,
                        'bad_ratings': 0,
                        'success_rate': 0.0,
                        'role': self._detect_role(agent)
                    }

                print(f"✅ Загружено {len(agents)} профилей агентов")
        except Exception as e:
            print(f"⚠️  Ошибка загрузки профилей: {e}")

    def _detect_role(self, agent: dict) -> str:
        """Определяет роль агента на основе инструкций"""
        instructions = agent['instructions'].lower()
        name = agent['name'].lower()

        role_patterns = {
            'coder': ['кодер', 'developer', 'программист', 'swift', 'python'],
            'designer': ['дизайн', 'ui/ux', 'графическ'],
            'smm': ['smm', 'социальн', 'контент-стратег'],
            'marketer': ['маркетолог', 'marketing'],
            'researcher': ['исследоват', 'research', 'аналитик'],
            'copywriter': ['копирайт', 'редактор текст'],
            'sales': ['продаж', 'sales'],
        }

        context = f"{name} {instructions}"

        for role, patterns in role_patterns.items():
            if any(pattern in context for pattern in patterns):
                return role

        return 'assistant'

    def analyze_task_type(self, query: str) -> Dict[str, Any]:
        """
        Анализирует тип задачи для выбора лучшего агента

        Returns:
            {
                'task_type': str,
                'complexity': float,
                'required_role': str,
                'recommended_agents': List[str]
            }
        """
        query_lower = query.lower()

        # Определяем тип задачи
        task_indicators = {
            'coding': ['код', 'функция', 'скрипт', 'программ', 'разработ'],
            'writing': ['текст', 'статья', 'описание', 'сочинение'],
            'analysis': ['анализ', 'исследование', 'данные', 'статистик'],
            'design': ['дизайн', 'цвет', 'шрифт', 'интерфейс'],
            'marketing': ['маркетинг', 'реклам', 'продвиж', 'кампани'],
        }

        detected_tasks = []
        for task_type, indicators in task_indicators.items():
            if any(indicator in query_lower for indicator in indicators):
                detected_tasks.append(task_type)

        primary_task = detected_tasks[0] if detected_tasks else 'general'

        # Оцениваем сложность
        complexity = self._estimate_complexity(query)

        # Определяем необходимую роль
        role_mapping = {
            'coding': 'coder',
            'writing': 'copywriter',
            'analysis': 'researcher',
            'design': 'designer',
            'marketing': 'marketer',
        }

        required_role = role_mapping.get(primary_task, 'assistant')

        # Рекомендуем агентов
        recommended_agents = self._get_agents_by_role(required_role)

        return {
            'task_type': primary_task,
            'complexity': complexity,
            'required_role': required_role,
            'recommended_agents': recommended_agents,
            'query': query
        }

    def _estimate_complexity(self, query: str) -> float:
        """Оценивает сложность запроса (0.0-1.0)"""
        words = query.split()

        # Базовая сложность на основе длины
        base_complexity = min(len(words) / 100, 1.0)

        # Индикаторы сложности
        complexity_boosters = [
            'объясни', 'почему', 'как работает', 'принцип',
            'сравни', 'проанализируй', 'опиши'
        ]

        for booster in complexity_boosters:
            if booster in query.lower():
                base_complexity = min(base_complexity + 0.2, 1.0)

        return base_complexity

    def _get_agents_by_role(self, role: str) -> List[str]:
        """Получает агентов по роли"""
        matching_agents = []

        for agent_id, agent_data in self.agent_performance.items():
            if agent_data['role'] == role:
                matching_agents.append({
                    'id': agent_id,
                    'name': agent_data['name'],
                    'model': agent_data['model'],
                    'success_rate': agent_data['success_rate']
                })

        # Сортируем по success_rate
        matching_agents.sort(key=lambda x: x['success_rate'], reverse=True)

        return matching_agents

    def predict_best_agent(self, query: str) -> Dict[str, Any]:
        """
        Предсказывает лучшего агента для задачи

        Returns:
            {
                'recommended_agent': str,
                'confidence': float,
                'expected_quality': float,
                'cost_estimate': float
            }
        """
        task_analysis = self.analyze_task_type(query)
        recommended_agents = task_analysis['recommended_agents']

        if not recommended_agents:
            # Если нет специализированных агентов, используем общий
            return {
                'recommended_agent': 'general',
                'confidence': 0.5,
                'expected_quality': 0.7,
                'cost_estimate': 0.01,
                'reason': 'No specialized agent found, using general'
            }

        best_agent = recommended_agents[0]

        # Оцениваем уверенность и качество
        confidence = min(0.9, 0.6 + (best_agent['success_rate'] * 0.3))
        expected_quality = min(0.95, 0.7 + (best_agent['success_rate'] * 0.25))

        # Оцениваем стоимость
        cost_estimate = self._estimate_agent_cost(best_agent['model'])

        return {
            'recommended_agent': best_agent['id'],
            'agent_name': best_agent['name'],
            'agent_model': best_agent['model'],
            'confidence': confidence,
            'expected_quality': expected_quality,
            'cost_estimate': cost_estimate,
            'task_analysis': task_analysis
        }

    def _estimate_agent_cost(self, model: str) -> float:
        """Оценивает стоимость агента"""
        # Цены за 1K токенов (упрощенные)
        model_costs = {
            'gpt-4o': 0.02,
            'gpt-4o-mini': 0.002,
            'claude-opus': 0.03,
            'claude-sonnet': 0.01,
            'claude-haiku': 0.001,
        }

        return model_costs.get(model.lower(), 0.01)

    def learn_from_feedback(self, message_id: str, rating: str, agent_id: str):
        """
        Обучается на новом feedback
        """
        if agent_id in self.agent_performance:
            self.agent_performance[agent_id]['total_messages'] += 1

            if rating == 'good':
                self.agent_performance[agent_id]['good_ratings'] += 1
            elif rating == 'bad':
                self.agent_performance[agent_id]['bad_ratings'] += 1

            # Пересчитываем success rate
            total = self.agent_performance[agent_id]['total_messages']
            good = self.agent_performance[agent_id]['good_ratings']

            self.agent_performance[agent_id]['success_rate'] = good / total if total > 0 else 0.0

    def get_performance_report(self) -> Dict[str, Any]:
        """Генерирует отчет производительности агентов"""
        report = {
            'total_agents': len(self.agent_performance),
            'total_feedback': len(self.learning_data['good']) + len(self.learning_data['bad']),
            'good_feedback_rate': 0.0,
            'agents': []
        }

        if report['total_feedback'] > 0:
            report['good_feedback_rate'] = len(self.learning_data['good']) / report['total_feedback']

        # Топ агентов
        sorted_agents = sorted(
            self.agent_performance.items(),
            key=lambda x: x[1]['success_rate'],
            reverse=True
        )

        for agent_id, agent_data in sorted_agents[:5]:  # Топ 5
            report['agents'].append({
                'id': agent_id,
                'name': agent_data['name'],
                'role': agent_data['role'],
                'model': agent_data['model'],
                'success_rate': agent_data['success_rate'],
                'total_messages': agent_data['total_messages']
            })

        return report


# Демонстрация
if __name__ == "__main__":
    learner = HermesQualityLearner()

    # Тестовые запросы
    test_queries = [
        "Напиши функцию сортировки на Python",
        "Создай логотип для стартапа",
        "Проанализируй данные о продажах",
        "Напиши пост для Instagram"
    ]

    print("\n🧪 Тестирование системы рекомендаций:\n")

    for query in test_queries:
        print(f"📝 Запрос: {query}")
        prediction = learner.predict_best_agent(query)

        print(f"   🤖 Рекомендуемый агент: {prediction['agent_name']}")
        print(f"   📊 Уверенность: {prediction['confidence']:.2f}")
        print(f"   ⭐ Ожидаемое качество: {prediction['expected_quality']:.2f}")
        print(f"   💰 Оценка стоимости: ${prediction['cost_estimate']:.4f}")
        print()

    # Отчет производительности
    print("📈 Отчет производительности:")
    report = learner.get_performance_report()
    print(f"   Всего агентов: {report['total_agents']}")
    print(f"   Всего feedback: {report['total_feedback']}")
    print(f"   Good rate: {report['good_feedback_rate']:.2%}")

    if report['agents']:
        print("\n   Топ агентов:")
        for agent in report['agents']:
            print(f"   - {agent['name']} ({agent['role']}): {agent['success_rate']:.1%}")
