import Foundation

struct RecapLabels: Equatable {
    var summary: String
    var decisions: String
    var actionItems: String
    var nextSteps: String
    var followUpEmail: String
}

extension RecapLanguage {
    var labels: RecapLabels {
        switch self {
        case .english:
            RecapLabels(
                summary: "Summary",
                decisions: "Decisions",
                actionItems: "Action Items",
                nextSteps: "Next Steps",
                followUpEmail: "Follow-up Email"
            )
        case .arabic:
            RecapLabels(
                summary: "الملخص",
                decisions: "القرارات",
                actionItems: "المهام",
                nextSteps: "الخطوات التالية",
                followUpEmail: "بريد المتابعة"
            )
        case .urdu:
            RecapLabels(
                summary: "خلاصہ",
                decisions: "فیصلے",
                actionItems: "اقدامات",
                nextSteps: "اگلے مراحل",
                followUpEmail: "فالو اپ ای میل"
            )
        }
    }
}

extension MeetingRecap {
    func shareText() -> String {
        let labels = language.labels
        var lines: [String] = [labels.summary, tldr]
        if !decisions.isEmpty {
            lines.append("")
            lines.append(labels.decisions)
            decisions.forEach { lines.append("- \($0)") }
        }
        if !actionItems.isEmpty {
            lines.append("")
            lines.append(labels.actionItems)
            actionItems.forEach { item in
                let meta = [item.owner.map { "owner: \($0)" }, item.due.map { "due: \($0)" }]
                    .compactMap { $0 }
                    .joined(separator: ", ")
                if meta.isEmpty {
                    lines.append("- \(item.task)")
                } else {
                    lines.append("- \(item.task) (\(meta))")
                }
            }
        }
        if !nextSteps.isEmpty {
            lines.append("")
            lines.append(labels.nextSteps)
            nextSteps.forEach { lines.append("- \($0)") }
        }
        if !followUpEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("")
            lines.append(labels.followUpEmail)
            lines.append(followUpEmail)
        }
        return lines.joined(separator: "\n")
    }
}
