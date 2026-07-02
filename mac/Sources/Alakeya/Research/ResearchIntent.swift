import Foundation

// ============================================================
// ResearchIntent.swift — classifies user query intent for
// research-oriented tasks. Drives query planning and playbook
// selection.
// ============================================================

enum ResearchIntent: String, CaseIterable {
    case factualQuestion    = "factual_question"
    case currentInfo        = "current_info"
    case topList            = "top_list"
    case localBusinessSearch = "local_business_search"
    case contactResearch    = "contact_research"
    case clientResearch     = "client_research"
    case travelResearch     = "travel_research"
    case hotelResearch      = "hotel_research"
    case productResearch    = "product_research"
    case academicResearch   = "academic_research"
    case seoResearch        = "seo_research"
    case documentResearch   = "document_research"
    case tableResearch      = "table_research"
    case socialProfileResearch = "social_profile_research"
    case exportTask         = "export_task"
    case general            = "general"

    var playbook: String {
        switch self {
        case .hotelResearch, .travelResearch:     return "TopHotelsPlaybook"
        case .localBusinessSearch, .contactResearch, .clientResearch: return "LocalBusinessContactsPlaybook"
        case .factualQuestion, .currentInfo, .academicResearch: return "FactCheckPlaybook"
        case .seoResearch:                        return "SEOResearchPlaybook"
        case .exportTask, .documentResearch, .tableResearch: return "DocumentReportPlaybook"
        case .socialProfileResearch:              return "PeopleResearchPlaybook"
        default:                                   return "GeneralResearchPlaybook"
        }
    }

    var minSources: Int {
        switch self {
        case .topList, .hotelResearch, .travelResearch:            return 3
        case .localBusinessSearch, .contactResearch, .clientResearch: return 2
        case .factualQuestion:                                      return 2
        case .seoResearch:                                          return 1
        default:                                                    return 2
        }
    }

    var minResults: Int {
        switch self {
        case .topList, .hotelResearch:   return 5
        case .localBusinessSearch, .contactResearch, .clientResearch: return 3
        default:                          return 1
        }
    }

    // MARK: - Detection from user query

    static func detect(from query: String) -> ResearchIntent {
        let lower = query.lowercased()

        // Export task first (highest priority)
        if matches(lower, patterns: ["выгрузи", "экспорт", "сохрани.*pdf", "сделай.*word", "сделай.*docx",
                                      "сделай.*excel", "xlsx", "export.*pdf", "export.*csv", "в pdf", "в docx",
                                      "в csv", "в excel", "download", "сохранить.*файл"]) {
            return .exportTask
        }

        // SEO/Technical audit
        if matches(lower, patterns: ["seo", "сео", "аудит.*сайт", "аудит.*страниц", "title.*description",
                                      "мета.{0,5}тег", "h1 сайт", "оптимизаци", "технический.*анализ",
                                      "robots\\.txt", "sitemap", "canonical", "structured data"]) {
            return .seoResearch
        }

        // Hotels/travel with enhanced detection
        if matches(lower, patterns: ["отел", "гостиниц", "санатори", "resort", "hotel", "hostel",
                                      "куда поехать", "тур.*кур", "путешеств", "тур", "экскурс",
                                      "проживан", "размещен"]) {
            return (lower.contains("топ") || lower.contains("лучш") || lower.contains("рейтинг") ||
                   lower.contains("сравн") || lower.contains("выб"))
                ? .hotelResearch : .travelResearch
        }

        // Enhanced business detection with categories
        let businessPatterns = [
            "салон", "кафе", "ресторан", "парикмахер", "стоматолог", "клиник", "автосервис",
            "магазин", "компани", "фирм", "предприят", "организ", "барбершоп", "спа", "фитнес",
            "трениров", "сервис", "ремонт", "услуг", "аптек", "банк", "страх"
        ]

        let hasBusinessTerm = businessPatterns.contains { lower.contains($0) }

        if hasBusinessTerm {
            return matches(lower, patterns: ["контакт", "телефон", "адрес", "email", "сайт",
                                              "работ", "час", "расписан"])
                ? .contactResearch : .localBusinessSearch
        }

        // Contact research explicit
        if matches(lower, patterns: ["найди.*контакт", "собери.*контакт", "контакты.*организ",
                                      "телефон.*компани", "email.*компани", "контактн",
                                      "почт.*адрес", "связ"]) {
            return .contactResearch
        }

        // Social/people research
        if matches(lower, patterns: ["вконтакте", "инстаграм", "профил", "страниц.*пользовател",
                                      "соцсет", "найди.*человек", "информаци.*person", "biograph",
                                      "личност", "публичн.*человек"]) {
            return .socialProfileResearch
        }

        // Enhanced top list detection
        if matches(lower, patterns: ["топ \\d", "топ-\\d", "лучш", "рейтинг", "топ.*компани",
                                      "список.*лучш", "сравни.*вариант", "выб", "recommend",
                                      "критер", "что лучше"]) {
            return .topList
        }

        // Table/data research
        if matches(lower, patterns: ["таблиц", "csv", "xlsx", "spreadsheet", "собери.*данн",
                                      "составь.*список", "выгруз.*данн", "собер.*информ"]) {
            return .tableResearch
        }

        // Academic/fact checking
        if matches(lower, patterns: ["исследован", "научн", "стать", "публикаци", "источник",
                                      "докажи", "подтверди", "проверь.*факт", "верн.*ли",
                                      "эксперимент", "статистик", "данн.*подтвержд"]) {
            return .academicResearch
        }

        // Current/time-sensitive info
        if matches(lower, patterns: ["сейчас", "сегодня", "\\d{4}.*год", "актуальн", "последн.*новост",
                                      "последние данн", "свежий", "новост", "текущ", "сегодн"]) {
            return .currentInfo
        }

        // Client/lead research
        if matches(lower, patterns: ["клиент", "потенциальн", "лид", "lead", "база.*клиент",
                                      "целев.*аудитор", "покупател"]) {
            return .clientResearch
        }

        // Product research
        if matches(lower, patterns: ["покупк", "куп", "цен", "магазин", "характерист",
                                      "обзор.*товар", "сравн.*товар", "выб.*товар"]) {
            return .productResearch
        }

        return .general
    }

    private static func matches(_ text: String, patterns: [String]) -> Bool {
        patterns.contains {
            text.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil
        }
    }
}
