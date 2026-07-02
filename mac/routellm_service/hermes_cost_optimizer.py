#!/usr/bin/env python3
"""
Гермес CostOptimizer - экономическая модель использования Алакеи
Показывает выгоду использования встроенных агентов vs кастомных решений
"""
import json
from typing import Dict, List, Any
from datetime import datetime
from dataclasses import dataclass

@dataclass
class CostComparison:
    """Сравнение стоимости использования"""
    alakeya_cost: float
    custom_cost: float
    savings_percentage: float
    time_savings: float  # часы в месяц
    quality_improvement: float  # процент улучшения качества

class HermesCostOptimizer:
    """
    Экономическая оптимизатор для Алакеи
    Показывает выгоду использования агентов Алакеи
    """

    def __init__(self):
        # Базовые стоимости (за 1000 запросов)
        self.base_costs = {
            # Кастомные решения
            'custom_gpt4_turbo': 0.01,  # $10 per 1K requests
            'custom_gpt4': 0.03,       # $30 per 1K requests
            'custom_claude_opus': 0.04,  # $40 per 1K requests
            'agency_services': 500,    # $500 per month

            # Алакея агенты
            'alakeya_general': 0.002,   # $2 per 1K requests
            'alakeya_specialized': 0.005,  # $5 per 1K requests
            'alakeya_advanced': 0.01,     # $10 per 1K requests
        }

        # Временные затраты (часы в месяц)
        self.time_costs = {
            'custom_setup': 20,      # Настройка кастомного решения
            'custom_maintenance': 10, # Поддержка кастомного решения
            'alakeya_setup': 2,      # Настройка Алакеи
            'alakeya_maintenance': 1, # Поддержка Алакеи
        }

        # Качественные показатели
        self.quality_scores = {
            'custom_without_training': 0.65,
            'custom_with_training': 0.80,
            'alakeya_agent': 0.85,
            'alakeya_trained_agent': 0.92,
        }

    def calculate_monthly_benefit(
        self,
        monthly_requests: int = 1000,
        custom_setup_cost: float = 0,
        use_specialized_agents: bool = True
    ) -> Dict[str, Any]:
        """
        Рассчитывает ежемесячную выгоду использования Алакеи

        Args:
            monthly_requests: Количество запросов в месяц
            custom_setup_cost: Стоимость настройки кастомного решения
            use_specialized_agents: Использовать ли специализированных агентов

        Returns:
            {
                'monthly_savings': float,
                'annual_savings': float,
                'roi_percentage': float,
                'quality_improvement': float,
                'time_saved_hours': float,
                'break_even_requests': int
            }
        """
        # Стоимость кастомного решения
        if monthly_requests < 100:
            custom_model = 'custom_gpt4_turbo'
        elif monthly_requests < 500:
            custom_model = 'custom_gpt4'
        else:
            custom_model = 'custom_claude_opus'

        custom_monthly_cost = (
            self.base_costs[custom_model] * monthly_requests +
            custom_setup_cost / 12 +  # Амортизация настройки
            self.time_costs['custom_maintenance'] * 50  # $50/hour
        )

        # Стоимость Алакеи
        if use_specialized_agents:
            alakeya_model = 'alakeya_specialized'
            alakeya_quality = self.quality_scores['alakeya_trained_agent']
        else:
            alakeya_model = 'alakeya_general'
            alakeya_quality = self.quality_scores['alakeya_agent']

        alakeya_monthly_cost = (
            self.base_costs[alakeya_model] * monthly_requests +
            self.time_costs['alakeya_setup'] * 50 / 12 +  # Амортизация
            self.time_costs['alakeya_maintenance'] * 50  # $50/hour
        )

        # Вычисления
        monthly_savings = custom_monthly_cost - alakeya_monthly_cost
        annual_savings = monthly_savings * 12

        # ROI
        investment = alakeya_monthly_cost
        return_value = monthly_savings + custom_monthly_cost  # Общая выгода
        roi_percentage = ((return_value - investment) / investment) * 100 if investment > 0 else 0

        # Улучшение качества
        custom_quality = self.quality_scores['custom_with_training']
        quality_improvement = ((alakeya_quality - custom_quality) / custom_quality) * 100

        # Экономия времени
        time_saved_hours = (
            (self.time_costs['custom_setup'] + self.time_costs['custom_maintenance']) -
            (self.time_costs['alakeya_setup'] + self.time_costs['alakeya_maintenance'])
        )

        # Точка безубыточности
        break_even_requests = int(custom_setup_cost / (self.base_costs[custom_model] - self.base_costs[alakeya_model])) if custom_setup_cost > 0 else 0

        return {
            'monthly_savings': monthly_savings,
            'annual_savings': annual_savings,
            'roi_percentage': roi_percentage,
            'quality_improvement': quality_improvement,
            'time_saved_hours': time_saved_hours,
            'break_even_requests': break_even_requests,
            'cost_comparison': {
                'custom_monthly': custom_monthly_cost,
                'alakeya_monthly': alakeya_monthly_cost,
                'custom_model': custom_model,
                'alakeya_model': alakeya_model
            }
        }

    def generate_business_case(
        self,
        company_size: str = 'small',
        industry: str = 'general'
    ) -> Dict[str, Any]:
        """
        Генерирует бизнес-кейс для использования Алакеи

        Args:
            company_size: 'small', 'medium', 'large'
            industry: 'general', 'tech', 'marketing', 'consulting'
        """
        # Оценка количества запросов
        requests_by_size = {
            'small': (100, 500),
            'medium': (500, 2000),
            'large': (2000, 10000)
        }

        min_requests, max_requests = requests_by_size[company_size]

        # Специфические множители для индустрии
        industry_multipliers = {
            'general': 1.0,
            'tech': 1.5,      # Больше запросов на кодинг
            'marketing': 2.0,  # Много контента
            'consulting': 1.8  # Много анализа
        }

        multiplier = industry_multipliers.get(industry, 1.0)

        avg_requests = int((min_requests + max_requests) / 2 * multiplier)

        # Расчет выгоды
        benefit = self.calculate_monthly_benefit(
            monthly_requests=avg_requests,
            custom_setup_cost=2000 if company_size != 'small' else 500,
            use_specialized_agents=True
        )

        return {
            'company_profile': {
                'size': company_size,
                'industry': industry,
                'estimated_monthly_requests': avg_requests
            },
            'financial_benefits': {
                'monthly_savings': benefit['monthly_savings'],
                'annual_savings': benefit['annual_savings'],
                'roi_percentage': benefit['roi_percentage']
            },
            'quality_benefits': {
                'improvement_percentage': benefit['quality_improvement'],
                'customer_satisfaction': '+15%',
                'error_reduction': '+25%'
            },
            'operational_benefits': {
                'time_saved_hours_per_month': benefit['time_saved_hours'],
                'faster_time_to_market': '+40%',
                'employee_productivity': '+35%'
            },
            'recommendation': self._generate_recommendation(benefit)
        }

    def _generate_recommendation(self, benefit: Dict[str, Any]) -> str:
        """Генерирует рекомендацию на основе расчетов"""
        monthly_savings = benefit['monthly_savings']
        roi = benefit['roi_percentage']
        quality_improvement = benefit['quality_improvement']

        if monthly_savings > 1000 and roi > 300:
            return """
            🚀 РЕКОМЕНДУЕТСЯ НЕМЕДЛЕННОЕ ВНЕДРЕНИЕ

            Алакея покажет ОЧЕНЬ ВЫСОКУЮ рентабельность инвестиций.
            Ожидается экономия более $1000 в месяц при ROI более 300%.
            Качество улучшится на {:.0f}%.
            """.format(quality_improvement)
        elif monthly_savings > 500 and roi > 150:
            return """
            ✅ РЕКОМЕНДУЕТСЯ ВНЕДРЕНИЕ

            Алакея покажет ВЫСОКУЮ рентабельность инвестиций.
            Ожидается экономия более $500 в месяц при ROI более 150%.
            Качество улучшится на {:.0f}%.
            """.format(quality_improvement)
        else:
            return """
            🤔 РЕКОМЕНДУЕТСЯ ТЕСТИРОВАНИЕ

            Алакея может быть выгодна для вашего случая.
            Проведите тестовый период для оценки реальной выгоды.
            """

    def compare_scenarios(
        self,
        scenarios: List[Dict[str, Any]]
    ) -> Dict[str, Any]:
        """
        Сравнивает несколько сценариев использования

        Args:
            scenarios: List of {
                'name': str,
                'monthly_requests': int,
                'setup_cost': float,
                'use_specialized': bool
            }
        """
        results = []

        for scenario in scenarios:
            benefit = self.calculate_monthly_benefit(
                monthly_requests=scenario['monthly_requests'],
                custom_setup_cost=scenario.get('setup_cost', 0),
                use_specialized_agents=scenario.get('use_specialized', True)
            )

            results.append({
                'name': scenario['name'],
                'monthly_savings': benefit['monthly_savings'],
                'annual_savings': benefit['annual_savings'],
                'roi_percentage': benefit['roi_percentage'],
                'quality_improvement': benefit['quality_improvement']
            })

        # Находим лучший сценарий
        best_scenario = max(results, key=lambda x: x['annual_savings'])

        return {
            'scenarios': results,
            'best_scenario': best_scenario['name'],
            'total_annual_savings': sum(s['annual_savings'] for s in results)
        }


# Демонстрация
if __name__ == "__main__":
    optimizer = HermesCostOptimizer()

    print("💰 ЭКОНОМИЧЕСКАЯ МОДЕЛЬ АЛАКЕЯ\n")

    # Бизнес-кейсы для разных компаний
    company_profiles = [
        ('small', 'general'),
        ('medium', 'tech'),
        ('large', 'marketing')
    ]

    for size, industry in company_profiles:
        print(f"📊 {size.upper()} - {industry.upper()}")
        business_case = optimizer.generate_business_case(size, industry)

        profile = business_case['company_profile']
        financial = business_case['financial_benefits']
        quality = business_case['quality_benefits']

        print(f"   Запросов в месяц: {profile['estimated_monthly_requests']}")
        print(f"   💵 Месячная экономия: ${financial['monthly_savings']:.2f}")
        print(f"   📈 Годовая экономия: ${financial['annual_savings']:.2f}")
        print(f"   🎯 ROI: {financial['roi_percentage']:.0f}%")
        print(f"   ⭐ Улучшение качества: {quality['improvement_percentage']:.0f}%")
        print(f"   ⏰ Экономия времени: {business_case['operational_benefits']['time_saved_hours_per_month']} ч/мес")
        print(business_case['recommendation'])
        print()

    # Сравнение сценариев
    print("🔄 СРАВНЕНИЕ СЦЕНАРИЕВ:")

    scenarios = [
        {'name': 'Минимальное использование', 'monthly_requests': 100, 'setup_cost': 500, 'use_specialized': False},
        {'name': 'Базовое использование', 'monthly_requests': 500, 'setup_cost': 1000, 'use_specialized': True},
        {'name': 'Активное использование', 'monthly_requests': 2000, 'setup_cost': 2000, 'use_specialized': True},
    ]

    comparison = optimizer.compare_scenarios(scenarios)

    for scenario in comparison['scenarios']:
        print(f"   {scenario['name']}:")
        print(f"      Годовая экономия: ${scenario['annual_savings']:.2f}")
        print(f"      ROI: {scenario['roi_percentage']:.0f}%")

    print(f"\n   🏆 Лучший сценарий: {comparison['best_scenario']}")
    print(f"   💰 Общая годовая экономия: ${comparison['total_annual_savings']:.2f}")
