//
//  BuildertrendExporter.swift
//  Forge
//
//  Phase 4: Formats a ScopePacket for Buildertrend in two flavours —
//  a CSV file ready for task import, and structured field-notes text.
//

import Foundation

enum BuildertrendExporter {

    // MARK: - CSV Export

    /// Writes a CSV file to the temp directory and returns its URL.
    /// Columns: Job Name, Address, Trade, Task, Needs Confirmation, Status
    static func csvTempFile(packet: ScopePacket, project: Project) throws -> URL {
        let csv = csvString(packet: packet, project: project)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScopeSnap-Buildertrend-\(UUID().uuidString).csv")
        try Data(csv.utf8).write(to: url, options: .atomic)
        return url
    }

    // MARK: - Field Notes Export

    /// Returns structured plain text to paste directly into Buildertrend field notes.
    static func fieldNotesExport(packet: ScopePacket, project: Project) -> String {
        var lines: [String] = []

        lines.append("BUILDERTREND FIELD NOTES")
        lines.append("Job: \(project.name)")
        if !project.address.isEmpty {
            lines.append("Address: \(project.address)")
        }
        lines.append("Type: \(project.projectType.displayName)")
        lines.append("Generated: \(packet.generatedAt.formatted(date: .long, time: .shortened))")
        lines.append("")

        lines.append("--- SCOPE SUMMARY ---")
        lines.append(packet.scopeSummary)
        lines.append("")

        lines.append("--- TASKS BY TRADE ---")
        for (trade, tasks) in ExportModule.groupedByTrade(packet.tasksByTrade) {
            lines.append("")
            lines.append("[\(trade.uppercased())]")
            for task in tasks {
                let check = task.isApproved ? "☑" : "☐"
                let flag  = task.isQuestion ? " ❓" : ""
                lines.append("  \(check) \(task.taskDescription)\(flag)")
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Private helpers

    private static func csvString(packet: ScopePacket, project: Project) -> String {
        var rows: [String] = [
            csvRow(["Job Name", "Address", "Trade", "Task", "Needs Confirmation", "Status"])
        ]
        for (trade, tasks) in ExportModule.groupedByTrade(packet.tasksByTrade) {
            for task in tasks {
                rows.append(csvRow([
                    project.name,
                    project.address,
                    trade.capitalized,
                    task.taskDescription,
                    task.isQuestion ? "Yes" : "No",
                    task.isApproved ? "Approved" : "Draft"
                ]))
            }
        }
        return rows.joined(separator: "\n")
    }

    private static func csvRow(_ fields: [String]) -> String {
        fields.map { field in
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }.joined(separator: ",")
    }
}
