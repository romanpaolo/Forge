//
//  ExportModule.swift
//  Forge
//
//  Feature 6: Formats a ScopePacket as markdown — used by copy-to-clipboard
//  and the share sheet in ScopeReviewView.
//

import Foundation

enum ExportModule {

    /// Returns a formatted Markdown string for the given ScopePacket,
    /// suitable for pasting into Buildertrend notes or emailing to a PM.
    static func markdownExport(packet: ScopePacket) -> String {
        var lines: [String] = []

        // Header
        lines.append("# Scope Packet")
        lines.append("**Generated:** \(packet.generatedAt.formatted(date: .abbreviated, time: .shortened))")
        lines.append("**Status:** \(packet.status.rawValue.capitalized)")
        lines.append("")

        // Scope summary
        lines.append("## Scope Summary")
        lines.append("")
        lines.append(packet.scopeSummary)
        lines.append("")

        // Tasks by trade
        let grouped = groupedByTrade(packet.tasksByTrade)
        guard !grouped.isEmpty else {
            return lines.joined(separator: "\n")
        }

        lines.append("## Tasks by Trade")
        lines.append("")
        for (trade, tasks) in grouped {
            lines.append("### \(trade.capitalized)")
            for task in tasks {
                let check = task.isApproved ? "[x]" : "[ ]"
                let flag = task.isQuestion ? " ❓" : ""
                lines.append("- \(check)\(flag) \(task.taskDescription)")
            }
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Private

    private static let tradeOrder = [
        "demo", "framing", "plumbing", "electrical", "HVAC",
        "drywall", "tile", "paint", "carpentry", "flooring",
        "roofing", "windows", "doors", "other"
    ]

    static func groupedByTrade(_ tasks: [TradeTask]) -> [(String, [TradeTask])] {
        let dict = Dictionary(grouping: tasks, by: \.trade)
        let known = tradeOrder
            .filter { dict[$0] != nil }
            .map { ($0, dict[$0]!) }
        let unknown = dict.keys
            .filter { !tradeOrder.contains($0) }
            .sorted()
            .map { ($0, dict[$0]!) }
        return known + unknown
    }
}
