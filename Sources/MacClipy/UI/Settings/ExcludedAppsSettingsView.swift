import SwiftUI

struct ExcludedAppsSettingsView: View {
    @Bindable var model: SettingsModel
    @State private var selectedExcludedApp: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "eye.slash")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 32, height: 32)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 7))

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.tr("settings.excludedApps.title"))
                        .font(.headline)
                    Text(L10n.tr("settings.excludedApps.help"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            List(selection: $selectedExcludedApp) {
                ForEach(model.excludedBundleIdentifiers, id: \.self) { bundleIdentifier in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: SettingsDefaults.displayName(for: bundleIdentifier))
                        Text(verbatim: bundleIdentifier)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .padding(.vertical, 2)
                    .tag(bundleIdentifier)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 8) {
                Button {
                    model.chooseExcludedApp()
                } label: {
                    Label(L10n.tr("settings.excludedApps.add"), systemImage: "plus")
                }

                Button {
                    if let selectedExcludedApp {
                        model.removeExcludedApp(selectedExcludedApp)
                        self.selectedExcludedApp = nil
                    }
                } label: {
                    Label(L10n.tr("settings.excludedApps.remove"), systemImage: "minus")
                }
                .disabled(selectedExcludedApp == nil)

                Button {
                    model.resetExcludedApps()
                    selectedExcludedApp = nil
                } label: {
                    Label(L10n.tr("settings.excludedApps.reset"), systemImage: "arrow.counterclockwise")
                }

                Spacer()

                Text(verbatim: model.statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 2)
        .padding(.top, 18)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
