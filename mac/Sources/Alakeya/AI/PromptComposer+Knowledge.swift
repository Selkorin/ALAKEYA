import Foundation

extension PromptComposer {
    static func composeWithSkillAndKnowledge() -> String {
        let base = composeWithSkill()
        let connectors = connectorsSystemBlock()
        let knowledge = KnowledgeStore.shared.composeContext()
        return [base, connectors, knowledge]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n\n---\n\n")
    }
}
