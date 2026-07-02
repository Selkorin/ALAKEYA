#!/usr/bin/env python3
"""
Гермес Hub - центральная система интеграции для Алакеи
Объединяет QualityLearner, CostOptimizer и RouteLLM
"""
import os
import json
from typing import Dict, List, Any, Optional
from datetime import datetime
from hermes_quality_learner import HermesQualityLearner
from hermes_cost_optimizer import HermesCostOptimizer

class HermesHub:
    """
    Центральный оркестратор Гермес системы
    Интегрирует все компоненты для умного управления агентами Алакеи
    """

    def __init__(self):
        self.quality_learner = HermesQualityLearner()
        self.cost_optimizer = HermesCostOptimizer()
        self.analytics_file = "hermes_analytics.json"
        self.load_analytics()

    def load_analytics(self):
        """Загружает аналитику использования"""
        if os.path.exists(self.analytics_file):
            try:
                with open(self.analytics_file, 'r', encoding='utf-8') as f:
                    self.analytics = json.load(f)
            except:
                self.analytics = {
                    'total_queries': 0,
                    'successful_recommendations': 0,
                    'cost_savings': 0.0,
                    'user_satisfaction': 0.0,
                    'agent_performance': {}
                }
        else:
            self.analytics = {
                'total_queries': 0,
                'successful_recommendations': 0,
                'cost_savings': 0.0,
                'user_satisfaction': 0.0,
                'agent_performance': {}
            }

    def save_analytics(self):
        """Сохраняет аналитику"""
        with open(self.analytics_file, 'w', encoding='utf-8') as f:
            json.dump(self.analytics, f, indent=2, ensure_ascii=False)

    def process_query(
        self,
        query: str,
        user_context: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        """
        Основной метод обработки запроса через Гермес

        Args:
            query: Текст запроса пользователя
            user_context: Контекст пользователя {
                'user_id': str,
                'history': List[str],
                'preferences': Dict[str, Any]
            }

        Returns:
            {
                'recommended_agent': Dict[str, Any],
                'cost_benefit': Dict[str, Any],
                'quality_prediction': Dict[str, Any],
                'routing_decision': Dict[str, Any]
            }
        """
        self.analytics['total_queries'] += 1

        # 1. Анализируем задачу и рекомендуем агента
        agent_recommendation = self.quality_learner.predict_best_agent(query)

        # 2. Рассчитываем экономическую выгоду
        # Оцениваем объем запросов на основе пользователя
        estimated_monthly_requests = self._estimate_user_requests(user_context)

        cost_benefit = self.cost_optimizer.calculate_monthly_benefit(
            monthly_requests=estimated_monthly_requests,
            custom_setup_cost=500,  # Базовая стоимость настройки
            use_specialized_agents=agent_recommendation['confidence'] > 0.7
        )

        # 3. Предсказание качества
        quality_prediction = {
            'expected_quality': agent_recommendation['expected_quality'],
            'confidence': agent_recommendation['confidence'],
            'complexity': agent_recommendation['task_analysis']['complexity'],
            'task_type': agent_recommendation['task_analysis']['task_type']
        }

        # 4. Решение о маршрутизации
        routing_decision = self._make_routing_decision(
            agent_recommendation,
            cost_benefit,
            quality_prediction
        )

        # Обновляем аналитику
        if routing_decision['use_alakeya_agent']:
            self.analytics['successful_recommendations'] += 1
            self.analytics['cost_savings'] += cost_benefit['monthly_savings'] / 30  # В день

        return {
            'recommended_agent': agent_recommendation,
            'cost_benefit': cost_benefit,
            'quality_prediction': quality_prediction,
            'routing_decision': routing_decision,
            'timestamp': datetime.now().isoformat()
        }

    def _estimate_user_requests(self, user_context: Optional[Dict[str, Any]]) -> int:
        """Оценивает количество запросов пользователя"""
        if not user_context:
            return 100  # Базовая оценка

        # Если есть история, считаем среднее
        history = user_context.get('history', [])
        if len(history) > 0:
            # Примерная оценка: 2 запроса в день * 30 дней
            return max(60, len(history) * 2)

        return 100

    def _make_routing_decision(
        self,
        agent_recommendation: Dict[str, Any],
        cost_benefit: Dict[str, Any],
        quality_prediction: Dict[str, Any]
    ) -> Dict[str, Any]:
        """
        Принимает решение о маршрутизации запроса

        Returns:
            {
                'use_alakeya_agent': bool,
                'use_custom_solution': bool,
                'reasoning': str,
                'recommended_model': str
            }
        """
        # Критерии для использования Алакеи агента
        use_alakeya = True
        reasoning = []

        # 1. Проверка качества
        if quality_prediction['expected_quality'] >= 0.8:
            reasoning.append("✅ Высокое ожидаемое качество (>80%)")
        else:
            reasoning.append("⚠️  Среднее качество (~70%)")

        # 2. Проверка экономии
        monthly_savings = cost_benefit['monthly_savings']
        if monthly_savings > 100:
            reasoning.append(f"💰 Значительная экономия (${monthly_savings:.2f}/мес)")
        elif monthly_savings > 20:
            reasoning.append(f"💵 Умеренная экономия (${monthly_savings:.2f}/мес)")
        else:
            reasoning.append(f"💳 Минимальная экономия (${monthly_savings:.2f}/мес)")

        # 3. Проверка уверенности в рекомендации
        confidence = agent_recommendation['confidence']
        if confidence >= 0.8:
            reasoning.append("🎯 Высокая уверенность в рекомендации")
        elif confidence >= 0.6:
            reasoning.append("🤔 Умеренная уверенность")
        else:
            reasoning.append("❓ Низкая уверенность - рассмотрите кастомное решение")
            use_alakeya = False

        # 4. Сложность задачи
        complexity = quality_prediction['complexity']
        if complexity > 0.8:
            reasoning.append("🧠 Очень сложная задача - нужна мощная модель")
        elif complexity > 0.5:
            reasoning.append("⚡ Средняя сложность")
        else:
            reasoning.append("📝 Простая задача - подойдет быстрое решение")

        # Итоговое решение
        if use_alakeya and confidence >= 0.6:
            recommended_model = agent_recommendation.get('agent_model', 'alakeya_smart')
            reasoning.append(f"✅ РЕКОМЕНДУЕТСЯ: Алакея агент")
        else:
            recommended_model = 'custom_gpt4'
            reasoning.append("⚠️  Рассмотрите кастомное решение")

        return {
            'use_alakeya_agent': use_alakeya and confidence >= 0.6,
            'use_custom_solution': not (use_alakeya and confidence >= 0.6),
            'reasoning': reasoning,
            'recommended_model': recommended_model,
            'expected_quality': quality_prediction['expected_quality'],
            'estimated_cost': agent_recommendation['cost_estimate']
        }

    def record_feedback(
        self,
        query: str,
        agent_id: str,
        rating: str,
        result: Dict[str, Any]
    ):
        """
        Записывает feedback и обучается на нем

        Args:
            query: Исходный запрос
            agent_id: ID использованного агента
            rating: 'good' или 'bad'
            result: Результат выполнения {
                'response_time': float,
                'cost': float,
                'quality_score': float
            }
        """
        # Обучаем QualityLearner
        self.quality_learner.learn_from_feedback(
            message_id=result.get('message_id', ''),
            rating=rating,
            agent_id=agent_id
        )

        # Обновляем аналитику
        if rating == 'good':
            # Увеличиваем оценку удовлетворенности
            current_satisfaction = self.analytics['user_satisfaction']
            self.analytics['user_satisfaction'] = min(1.0, current_satisfaction + 0.01)
        else:
            # Уменьшаем оценку
            current_satisfaction = self.analytics['user_satisfaction']
            self.analytics['user_satisfaction'] = max(0.0, current_satisfaction - 0.02)

        # Обновляем производительность агента
        if agent_id not in self.analytics['agent_performance']:
            self.analytics['agent_performance'][agent_id] = {
                'total': 0,
                'good': 0,
                'bad': 0,
                'success_rate': 0.0
            }

        agent_perf = self.analytics['agent_performance'][agent_id]
        agent_perf['total'] += 1

        if rating == 'good':
            agent_perf['good'] += 1
        else:
            agent_perf['bad'] += 1

        agent_perf['success_rate'] = agent_perf['good'] / agent_perf['total'] if agent_perf['total'] > 0 else 0.0

        self.save_analytics()

    def generate_user_report(self, user_id: str = "default") -> Dict[str, Any]:
        """
        Генерирует отчет для пользователя

        Returns:
            {
                'performance_summary': Dict[str, Any],
                'cost_benefit_analysis': Dict[str, Any],
                'quality_metrics': Dict[str, Any],
                'recommendations': List[str]
            }
        """
        perf_report = self.quality_learner.get_performance_report()

        # Анализ выгоды
        cost_benefit = self.cost_optimizer.generate_business_case(
            company_size='small',
            industry='general'
        )

        # Рекомендации
        recommendations = []

        if self.analytics['user_satisfaction'] >= 0.8:
            recommendations.append("🎉 Отлично! Вы довольны качеством агентов Алакеи")
        elif self.analytics['user_satisfaction'] >= 0.6:
            recommendations.append("⚠️  Умеренная удовлетворенность - рассмотрите специализированных агентов")
        else:
            recommendations.append("❌ Низкая удовлетворенность - рекомендуется пересмотреть настройки")

        if self.analytics['cost_savings'] > 100:
            recommendations.append(f"💰 Отличная экономия: ${self.analytics['cost_savings']:.2f} сэкономлено")

        top_agents = perf_report.get('agents', [])[:3]
        if top_agents:
            top_agent_names = [agent['name'] for agent in top_agents]
            recommendations.append(f"🤖 Топ агенты: {', '.join(top_agent_names)}")

        return {
            'performance_summary': {
                'total_queries': self.analytics['total_queries'],
                'successful_recommendations': self.analytics['successful_recommendations'],
                'user_satisfaction': self.analytics['user_satisfaction'],
                'total_savings': self.analytics['cost_savings']
            },
            'cost_benefit_analysis': {
                'monthly_savings': cost_benefit['financial_benefits']['monthly_savings'],
                'annual_savings': cost_benefit['financial_benefits']['annual_savings'],
                'roi_percentage': cost_benefit['financial_benefits']['roi_percentage']
            },
            'quality_metrics': {
                'good_feedback_rate': perf_report['good_feedback_rate'],
                'top_agents': top_agents
            },
            'recommendations': recommendations
        }

    def get_api_endpoints(self) -> Dict[str, Any]:
        """
        Описание API эндпоинтов для интеграции с Алакеей
        """
        return {
            'endpoints': [
                {
                    'path': '/hermes/process',
                    'method': 'POST',
                    'description': 'Обработать запрос через Гермес',
                    'parameters': {
                        'query': 'Текст запроса (обязательный)',
                        'user_context': 'Контекст пользователя (опциональный)'
                    },
                    'response': 'Рекомендация агента + экономическая выгода'
                },
                {
                    'path': '/hermes/feedback',
                    'method': 'POST',
                    'description': 'Записать feedback и обучиться',
                    'parameters': {
                        'query': 'Исходный запрос',
                        'agent_id': 'ID использованного агента',
                        'rating': 'good или bad',
                        'result': 'Результат выполнения'
                    }
                },
                {
                    'path': '/hermes/report',
                    'method': 'GET',
                    'description': 'Получить отчет о производительности',
                    'parameters': {
                        'user_id': 'ID пользователя (опциональный)'
                    },
                    'response': 'Полный отчет о работе системы'
                },
                {
                    'path': '/hermes/cost-analysis',
                    'method': 'POST',
                    'description': 'Рассчитать экономическую выгоду',
                    'parameters': {
                        'monthly_requests': 'Количество запросов в месяц',
                        'company_size': 'small/medium/large',
                        'industry': 'отрасль'
                    }
                }
            ],
            'integration_guide': '''
            # Swift интеграция с Гермес:

            1. Добавьте в RouteLLMClient вызов Гермес API
            2. Передавайте каждый запрос через /hermes/process
            3. Получайте рекомендации агента и экономическую выгоду
            4. Записывайте feedback через /hermes/feedback
            5. Показывайте отчеты пользователю через /hermes/report

            Пример:
            let hermesResponse = await callHermesAPI(
                query: userMessage,
                user_context: userContext
            )

            let recommendedAgent = hermesResponse["recommended_agent"]
            let costBenefit = hermesResponse["cost_benefit"]
            '''
        }


# Демонстрация
if __name__ == "__main__":
    hub = HermesHub()

    print("🌟 ГЕРМЕС HUB - ЦЕНТРАЛЬНАЯ СИСТЕМА\n")

    # Тестовые запросы
    test_queries = [
        "Напиши функцию сортировки на Python",
        "Создай маркетинговый план для стартапа",
        "Проанализируй данные о продажах за Q3",
        "Сделай логотип для техно-компании"
    ]

    print("🧪 ОБРАБОТКА ЗАПРОСОВ ЧЕРЕЗ ГЕРМЕС:\n")

    for query in test_queries:
        print(f"📝 Запрос: {query}")

        result = hub.process_query(
            query=query,
            user_context={'user_id': 'test_user', 'history': []}
        )

        routing = result['routing_decision']
        agent = result['recommended_agent']

        print(f"   🤖 Агент: {agent.get('agent_name', 'N/A')}")
        print(f"   📊 Качество: {routing['expected_quality']:.2f}")
        print(f"   💰 Стоимость: ${routing['estimated_cost']:.4f}")
        print(f"   💵 Месячная экономия: ${result['cost_benefit']['monthly_savings']:.2f}")
        print(f"   🎯 Решение: {'Использовать Алакею' if routing['use_alakeya_agent'] else 'Рассмотреть кастом'}")

        for reason in routing['reasoning']:
            print(f"      {reason}")

        print()

    # Симуляция feedback
    print("📝 СИМУЛЯЦИЯ FEEDBACK:\n")
    hub.record_feedback(
        query=test_queries[0],
        agent_id='test_agent',
        rating='good',
        result={'message_id': 'msg123', 'response_time': 1.2, 'cost': 0.003, 'quality_score': 0.9}
    )
    print("✅ Feedback записан и система обучена")

    # Генерация отчета
    print("\n📊 ОТЧЕТ ДЛЯ ПОЛЬЗОВАТЕЛЯ:\n")
    report = hub.generate_user_report()

    print(f"Всего запросов: {report['performance_summary']['total_queries']}")
    print(f"Успешных рекомендаций: {report['performance_summary']['successful_recommendations']}")
    print(f"Удовлетворенность: {report['performance_summary']['user_satisfaction']:.2%}")
    print(f"Экономия: ${report['performance_summary']['total_savings']:.2f}")

    print("\n💡 Рекомендации:")
    for rec in report['recommendations']:
        print(f"   {rec}")

    # API эндпоинты
    print("\n🔗 API ЭНДПОИНТЫ:")
    endpoints = hub.get_api_endpoints()
    for endpoint in endpoints['endpoints']:
        print(f"   {endpoint['method']} {endpoint['path']}")
        print(f"      {endpoint['description']}")

    print("\n" + "="*50)
    print("🚀 ГЕРМЕС ГОТОВ ДЛЯ ИНТЕГРАЦИИ С АЛАКЕЕЙ!")
    print("="*50)
