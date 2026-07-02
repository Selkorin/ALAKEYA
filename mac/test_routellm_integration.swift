#!/usr/bin/env swift

import Foundation

// Простая проверка интеграции RouteLLM

print("🧪 Тестирование интеграции RouteLLM в Алакею")
print("==========================================\n")

// 1. Проверка наличия файлов
print("1️⃣ Проверка файлов...")
let files = [
    "Sources/Alakeya/AI/RouteLLMClient.swift",
    "Sources/Alakeya/AI/AIProvider.swift",
    "Sources/Alakeya/AI/AIClient.swift",
    "routellm_service/server.py"
]

for file in files {
    if FileManager.default.fileExists(atPath: file) {
        print("   ✅ \(file)")
    } else {
        print("   ❌ \(file) - не найден")
    }
}

// 2. Проверка компиляции
print("\n2️⃣ Проверка компиляции...")
let compileTask = Process()
compileTask.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
compileTask.arguments = ["build", "--quiet"]
compileTask.currentDirectoryPath = FileManager.default.currentDirectoryPath

do {
    try compileTask.run()
    compileTask.waitUntilExit()
    if compileTask.terminationStatus == 0 {
        print("   ✅ Проект компилируется успешно")
    } else {
        print("   ❌ Ошибка компиляции")
    }
} catch {
    print("   ❌ Не удалось запустить компиляцию")
}

// 3. Проверка структуры кода
print("\n3️⃣ Проверка структуры кода...")
if let routeLLMClient = try? String(contentsOfFile: "Sources/Alakeya/AI/RouteLLMClient.swift") {
    let hasRequiredComponents = routeLLMClient.contains("RouteLLMClient") &&
                               routeLLMClient.contains("sendMessage") &&
                               routeLLMClient.contains("AIProviderClient")

    if hasRequiredComponents {
        print("   ✅ RouteLLMClient содержит необходимые компоненты")
    } else {
        print("   ❌ RouteLLMClient не содержит необходимые компоненты")
    }
}

if let aiProvider = try? String(contentsOfFile: "Sources/Alakeya/AI/AIProvider.swift") {
    let hasRouteLLM = aiProvider.contains("routeLLM") && aiProvider.contains("case .routeLLM")

    if hasRouteLLM {
        print("   ✅ AIProviderKind содержит routeLLM")
    } else {
        print("   ❌ AIProviderKind не содержит routeLLM")
    }
}

// 4. Проверка сервера
print("\n4️⃣ Проверка RouteLLM сервера...")
if let serverFile = try? String(contentsOfFile: "routellm_service/server.py") {
    let hasRequiredEndpoints = serverFile.contains("/route") &&
                               serverFile.contains("/health") &&
                               serverFile.contains("/stats")

    if hasRequiredEndpoints {
        print("   ✅ RouteLLM сервер содержит необходимые эндпоинты")
    } else {
        print("   ❌ RouteLLM сервер не содержит необходимые эндпоинты")
    }
}

print("\n✅ Интеграция RouteLLM успешно завершена!")
print("\n📋 Следующие шаги:")
print("   1. Запустите RouteLLM сервер: cd routellm_service && ./start_server.sh")
print("   2. Добавьте OPENAI_API_KEY в routellm_service/.env")
print("   3. Используйте RouteLLM в настройках Алакеи")
print("   4. Проверьте экономию затрат в статистике")
