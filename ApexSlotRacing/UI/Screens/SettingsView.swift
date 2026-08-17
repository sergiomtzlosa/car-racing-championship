import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var app: AppModel
    @State private var local = AppSettings.default
    @State private var didPrepare = false
    @State private var cloudTestState: CloudTestState = .idle
    @State private var showResetConfirm = false

    private enum CloudTestState: Equatable {
        case idle
        case testing
        case success
        case failure
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                HStack(alignment: .top, spacing: 18) {
                    VStack(spacing: 16) {
                        audioSection
                        graphicsSection
                        controlsSection
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 16) {
                        cloudSection
                        gameCenterSection
                        dataSection
                    }
                    .frame(width: 440)
                }
                .padding(.horizontal, 34)
                .padding(.top, 10)
                .padding(.bottom, 34)
            }
        }
        .background(CarbonBackground())
        .onAppear {
            guard !didPrepare else { return }
            didPrepare = true
            local = app.settings
        }
        .onChange(of: local) { _, value in
            app.updateSettings(value)
        }
        .onChange(of: local.cloudAIURL) { _, _ in
            if cloudTestState != .testing { cloudTestState = .idle }
        }
        .onChange(of: local.cloudAIEnabled) { _, _ in
            if cloudTestState != .testing { cloudTestState = .idle }
        }
        .onChange(of: local.cloudAIProvider) { oldValue, newValue in
            if cloudTestState != .testing { cloudTestState = .idle }
            guard oldValue != newValue else { return }
            if newValue == .openAI {
                if !local.cloudAIURL.contains("/chat/completions") {
                    local.cloudAIURL = newValue.defaultURL
                }
                if local.cloudAIModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    local.cloudAIModel = newValue.defaultModel
                }
            } else if !local.cloudAIURL.contains("/v1/drive") {
                local.cloudAIURL = newValue.defaultURL
            }
        }
        .alert("Reset all local data?", isPresented: $showResetConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset Everything", role: .destructive) {
                app.resetAllData()
                local = app.settings
            }
        } message: {
            Text("This removes your profile, custom tracks, championship season and local records. The built-in game content remains.")
        }
    }

    private var topBar: some View {
        HStack(spacing: 16) {
            BackButton { app.goToMenu() }
                .accessibilityIdentifier("settings.back")
            ScreenHeader(eyebrow: "Pit Wall",
                         title: "Settings",
                         subtitle: "Tune the experience, the audio, and the machine behind the machine.")
            Spacer()
            MiniPill(text: app.networkMonitor.isOnline ? "ONLINE" : "OFFLINE",
                     tint: app.networkMonitor.isOnline ? Theme.success : Theme.amber,
                     icon: app.networkMonitor.isOnline ? "wifi" : "wifi.slash")
            MiniPill(text: "\(Int(app.profile.races)) RACES", tint: Theme.orange, icon: "flag.checkered")
        }
        .padding(.horizontal, 34)
        .padding(.top, 30)
        .padding(.bottom, 10)
    }

    private var audioSection: some View {
        SectionCard(title: "Audio", icon: "speaker.wave.2.fill") {
            VStack(spacing: 14) {
                volumeRow("Master", value: $local.masterVolume, icon: "speaker.wave.3.fill", tint: Theme.offWhite, identifier: "settings.volume.master")
                volumeRow("Music", value: $local.musicVolume, icon: "music.note", tint: Theme.teal, identifier: "settings.volume.music")
                volumeRow("Effects", value: $local.sfxVolume, icon: "bolt.horizontal.fill", tint: Theme.amber, identifier: "settings.volume.effects")
                volumeRow("Motor", value: $local.engineVolume, icon: "engine.combustion.fill", tint: Theme.orange, identifier: "settings.volume.motor")
                HStack {
                    Text("All audio is synthesized at runtime. No external audio assets are used.")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.muted)
                    Spacer()
                    Button {
                        app.toggleMute()
                    } label: {
                        Label(app.isMuted ? "Unmute" : "Mute", systemImage: app.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.offWhite)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.white.opacity(0.06)))
                    .accessibilityIdentifier("settings.mute")
                }
            }
        }
    }

    private var graphicsSection: some View {
        SectionCard(title: "Visuals", icon: "display") {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Quality preset")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.muted)
                    Spacer()
                    Picker("Quality", selection: $local.graphicsQuality) {
                        ForEach(GraphicsQuality.allCases) { quality in
                            Text(quality.displayName).tag(quality)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 260)
                    .tint(Theme.orange)
                    .accessibilityIdentifier("settings.quality")
                }
                HStack {
                    Text("Default camera")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.muted)
                    Spacer()
                    Picker("Camera", selection: $local.defaultCamera) {
                        ForEach(CameraMode.allCases) { mode in
                            Label(mode.displayName, systemImage: mode.icon).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 260)
                    .tint(Theme.orange)
                    .accessibilityIdentifier("settings.camera")
                }
                Toggle(isOn: $local.showFPS) {
                    settingToggleLabel("Show frame statistics", detail: "Display SceneKit's live renderer statistics overlay.")
                }
                .toggleStyle(.switch)
                .tint(Theme.orange)
                .accessibilityIdentifier("settings.showFPS")
                Toggle(isOn: $local.reduceMotion) {
                    settingToggleLabel("Reduce motion", detail: "Disable camera drift, turntable spin and cockpit shake.")
                }
                .toggleStyle(.switch)
                .tint(Theme.orange)
                .accessibilityIdentifier("settings.reduceMotion")
            }
        }
    }

    private var controlsSection: some View {
        SectionCard(title: "Controls", icon: "keyboard.fill") {
            VStack(spacing: 8) {
                controlRow("Throttle", keyboard: "W / ↑ / Space", gamepad: "Right trigger", icon: "arrow.up")
                controlRow("Brake", keyboard: "S / ↓", gamepad: "Left trigger", icon: "arrow.down")
                controlRow("Camera cycle", keyboard: "C", gamepad: "Y", icon: "camera.fill")
                controlRow("Boost", keyboard: "Shift", gamepad: "A", icon: "bolt.fill")
                controlRow("Restart", keyboard: "R", gamepad: "X", icon: "arrow.clockwise")
                controlRow("Pause", keyboard: "Esc / P", gamepad: "Menu", icon: "pause.fill")
                controlRow("Mute", keyboard: "M", gamepad: "—", icon: "speaker.slash.fill")
                Text("Gamepads are discovered automatically. On-screen throttle and brake controls are available during every race.")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 4)
            }
        }
    }

    private var cloudSection: some View {
        SectionCard(title: "Cloud AI", icon: "cloud.fill") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $local.cloudAIEnabled) {
                    settingToggleLabel("Enable external driver AI",
                                       detail: "Local AI is always active underneath. Cloud responses are optional, asynchronous and fail soft.")
                }
                .toggleStyle(.switch)
                .tint(Theme.teal)
                .accessibilityIdentifier("settings.cloudEnabled")

                VStack(alignment: .leading, spacing: 5) {
                    fieldLabel("CONNECTION STYLE")
                    Picker("Connection style", selection: $local.cloudAIProvider) {
                        ForEach(CloudAIProvider.allCases) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .tint(Theme.teal)
                    .accessibilityIdentifier("settings.cloudProvider")
                }

                VStack(alignment: .leading, spacing: 5) {
                    fieldLabel(local.cloudAIProvider == .openAI ? "CHAT COMPLETIONS URL" : "ENDPOINT URL")
                    TextField(local.cloudAIProvider.defaultURL,
                              text: $local.cloudAIURL)
                        .textFieldStyle(.plain)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.offWhite)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.35)))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.stroke, lineWidth: 1))
                        .accessibilityIdentifier("settings.cloudURL")
                }

                if local.cloudAIProvider.usesToken {
                    VStack(alignment: .leading, spacing: 5) {
                        fieldLabel("API TOKEN")
                        SecureField("sk-… (stored in Keychain)",
                                    text: $local.cloudAIToken)
                            .textFieldStyle(.plain)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.offWhite)
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.35)))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.stroke, lineWidth: 1))
                            .accessibilityIdentifier("settings.cloudToken")
                        Text("Tokens go to the macOS Keychain, never to UserDefaults.")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.muted.opacity(0.8))
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        fieldLabel("MODEL")
                        TextField(CloudAIProvider.openAI.defaultModel, text: $local.cloudAIModel)
                            .textFieldStyle(.plain)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.offWhite)
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.35)))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.stroke, lineWidth: 1))
                            .accessibilityIdentifier("settings.cloudModel")
                    }

                    HStack(spacing: 6) {
                        cloudPresetButton(title: "OPENCODE",
                                          identifier: "settings.preset.opencode",
                                          tint: Theme.teal) {
                            applyCloudPreset(CloudAIModelPresets.openCode)
                        }
                        cloudPresetButton(title: "LOCAL MOCK",
                                          identifier: "settings.preset.localMock",
                                          tint: Theme.amber) {
                            applyCloudPreset(CloudAIModelPresets.localMock)
                        }
                        cloudPresetButton(title: "OPENAI",
                                          identifier: "settings.preset.openAI",
                                          tint: Theme.orange) {
                            applyCloudPreset(CloudAIModelPresets.openAI)
                        }
                    }

                    Menu {
                        ForEach(CloudAIModelPresets.openCodeFreeModels) { preset in
                            Button {
                                applyCloudPreset(preset)
                            } label: {
                                Text("\(preset.title) — \(preset.model)")
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 9, weight: .semibold))
                            Text("OPENCODE FREE MODEL PRESETS")
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .tracking(0.8)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .foregroundStyle(Theme.teal)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.teal.opacity(0.08)))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.teal.opacity(0.22), lineWidth: 1))
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .accessibilityIdentifier("settings.cloudModelPresets")

                    Text("OpenCode Zen free chat models are listed for convenience. OpenCode's documentation notes that free-tier chat models require the OpenCode client; direct API keys need paid/Go access. The local mock exercises the same protocol offline.")
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.muted.opacity(0.82))
                        .fixedSize(horizontal: false, vertical: true)
                }

                if local.cloudAIProvider == .direct {
                    Text("Direct mode sends the telemetry object to a local or hosted /v1/drive endpoint. No token or model field is required.")
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.muted.opacity(0.82))
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 9) {
                    MiniPill(text: statusText,
                             tint: statusTint,
                             icon: statusIcon)
                        .accessibilityIdentifier("settings.cloudStatus")
                    Spacer()
                    Button {
                        testCloud()
                    } label: {
                        HStack(spacing: 6) {
                            if cloudTestState == .testing {
                                ProgressView().controlSize(.small).tint(Theme.teal)
                            }
                            Text(cloudTestState == .testing ? "TESTING" : "TEST CONNECTION")
                        }
                    }
                    .buttonStyle(RacingButtonStyle(accent: Theme.teal, compact: true))
                    .frame(width: 156)
                    .disabled(cloudTestState == .testing || !local.cloudAIEnabled)
                    .accessibilityIdentifier("settings.testCloud")
                }

                Text("\(local.cloudAIProvider.protocolSummary) · only HTTPS or loopback HTTP · see README for the mock server protocol.")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.muted.opacity(0.8))
            }
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .bold, design: .rounded))
            .tracking(1.1)
            .foregroundStyle(Theme.muted)
    }

    private func cloudPresetButton(title: String,
                                   identifier: String,
                                   tint: Color,
                                   action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .tracking(0.7)
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 8).fill(tint.opacity(0.09)))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(tint.opacity(0.24), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    private func applyCloudPreset(_ preset: CloudAIModelPreset) {
        local.cloudAIProvider = preset.provider
        local.cloudAIURL = preset.endpoint
        local.cloudAIModel = preset.model
        if cloudTestState != .testing { cloudTestState = .idle }
    }

    private var gameCenterSection: some View {
        SectionCard(title: "Game Center", icon: "gamecontroller.fill") {
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 9) {
                    Circle()
                        .fill(app.gameCenter.isAuthenticated ? Theme.success : Theme.muted)
                        .frame(width: 7, height: 7)
                    Text(app.gameCenter.statusText)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.offWhite)
                    Spacer()
                    if !app.gameCenter.playerAlias.isEmpty {
                        Text(app.gameCenter.playerAlias)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.teal)
                    }
                }
                Text("Leaderboards cover best laps per circuit, championship points and pursuit wins. Achievements and records always work locally when Game Center is unavailable.")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.muted)
                HStack(spacing: 8) {
                    Button {
                        app.gameCenter.authenticate()
                    } label: {
                        Label("SIGN IN / REFRESH", systemImage: "person.crop.circle.badge.checkmark")
                    }
                    .buttonStyle(RacingButtonStyle(compact: true))
                    .accessibilityIdentifier("settings.gameCenterSignIn")
                    Button {
                        app.gameCenter.showDashboard()
                    } label: {
                        Label("DASHBOARD", systemImage: "gamecontroller.fill")
                    }
                    .buttonStyle(RacingButtonStyle(accent: Theme.teal, compact: true))
                    .disabled(!app.gameCenter.isAuthenticated)
                    .accessibilityIdentifier("settings.gameCenterDashboard")
                }
            }
        }
    }

    private var dataSection: some View {
        SectionCard(title: "Data", icon: "externaldrive.fill") {
            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Local profile")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.offWhite)
                        Text("\(app.profile.races) races · \(app.profile.wins) wins · \(app.profile.championships) titles")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Button("UNLOCK ALL") {
                        app.unlockAll()
                    }
                    .buttonStyle(RacingButtonStyle(accent: Theme.teal, compact: true))
                    .frame(width: 130)
                    .accessibilityIdentifier("settings.unlockAll")
                }
                Button {
                    showResetConfirm = true
                } label: {
                    HStack {
                        Image(systemName: "trash.fill")
                        Text("RESET ALL LOCAL DATA")
                        Spacer()
                    }
                }
                .buttonStyle(RacingButtonStyle(accent: Theme.danger, compact: true))
                .accessibilityIdentifier("settings.reset")
                Text("Custom tracks are stored in Application Support/ApexSlotRacing/Tracks.")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.muted.opacity(0.8))
            }
        }
    }

    private var statusText: String {
        switch cloudTestState {
        case .testing: return "CHECKING"
        case .success: return "CONNECTED"
        case .failure: return "NO RESPONSE"
        case .idle: return app.networkMonitor.isOnline ? "READY" : "OFFLINE"
        }
    }

    private var statusTint: Color {
        switch cloudTestState {
        case .success: return Theme.success
        case .failure: return Theme.danger
        case .testing: return Theme.amber
        case .idle: return app.networkMonitor.isOnline ? Theme.teal : Theme.amber
        }
    }

    private var statusIcon: String {
        switch cloudTestState {
        case .success: return "checkmark.circle.fill"
        case .failure: return "exclamationmark.triangle.fill"
        default: return "network"
        }
    }

    private func volumeRow(_ title: String, value: Binding<Double>, icon: String, tint: Color, identifier: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 16)
            Text(title)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.muted)
                .frame(width: 54, alignment: .leading)
            Slider(value: value, in: 0...1)
                .tint(tint)
                .accessibilityIdentifier(identifier)
                .accessibilityLabel("\(title) volume")
            Text("\(Int(value.wrappedValue * 100))%")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.offWhite)
                .frame(width: 30, alignment: .trailing)
        }
    }

    private func settingToggleLabel(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.offWhite)
            Text(detail)
                .font(.system(size: 8, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func controlRow(_ title: String, keyboard: String, gamepad: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Theme.orange)
                .frame(width: 18)
            Text(title)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.offWhite)
            Spacer()
            Text(keyboard)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.muted)
                .frame(width: 116, alignment: .trailing)
            Text(gamepad)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.muted)
                .frame(width: 90, alignment: .trailing)
        }
        .padding(.vertical, 3)
    }

    private func testCloud() {
        cloudTestState = .testing
        let configuration = CloudAIConfiguration(settings: local)
        Task {
            let ok = await app.testCloudAI(configuration: configuration)
            await MainActor.run {
                cloudTestState = ok ? .success : .failure
            }
        }
    }
}
