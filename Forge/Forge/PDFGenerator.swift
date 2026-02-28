//
//  PDFGenerator.swift
//  Forge
//
//  Phase 3, Feature: PDF packet generation.
//  Renders a ScopePacket + Project metadata to a letter-size PDF using
//  UIGraphicsPDFRenderer and NSAttributedString for selectable text.
//

import UIKit
import Foundation

@MainActor
enum PDFGenerator {

    // MARK: - Page metrics

    private static let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)  // US Letter
    private static let margin: CGFloat = 56
    private static var contentWidth: CGFloat { pageRect.width - margin * 2 }
    private static var contentBottom: CGFloat { pageRect.height - margin }

    // MARK: - Public API

    /// Renders packet + project header to a PDF in the temp directory.
    /// Returns the URL of the generated file — suitable for `UIActivityViewController`.
    static func generate(packet: ScopePacket, project: Project) throws -> URL {
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScopeSnap-\(UUID().uuidString).pdf")

        try renderer.writePDF(to: url) { ctx in
            ctx.beginPage()
            var y: CGFloat = margin

            y = drawHeader(project: project, packet: packet, ctx: ctx, y: y)
            y += 12
            y = drawScopeSummary(packet.scopeSummary, ctx: ctx, y: y)
            y += 14
            drawTasksByTrade(packet.tasksByTrade, ctx: ctx, y: &y)
        }

        return url
    }

    // MARK: - Section renderers

    private static func drawHeader(
        project: Project,
        packet: ScopePacket,
        ctx: UIGraphicsPDFRendererContext,
        y: CGFloat
    ) -> CGFloat {
        var y = y
        y = draw("SCOPE PACKET", style: .eyebrow, ctx: ctx, y: y)
        y += 2
        y = draw(project.name, style: .title, ctx: ctx, y: y)
        if !project.address.isEmpty {
            y = draw(project.address, style: .subtitle, ctx: ctx, y: y)
        }
        y = draw(
            "Type: \(project.projectType.displayName)  |  " +
            "Generated: \(packet.generatedAt.formatted(date: .long, time: .shortened))  |  " +
            "Status: \(packet.status.rawValue.capitalized)",
            style: .caption,
            ctx: ctx,
            y: y
        )
        y += 8
        return drawRule(ctx: ctx, y: y)
    }

    private static func drawScopeSummary(
        _ summary: String,
        ctx: UIGraphicsPDFRendererContext,
        y: CGFloat
    ) -> CGFloat {
        var y = y
        y = draw("SCOPE SUMMARY", style: .sectionHeader, ctx: ctx, y: y)
        y += 4
        return draw(summary, style: .body, ctx: ctx, y: y)
    }

    private static func drawTasksByTrade(
        _ tasks: [TradeTask],
        ctx: UIGraphicsPDFRendererContext,
        y: inout CGFloat
    ) {
        let groups = ExportModule.groupedByTrade(tasks)
        guard !groups.isEmpty else { return }

        y = checkPageBreak(needed: 48, ctx: ctx, y: y)
        y = draw("TASKS BY TRADE", style: .sectionHeader, ctx: ctx, y: y)
        y += 6

        for (trade, tradeTasks) in groups {
            y = checkPageBreak(needed: 40, ctx: ctx, y: y)
            y = draw(trade.uppercased(), style: .tradeHeader, ctx: ctx, y: y)
            y += 2

            for task in tradeTasks {
                y = checkPageBreak(needed: 18, ctx: ctx, y: y)
                let check = task.isApproved ? "☑" : "☐"
                let flag  = task.isQuestion ? "❓  " : "    "
                y = draw(
                    "\(check)  \(flag)\(task.taskDescription)",
                    style: task.isQuestion ? .questionTask : .task,
                    ctx: ctx,
                    y: y,
                    indent: 8
                )
            }
            y += 10
        }
    }

    // MARK: - Text styles

    private enum Style {
        case eyebrow, title, subtitle, caption
        case sectionHeader, tradeHeader
        case body, task, questionTask

        var font: UIFont {
            switch self {
            case .eyebrow:       return .systemFont(ofSize: 9, weight: .semibold)
            case .title:         return .boldSystemFont(ofSize: 20)
            case .subtitle:      return .systemFont(ofSize: 13)
            case .caption:       return .systemFont(ofSize: 10)
            case .sectionHeader: return .boldSystemFont(ofSize: 11)
            case .tradeHeader:   return .boldSystemFont(ofSize: 10)
            case .body:          return .systemFont(ofSize: 10)
            case .task:          return .systemFont(ofSize: 10)
            case .questionTask:  return .italicSystemFont(ofSize: 10)
            }
        }

        var color: UIColor {
            switch self {
            case .eyebrow:       return .systemGray
            case .title:         return .black
            case .subtitle:      return .darkGray
            case .caption:       return .systemGray
            case .sectionHeader: return .black
            case .tradeHeader:   return .darkGray
            case .body:          return .black
            case .task:          return .black
            case .questionTask:  return UIColor(red: 0.75, green: 0.35, blue: 0, alpha: 1)
            }
        }

        var lineSpacing: CGFloat {
            switch self {
            case .title: return 4
            case .body:  return 3
            default:     return 2
            }
        }
    }

    // MARK: - Drawing primitives

    @discardableResult
    private static func draw(
        _ text: String,
        style: Style,
        ctx: UIGraphicsPDFRendererContext,
        y: CGFloat,
        indent: CGFloat = 0
    ) -> CGFloat {
        let x     = margin + indent
        let width = contentWidth - indent

        let para = NSMutableParagraphStyle()
        para.lineSpacing = style.lineSpacing

        let attrs: [NSAttributedString.Key: Any] = [
            .font:           style.font,
            .foregroundColor: style.color,
            .paragraphStyle: para,
        ]

        let textHeight = text.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs,
            context: nil
        ).height

        text.draw(in: CGRect(x: x, y: y, width: width, height: textHeight), withAttributes: attrs)
        return y + textHeight + style.lineSpacing + 2
    }

    @discardableResult
    private static func drawRule(ctx: UIGraphicsPDFRendererContext, y: CGFloat) -> CGFloat {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: margin, y: y))
        path.addLine(to: CGPoint(x: pageRect.width - margin, y: y))
        UIColor.lightGray.setStroke()
        path.lineWidth = 0.5
        path.stroke()
        return y + 10
    }

    @discardableResult
    private static func checkPageBreak(
        needed: CGFloat,
        ctx: UIGraphicsPDFRendererContext,
        y: CGFloat
    ) -> CGFloat {
        if y + needed > contentBottom {
            ctx.beginPage()
            return margin
        }
        return y
    }
}
