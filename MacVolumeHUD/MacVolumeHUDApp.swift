//
//  MacVolumeHUDApp.swift
//  MacVolumeHUD
//
//  Created by 고정근 on 3/11/26.
//

import SwiftUI
import AppKit
import ApplicationServices

enum HUDSize: String, CaseIterable {
    case small = "Small"
    case medium = "Medium"
    case large = "Large"
    
    var scale: CGFloat {
        switch self {
        case .small: return 0.75
        case .medium: return 1.0
        case .large: return 1.25
        }
    }
}

@main
struct MacVolumeHUDApp: App {
    @StateObject private var volumeManager = VolumeManager()
    @AppStorage("hudSize") private var hudSize: HUDSize = .medium
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showOnboarding = false

    init() {
        _ = BrightnessManager.shared
    }
    
    var body: some Scene {
        Window("MacVolumeHUD", id: "main") {
            SettingsHomeView(
                volumeManager: volumeManager,
                hudSize: $hudSize,
                showOnboarding: $showOnboarding
            )
                .onAppear {
                    if !hasSeenOnboarding {
                        showOnboarding = true
                    }
                }
                .sheet(isPresented: $showOnboarding) {
                    OnboardingView(
                        hasSeenOnboarding: $hasSeenOnboarding,
                        showOnboarding: $showOnboarding
                    )
                }
        }
        .windowResizability(.contentSize)

        MenuBarExtra("MacVolumeHUD", systemImage: "speaker.wave.2.fill") {
            MenuBarContentView(volumeManager: volumeManager)
        }
    }
}

private struct SettingsHomeView: View {
    @ObservedObject var volumeManager: VolumeManager
    @Binding var hudSize: HUDSize
    @Binding var showOnboarding: Bool
    @AppStorage(BrightnessManager.isEnabledDefaultsKey) private var brightnessHUDEnabled = false
    @State private var hasAccessibilityAccess = AXIsProcessTrusted()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            statusSection
            appearanceSection
            behaviorSection
        }
        .padding(24)
        .frame(width: 420)
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .underPageBackgroundColor)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .onAppear(perform: refreshAccessibilityStatus)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshAccessibilityStatus()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("MacVolumeHUD")
                .font(.system(size: 24, weight: .semibold))
            Text("Bring back the old centered Mac volume display with a cleaner Apple-style overlay.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var statusSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Status")
                    .font(.headline)

                VStack(spacing: 0) {
                    statusRow(label: "Output", value: volumeManager.activeDeviceName)
                    Divider().opacity(0.5)
                    statusRow(label: "Volume", value: "\(Int(volumeManager.volume * 100))%")
                    Divider().opacity(0.5)
                    statusRow(label: "HUD Size", value: hudSize.rawValue)
                    Divider().opacity(0.5)
                    statusRow(label: "State", value: volumeManager.isMuted ? "Muted" : "Live")
                }
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.black.opacity(0.04))
                )

                HStack {
                    Spacer()
                    Button {
                        NSApplication.shared.terminate(nil)
                    } label: {
                        Text("Quit")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.red)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var appearanceSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Appearance")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    Text("HUD Size")
                        .font(.subheadline.weight(.medium))
                    Picker("HUD Size", selection: $hudSize) {
                        ForEach(HUDSize.allCases, id: \.self) { size in
                            Text(size.rawValue).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .onChange(of: hudSize) {
                    HUDWindowManager.shared.showHUD(volumeManager: volumeManager)
                }

                Text("Changing the size immediately shows the real HUD on screen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var behaviorSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Behavior")
                    .font(.headline)

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Accessibility Access")
                            .font(.subheadline.weight(.medium))
                        Text(hasAccessibilityAccess ? "Enabled" : "Required for media key interception")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(hasAccessibilityAccess ? "Ready" : "Needs Setup")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(hasAccessibilityAccess ? Color.green : Color.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill((hasAccessibilityAccess ? Color.green : Color.orange).opacity(0.12))
                        )
                }

                if !hasAccessibilityAccess {
                    Button("Open Accessibility Settings") {
                        openAccessibilitySettings()
                    }
                    .buttonStyle(.bordered)
                }

                Button("Open Setup Guide") {
                    showOnboarding = true
                }
                .buttonStyle(.link)

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Toggle(isOn: $brightnessHUDEnabled) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Replace Brightness HUD")
                                .font(.subheadline.weight(.medium))
                            Text("Use the classic centered HUD for brightness keys too.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)

                    if brightnessHUDEnabled && !BrightnessManager.shared.canControlBrightness {
                        Text("Brightness replacement is only available when macOS exposes brightness control for the current display.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("Tips")
                        .font(.subheadline.weight(.medium))
                    Text("Use Option + Shift while pressing volume or brightness keys for fine adjustment.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Volume and brightness keys now share the same centered classic HUD style.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func statusRow(label: String, value: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)

            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.72))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
    }


    private func refreshAccessibilityStatus() {
        hasAccessibilityAccess = AXIsProcessTrusted()
        MediaKeyInterceptor.shared.refreshPermissionState()
    }

    private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

private struct MenuBarContentView: View {
    @ObservedObject var volumeManager: VolumeManager
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            Button("Open MacVolumeHUD") {
                openWindow(id: "main")
                NSApplication.shared.activate(ignoringOtherApps: true)
            }

            Divider()

            Button("Quit MacVolumeHUD") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

private struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool
    @Binding var showOnboarding: Bool
    @State private var hasAccessibilityAccess = AXIsProcessTrusted()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Set Up MacVolumeHUD")
                    .font(.system(size: 24, weight: .semibold))
                Text("MacVolumeHUD replaces the stock macOS volume indicator by intercepting the media keys before the system HUD appears.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            onboardingCard {
                onboardingRow(
                    number: "1",
                    title: "Allow Accessibility Access",
                    detail: "Open System Settings and enable MacVolumeHUD in Privacy & Security > Accessibility."
                )
                onboardingRow(
                    number: "2",
                    title: "Return and test the volume keys",
                    detail: "Once permission is enabled, MacVolumeHUD can show the centered classic HUD instead of the stock one."
                )
                onboardingRow(
                    number: "3",
                    title: "If the stock HUD still appears",
                    detail: "Quit and reopen MacVolumeHUD after granting permission. macOS can keep using the old input path until the app restarts."
                )
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Accessibility Status")
                        .font(.subheadline.weight(.medium))
                    Text(hasAccessibilityAccess ? "Ready" : "Needs Setup")
                        .font(.caption)
                        .foregroundStyle(hasAccessibilityAccess ? Color.green : Color.orange)
                }

                Spacer()

                Button("Open Accessibility Settings") {
                    openAccessibilitySettings()
                }
                .buttonStyle(.borderedProminent)
            }

            HStack {
                Button("Not Now") {
                    hasSeenOnboarding = true
                    showOnboarding = false
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Continue") {
                    hasSeenOnboarding = true
                    showOnboarding = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 460)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear(perform: refreshAccessibilityStatus)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshAccessibilityStatus()
        }
    }

    private func onboardingCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }

    private func onboardingRow(number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.06))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func refreshAccessibilityStatus() {
        hasAccessibilityAccess = AXIsProcessTrusted()
        MediaKeyInterceptor.shared.refreshPermissionState()
    }

    private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
