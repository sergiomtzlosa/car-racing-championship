import SwiftUI

struct RaceSetupView: View {
    let mode: RaceMode
    @EnvironmentObject private var app: AppModel

    @State private var selectedTrackID = TrackCatalog.sunsetID
    @State private var selectedCar: CarModelKind = .gt
    @State private var difficulty: Difficulty = .medium
    @State private var laps = 3
    @State private var environment: TrackEnvironment = .dusk
    @State private var role: PursuitRole = .pursuer
    @State private var didPrepare = false

    private var tracks: [TrackLayout] {
        app.allTracks
    }

    private var selectedTrack: TrackLayout {
        tracks.first(where: { $0.id == selectedTrackID }) ?? tracks.first ?? TrackCatalog.sunsetSpeedway
    }

    private var selectedBuilt: BuiltTrack {
        TrackPathBuilder.build(selectedTrack)
    }

    private var readiness: Bool {
        selectedBuilt.isClosed && selectedBuilt.length > 8
    }

    private var selectedConfig: CarConfig {
        if selectedCar == app.profile.carConfig.model {
            return app.profile.carConfig
        }
        return .standard(for: selectedCar)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(spacing: 22) {
                    HStack(alignment: .top, spacing: 20) {
                        VStack(alignment: .leading, spacing: 17) {
                            trackSection
                            carSection
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        setupPanel
                            .frame(width: 360)
                    }
                    if !readiness {
                        warningBanner
                    }
                }
                .padding(.horizontal, 34)
                .padding(.top, 18)
                .padding(.bottom, 34)
            }
        }
        .background(CarbonBackground())
        .onAppear(perform: prepare)
    }

    private var topBar: some View {
        HStack(spacing: 16) {
            BackButton { app.goToMenu() }
                .accessibilityIdentifier("setup.back")
            ScreenHeader(eyebrow: mode == .pursuit ? "Pursuit Mode" : "Quick Race",
                         title: mode == .pursuit ? "Choose Your Hunt" : "Build The Grid",
                         subtitle: mode == .pursuit
                            ? "Three laps. One fugitive. One pursuer. No excuses."
                            : "Pick a circuit, tune the setup, and take it to the line.")
            Spacer()
            MiniPill(text: readiness ? "CIRCUIT READY" : "CIRCUIT OPEN",
                     tint: readiness ? Theme.success : Theme.danger,
                     icon: readiness ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
        }
        .padding(.horizontal, 34)
        .padding(.top, 30)
        .padding(.bottom, 8)
    }

    private var trackSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("CIRCUIT", icon: "map.fill")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(tracks) { track in
                    TrackCard(track: track,
                              selected: selectedTrackID == track.id,
                              bestLap: app.profile.bestLaps[track.name]) {
                        selectedTrackID = track.id
                        environment = track.environment
                    }
                    .accessibilityIdentifier("setup.track.\(track.name.lowercased().replacingOccurrences(of: " ", with: "-"))")
                }
            }
        }
    }

    private var carSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("MACHINE", icon: "car.fill")
            HStack(spacing: 10) {
                ForEach(CarModelKind.allCases) { model in
                    let unlocked = app.profile.isUnlocked(model)
                    CarModelCard(model: model,
                                 config: model == app.profile.carConfig.model ? app.profile.carConfig : .standard(for: model),
                                 selected: selectedCar == model,
                                 unlocked: unlocked) {
                        if unlocked {
                            selectedCar = model
                        }
                    }
                    .accessibilityIdentifier("setup.car.\(model.rawValue)")
                }
            }
        }
    }

    private var setupPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(mode == .pursuit ? "PURSUIT BRIEF" : "RACE SETUP")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1.6)
                        .foregroundStyle(Theme.orange)
                    Text(selectedTrack.name)
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.offWhite)
                }
                Spacer()
                MiniPill(text: "\(selectedTrack.laneCount) LANES", tint: Theme.teal, icon: "road.lanes")
            }

            TrackOutlineView(track: selectedTrack, lineWidth: 2.4, tint: Theme.orange, showStart: true)
                .frame(height: 118)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.28))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.stroke, lineWidth: 1))
                )

            divider

            if mode == .pursuit {
                settingLabel("YOUR ROLE")
                HStack(spacing: 8) {
                    roleButton(role: .pursuer,
                               title: "Pursuer",
                               detail: "3 siren boosts · capture",
                               icon: "light.beacon.max.fill")
                    roleButton(role: .fugitive,
                               title: "Fugitive",
                               detail: "3 s head start · survive",
                               icon: "figure.run")
                }
                settingLabel("DIFFICULTY")
                Picker("Difficulty", selection: $difficulty) {
                    ForEach(Difficulty.allCases) { value in
                        Text(value.displayName).tag(value)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .tint(Theme.orange)
                .accessibilityIdentifier("setup.difficulty")
            } else {
                settingLabel("DIFFICULTY")
                Picker("Difficulty", selection: $difficulty) {
                    ForEach(Difficulty.allCases) { value in
                        Text(value.displayName).tag(value)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .tint(Theme.orange)
                .accessibilityIdentifier("setup.difficulty")

                settingLabel("LAPS")
                HStack(spacing: 7) {
                    ForEach([3, 5, 10], id: \.self) { value in
                        Button {
                            laps = value
                        } label: {
                            Text("\(value)")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundStyle(laps == value ? .white : Theme.muted)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(
                                    RoundedRectangle(cornerRadius: 9)
                                        .fill(laps == value ? Theme.orange : Color.white.opacity(0.06))
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("setup.laps.\(value)")
                    }
                }
            }

            settingLabel("TIME OF DAY")
            Picker("Environment", selection: $environment) {
                ForEach(TrackEnvironment.allCases) { value in
                    Text(value.displayName).tag(value)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .tint(Theme.orange)
            .accessibilityIdentifier("setup.environment")

            divider

            HStack(spacing: 8) {
                StatPill(label: "Circuit", value: String(format: "%.1f m", selectedBuilt.length), tint: Theme.offWhite)
                StatPill(label: "Best lap", value: app.profile.bestLaps[selectedTrack.name]?.lapTimeString() ?? "--:--", tint: Theme.teal)
                StatPill(label: "Class", value: selectedCar.displayName.components(separatedBy: " ").first ?? "GT", tint: Theme.amber)
            }

            Button {
                startRace()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: mode == .pursuit ? "light.beacon.max.fill" : "flag.checkered")
                    Text(mode == .pursuit ? "START PURSUIT" : "START RACE")
                    Spacer()
                    Text("RETURN")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.65))
                }
            }
            .buttonStyle(RacingButtonStyle(prominent: true, accent: mode == .pursuit ? Theme.teal : Theme.orange))
            .disabled(!readiness)
            .keyboardShortcut(.return, modifiers: [])
            .accessibilityIdentifier("setup.start")

            Text(mode == .pursuit
                 ? "Capture the fugitive within three laps. Sirens boost: Shift / gamepad A."
                 : "Throttle W / ↑  ·  Brake S / ↓  ·  Camera C  ·  Pause Esc")
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.muted.opacity(0.8))
        }
        .padding(19)
        .background(
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .fill(Theme.panel.opacity(0.90))
                .overlay(RoundedRectangle(cornerRadius: 19, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1))
        )
    }

    private func roleButton(role value: PursuitRole, title: String, detail: String, icon: String) -> some View {
        Button {
            role = value
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(role == value ? (value == .pursuer ? Theme.orange : Theme.teal) : Theme.muted)
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.offWhite)
                Text(detail)
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(11)
            .background(
                RoundedRectangle(cornerRadius: 11)
                    .fill(role == value ? Color.white.opacity(0.08) : Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 11)
                            .strokeBorder(role == value ? (value == .pursuer ? Theme.orange : Theme.teal).opacity(0.65) : Theme.stroke,
                                          lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("setup.role.\(value.rawValue)")
    }

    private var warningBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.amber)
            VStack(alignment: .leading, spacing: 2) {
                Text("CIRCUIT IS OPEN")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(Theme.amber)
                Text("This custom circuit cannot be raced until its endpoints are connected in the Track Editor.")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            Button("OPEN EDITOR") { app.openEditor(track: selectedTrack) }
                .buttonStyle(RacingButtonStyle(accent: Theme.amber, compact: true))
                .frame(width: 150)
                .accessibilityIdentifier("setup.openEditor")
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.amber.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.amber.opacity(0.3), lineWidth: 1))
    }

    private var divider: some View {
        Rectangle().fill(Theme.stroke).frame(height: 1)
    }

    private func sectionLabel(_ text: String, icon: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.orange)
            Text(text)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(Theme.muted)
        }
        .frame(minHeight: 14, alignment: .center)
    }

    private func settingLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .bold, design: .rounded))
            .tracking(1.2)
            .foregroundStyle(Theme.muted)
    }

    private func prepare() {
        guard !didPrepare else { return }
        didPrepare = true
        if !app.profile.isUnlocked(selectedCar) {
            selectedCar = .gt
        }
        if let track = tracks.first(where: { $0.id == selectedTrackID }) {
            environment = track.environment
        }
        if mode == .pursuit {
            laps = 3
        }
    }

    private func startRace() {
        guard readiness else { return }
        if mode == .pursuit {
            app.startPursuit(track: selectedTrack,
                             car: selectedConfig,
                             difficulty: difficulty,
                             role: role,
                             environment: environment)
        } else {
            app.startQuickRace(track: selectedTrack,
                               car: selectedConfig,
                               difficulty: difficulty,
                               laps: laps,
                               environment: environment)
        }
    }
}
