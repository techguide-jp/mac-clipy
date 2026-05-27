import AppKit
import SwiftUI

struct DevelopmentCrashReportView: View {
    let report: DevelopmentCrashReport
    let onClose: () -> Void

    @State private var statusMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            message
            logPath
            logBody
            footer
        }
        .padding(20)
        .frame(width: 720, height: 560)
    }

    private var header: some View {
        HStack {
            Text(L10n.tr("developmentCrashReport.title"))
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .accessibilityLabel(L10n.tr("button.close"))
            }
            .buttonStyle(.plain)
            .help(L10n.tr("button.close"))
        }
    }

    private var message: some View {
        Text(L10n.tr("developmentCrashReport.message", formattedDate(report.previousLaunchDate)))
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var logPath: some View {
        if let logURL = report.logURL {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.tr("developmentCrashReport.logPath"))
                    .font(.headline)
                Text(verbatim: logURL.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    private var logBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            if report.isLogTruncated {
                Text(L10n.tr("developmentCrashReport.logTruncated"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                Text(verbatim: displayLogText)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(10)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor))
            )
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if let statusMessage {
                Text(verbatim: statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                copyLog()
            } label: {
                Label(L10n.tr("developmentCrashReport.copyLog"), systemImage: "doc.on.doc")
            }

            Button {
                revealLogInFinder()
            } label: {
                Label(L10n.tr("developmentCrashReport.revealInFinder"), systemImage: "folder")
            }
            .disabled(report.logURL == nil)

            Button(L10n.tr("button.close")) {
                onClose()
            }
            .keyboardShortcut(.defaultAction)
        }
    }

    private var displayLogText: String {
        if !report.logText.isEmpty {
            return report.logText
        }

        return L10n.tr("developmentCrashReport.logMissing")
    }

    private func formattedDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .standard)
    }

    private func copyLog() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(clipboardText, forType: .string)
        statusMessage = L10n.tr("developmentCrashReport.copied")
    }

    private func revealLogInFinder() {
        guard let logURL = report.logURL else {
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([logURL])
    }

    private var clipboardText: String {
        var sections: [String] = [
            L10n.tr("developmentCrashReport.message", formattedDate(report.previousLaunchDate))
        ]

        if let logURL = report.logURL {
            sections.append("\(L10n.tr("developmentCrashReport.logPath")): \(logURL.path)")
        }

        sections.append(displayLogText)

        return sections.joined(separator: "\n\n")
    }
}
