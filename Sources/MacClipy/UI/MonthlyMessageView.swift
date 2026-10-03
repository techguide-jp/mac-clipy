import SwiftUI

struct MonthlyMessageView: View {
    @Bindable var center: MonthlyMessageCenter
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label(L10n.tr("monthly.windowTitle"), systemImage: "envelope.open")
                .font(.headline)
            if let message = center.message {
                Text(message.title).font(.title2.bold())
                ScrollView {
                    Text(message.message)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Text(L10n.tr("monthly.surveyHelp")).font(.footnote).foregroundStyle(.secondary)
                HStack {
                    Link(L10n.tr("monthly.answerSurvey"), destination: message.surveyURL)
                        .buttonStyle(.borderedProminent)
                    Spacer()
                    Button(L10n.tr("monthly.close"), action: onClose)
                }
            } else if center.isLoading {
                ProgressView(L10n.tr("monthly.loading"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text(center.allowsFetching ? center.errorMessage : L10n.tr("monthly.unavailable"))
                    .foregroundStyle(.secondary)
                Spacer()
                HStack {
                    Button(L10n.tr("monthly.retry")) {
                        Task { await center.refresh(automatically: false, force: true) }
                    }
                    .disabled(!center.allowsFetching || center.isLoading)
                    Spacer()
                    Button(L10n.tr("monthly.close"), action: onClose)
                }
            }
        }
        .padding(24)
        .frame(width: 500, height: 350)
        .onAppear { center.markPresented() }
        .onChange(of: center.message) { _, _ in center.markPresented() }
    }
}
