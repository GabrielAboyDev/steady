import SwiftUI

/// The enable-the-keyboard flow (US-005).
struct OnboardingView: View {

    @EnvironmentObject private var store: SharedStore
    @State private var isEnabled = KeyboardInstallState.isEnabled

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    statusBanner
                    steps
                    openSettingsButton
                    privacyNote
                }
                .padding(20)
            }
            .background(Theme.surfaceBase)
            .navigationTitle("Setup")
            .onAppear(perform: refreshStatus)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Almost ready")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text("One quick setup in iOS Settings and your predictive keyboard works in every app.")
                .font(.system(size: 16))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var statusBanner: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(isEnabled ? Theme.positive : Theme.caution)
                .frame(width: 9, height: 9)
            Text(isEnabled ? "Keyboard enabled" : "Keyboard not enabled yet")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isEnabled ? Theme.positive : Theme.caution)
            Spacer(minLength: 0)
            Button("Check again", action: refreshStatus)
                .font(.system(size: 14, weight: .semibold))
        }
        .padding(14)
        .background(isEnabled ? Theme.positive.opacity(0.1) : Theme.caution.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

    private var steps: some View {
        VStack(spacing: 12) {
            stepCard(
                number: 1,
                title: "Open Settings",
                detail: "Tap the button below to jump to this app in Settings, then choose Keyboards."
            )
            stepCard(
                number: 2,
                title: "Add “Steady”",
                detail: "Tap Keyboards, then Add New Keyboard… and pick Steady from the list."
            )
            stepCard(
                number: 3,
                title: "Switch with the globe 🌐",
                detail: "In any app, hold the globe key and pick Steady to start typing."
            )
        }
    }

    private func stepCard(number: Int, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(number)")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Theme.brand)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(detail)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Theme.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius)
                .strokeBorder(Theme.ruleHairline, lineWidth: 1)
        )
    }

    private var openSettingsButton: some View {
        Button {
            KeyboardInstallState.openSettings()
        } label: {
            Text("Open Keyboard Settings")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(
                    LinearGradient(
                        colors: [Theme.brand, Theme.brandDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var privacyNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("🔒").font(.system(size: 18))
            Text("No “Allow Full Access” required. All prediction runs on your device — nothing you type ever leaves your phone.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Theme.brandSoft.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

    private func refreshStatus() {
        store.reload()
        isEnabled = KeyboardInstallState.isEnabled
    }
}
