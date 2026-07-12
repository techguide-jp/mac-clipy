import AppKit
import SwiftUI

struct OnboardingView: View {
    let isAccessibilityTrusted: () -> Bool
    let requestAccessibilityPermission: () -> Bool
    let onFinish: () -> Void

    @State private var accessibilityTrusted: Bool
    @State private var permissionRequested = false

    init(
        isAccessibilityTrusted: @escaping () -> Bool,
        requestAccessibilityPermission: @escaping () -> Bool,
        onFinish: @escaping () -> Void
    ) {
        self.isAccessibilityTrusted = isAccessibilityTrusted
        self.requestAccessibilityPermission = requestAccessibilityPermission
        self.onFinish = onFinish
        _accessibilityTrusted = State(initialValue: isAccessibilityTrusted())
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            VStack(spacing: 0) {
                OnboardingStepRow(
                    icon: "menubar.rectangle",
                    title: L10n.tr("onboarding.menuBar.title"),
                    description: L10n.tr("onboarding.menuBar.description")
                ) {
                    Image(systemName: "clipboard")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }

                Divider()

                OnboardingStepRow(
                    icon: "keyboard",
                    title: L10n.tr("onboarding.shortcut.title"),
                    description: L10n.tr("onboarding.shortcut.description")
                ) {
                    Text(verbatim: "⇧⌘V")
                        .font(.system(.body, design: .monospaced, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                        .accessibilityLabel(L10n.tr("onboarding.shortcut.accessibilityLabel"))
                }

                Divider()

                OnboardingStepRow(
                    icon: "hand.raised",
                    title: L10n.tr("onboarding.accessibility.title"),
                    description: L10n.tr("onboarding.accessibility.description")
                ) {
                    accessibilityControl
                }
            }
            .padding(.horizontal, 28)

            Spacer(minLength: 20)

            footer
        }
        .frame(width: 680, height: 470)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            accessibilityTrusted = isAccessibilityTrusted()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            accessibilityTrusted = isAccessibilityTrusted()
        }
    }

    private var header: some View {
        HStack(spacing: 18) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 72, height: 72)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.tr("onboarding.title"))
                    .font(.largeTitle.bold())
                Text(L10n.tr("onboarding.subtitle"))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.horizontal, 28)
        .padding(.top, 26)
        .padding(.bottom, 18)
    }

    @ViewBuilder
    private var accessibilityControl: some View {
        if accessibilityTrusted {
            Label(L10n.tr("onboarding.accessibility.enabled"), systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.callout.weight(.semibold))
        } else {
            VStack(alignment: .trailing, spacing: 6) {
                Button {
                    permissionRequested = true
                    accessibilityTrusted = requestAccessibilityPermission()
                } label: {
                    Label(
                        L10n.tr("onboarding.accessibility.enable"),
                        systemImage: "gearshape"
                    )
                }

                if permissionRequested {
                    Text(L10n.tr("onboarding.accessibility.requested"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 20) {
            Label {
                Text(L10n.tr("onboarding.privacy"))
            } icon: {
                Image(systemName: "lock")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Spacer()

            Button {
                onFinish()
            } label: {
                Text(L10n.tr("onboarding.finish"))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

private struct OnboardingStepRow<Accessory: View>: View {
    let icon: String
    let title: String
    let description: String
    @ViewBuilder let accessory: Accessory

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 34)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: title)
                    .font(.headline)
                Text(verbatim: description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 18)

            accessory
                .frame(maxWidth: 210, alignment: .trailing)
        }
        .padding(.vertical, 17)
    }
}
