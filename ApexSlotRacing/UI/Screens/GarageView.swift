import SwiftUI

struct GarageView: View {
    @EnvironmentObject private var app: AppModel
    @State private var autoRotate = true
    @State private var savedFlash = false
    @State private var draft: CarConfig?
    @State private var saveGeneration = 0

    private var config: CarConfig { draft ?? app.profile.carConfig }

    private var isDirty: Bool { draft != nil && draft != app.profile.carConfig }

    private let paintSwatches = [
        "#E83B2F", "#F0A516", "#2E7BE8", "#2FB37A",
        "#9D5BE8", "#E85D93", "#F1EDE5", "#161B22"
    ]

    var body: some View {
        VStack(spacing: 0) {
            topBar
            HStack(alignment: .top, spacing: 20) {
                showcase
                    .frame(maxWidth: .infinity)
                controlPanel
                    .frame(width: 388)
            }
            .padding(.horizontal, 32)
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
        .background(CarbonBackground())
        .onAppear {
            if draft == nil { draft = app.profile.carConfig }
        }
    }

    private var topBar: some View {
        HStack(spacing: 16) {
            BackButton { app.goToMenu() }
                .accessibilityIdentifier("garage.back")
            ScreenHeader(eyebrow: "Personal Workshop",
                         title: "Garage",
                         subtitle: "Make it yours. Every finish, wheel and decal is procedural.")
            Spacer()
            if savedFlash && !isDirty {
                MiniPill(text: "CONFIG SAVED", tint: Theme.success, icon: "checkmark.circle.fill")
                    .transition(.opacity)
            } else if isDirty {
                MiniPill(text: "UNSAVED CHANGES", tint: Theme.amber, icon: "pencil.circle.fill")
            }
            MiniPill(text: config.model.displayName.uppercased(), tint: Theme.orange, icon: "car.fill")
        }
        .padding(.horizontal, 32)
        .padding(.top, 30)
        .padding(.bottom, 8)
        .animation(.easeOut(duration: 0.2), value: savedFlash)
        .animation(.easeOut(duration: 0.2), value: isDirty)
    }

    private var showcase: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(colors: [Color(hex: "#141C25"), Color(hex: "#090D12")],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1))

            ShowcaseSceneView(config: config,
                              qualitative: app.settings.graphicsQuality,
                              interactive: true,
                              autoRotate: autoRotate && !app.settings.reduceMotion)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            VStack {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        MiniPill(text: "TURNTABLE", tint: Theme.offWhite.opacity(0.75), icon: "rotate.3d")
                        HStack(spacing: 8) {
                            Circle().fill(Color(hex: config.primaryHex)).frame(width: 9, height: 9)
                            Circle().fill(Color(hex: config.secondaryHex)).frame(width: 9, height: 9)
                        }
                    }
                    Spacer()
                    Button {
                        autoRotate.toggle()
                        AudioDirector.shared.play(.uiClick)
                    } label: {
                        Image(systemName: autoRotate ? "pause.fill" : "play.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Theme.offWhite)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.black.opacity(0.40)))
                            .overlay(Circle().strokeBorder(Theme.stroke, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .help(autoRotate ? "Pause turntable" : "Resume turntable")
                    .accessibilityLabel(autoRotate ? "Pause turntable" : "Resume turntable")
                    .accessibilityIdentifier("garage.autoRotate")
                }
                Spacer()
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(config.model.displayName.uppercased())
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .tracking(1.5)
                            .foregroundStyle(Theme.orange)
                        Text(config.model.subtitle)
                            .font(.system(size: 25, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.offWhite)
                    }
                    Spacer()
                    Text("DRAG TO ORBIT")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(Theme.muted.opacity(0.7))
                }
            }
            .padding(23)
        }
        .shadow(color: .black.opacity(0.3), radius: 24, y: 14)
    }

    private var controlPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                carSelection
                paintSection
                wheelSection
                decalSection
                statsSection
                actionSection
            }
            .padding(.bottom, 10)
        }
        .scrollIndicators(.hidden)
    }

    private var carSelection: some View {
        SectionCard(title: "Machine", icon: "car.fill") {
            VStack(spacing: 8) {
                ForEach(CarModelKind.allCases) { model in
                    let unlocked = app.profile.isUnlocked(model)
                    Button {
                        guard unlocked else { return }
                        var updated = CarConfig.standard(for: model)
                        if model == .gt { updated = config.model == .gt ? config : updated }
                        setConfig(updated)
                    } label: {
                        HStack(spacing: 11) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(hex: config.model == model ? config.primaryHex : CarConfig.standard(for: model).primaryHex).opacity(0.18))
                                Image(systemName: "car.side.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(config.model == model ? Theme.orange : Theme.muted)
                            }
                            .frame(width: 38, height: 34)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(model.displayName)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(unlocked ? Theme.offWhite : Theme.muted)
                                Text(model.unlockText ?? model.subtitle)
                                    .font(.system(size: 8, weight: .medium, design: .rounded))
                                    .foregroundStyle(unlocked ? Theme.muted : Theme.amber)
                            }
                            Spacer()
                            if !unlocked {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(Theme.amber)
                            } else if config.model == model {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(Theme.orange)
                            }
                        }
                        .padding(9)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(config.model == model ? Color.white.opacity(0.07) : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(config.model == model ? Theme.orange.opacity(0.4) : Color.clear, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!unlocked)
                    .accessibilityIdentifier("garage.model.\(model.rawValue)")
                }
            }
        }
    }

    private var paintSection: some View {
        SectionCard(title: "Paint Booth", icon: "paintpalette.fill") {
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 7) {
                    ForEach(paintSwatches, id: \.self) { hex in
                        Button {
                            var updated = config
                            updated.primaryHex = hex
                            setConfig(updated)
                            AudioDirector.shared.play(.paint)
                        } label: {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 24, height: 24)
                                .overlay(Circle().strokeBorder(config.primaryHex == hex ? Theme.offWhite : Color.white.opacity(0.15), lineWidth: config.primaryHex == hex ? 2 : 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Paint \(hex)")
                        .accessibilityIdentifier("garage.paint.\(hex.replacingOccurrences(of: "#", with: ""))")
                    }
                }
                HStack(spacing: 10) {
                    ColorPicker("Primary", selection: primaryColor, supportsOpacity: false)
                        .accessibilityIdentifier("garage.primaryColor")
                    ColorPicker("Secondary", selection: secondaryColor, supportsOpacity: false)
                        .accessibilityIdentifier("garage.secondaryColor")
                }
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.muted)
                .colorScheme(.dark)
            }
        }
    }

    private var wheelSection: some View {
        SectionCard(title: "Wheels", icon: "circle.dotted") {
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { style in
                    Button {
                        var updated = config
                        updated.wheelStyle = style
                        setConfig(updated)
                        AudioDirector.shared.play(.uiClick)
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: style == 0 ? "circle.grid.cross" : style == 1 ? "circle.hexagongrid" : "circle.circle")
                                .font(.system(size: 20, weight: .regular))
                            Text(style == 0 ? "MESH" : style == 1 ? "FIVE" : "TURBINE")
                                .font(.system(size: 7, weight: .bold, design: .rounded))
                                .tracking(0.8)
                        }
                        .foregroundStyle(config.wheelStyle == style ? Theme.orange : Theme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 9)
                                .fill(config.wheelStyle == style ? Theme.orange.opacity(0.10) : Color.white.opacity(0.03))
                                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(config.wheelStyle == style ? Theme.orange.opacity(0.4) : Theme.stroke, lineWidth: 1))
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("garage.wheel.\(style)")
                }
            }
        }
    }

    private var decalSection: some View {
        SectionCard(title: "Livery", icon: "sparkles") {
            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { style in
                    let unlocked = app.profile.unlockedDecalStyles.contains(style)
                    Button {
                        guard unlocked else { return }
                        var updated = config
                        updated.decalStyle = style
                        setConfig(updated)
                        AudioDirector.shared.play(.uiClick)
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: unlocked ? "square.stack.3d.up.fill" : "lock.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text(style == 0 ? "CLEAN" : style == 1 ? "STRIPE" : style == 2 ? "ROUNDEL" : "SPONSOR")
                                .font(.system(size: 7, weight: .bold, design: .rounded))
                                .tracking(0.5)
                        }
                        .foregroundStyle(config.decalStyle == style ? Theme.teal : (unlocked ? Theme.muted : Theme.amber.opacity(0.6)))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 9)
                                .fill(config.decalStyle == style ? Theme.teal.opacity(0.09) : Color.white.opacity(0.03))
                                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(config.decalStyle == style ? Theme.teal.opacity(0.4) : Theme.stroke, lineWidth: 1))
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!unlocked)
                    .accessibilityIdentifier("garage.decal.\(style)")
                }
            }
            if !app.profile.unlockedDecalStyles.contains(3) {
                Text("Unlock more livery sets with podium finishes and wins.")
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.muted)
            }
        }
    }

    private var statsSection: some View {
        SectionCard(title: "Performance", icon: "speedometer") {
            VStack(spacing: 10) {
                StatBar(label: "Top speed", value: Double(config.model.stats.topSpeed / 11.5), tint: Theme.orange)
                StatBar(label: "Acceleration", value: Double(config.model.stats.acceleration / 11.5), tint: Theme.amber)
                StatBar(label: "Grip", value: Double(config.model.stats.grip / 25.0), tint: Theme.teal)
                StatBar(label: "Magnet stability", value: Double(config.model.stats.stability), tint: Theme.success)
            }
        }
    }

    private var actionSection: some View {
        VStack(spacing: 8) {
            Button {
                randomize()
            } label: {
                HStack {
                    Image(systemName: "dice.fill")
                    Text("RANDOMIZE LIVERY")
                    Spacer()
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
            }
            .buttonStyle(RacingButtonStyle(compact: true))
            .accessibilityIdentifier("garage.randomize")
            Button {
                let config = draft ?? app.profile.carConfig
                app.updateCar(config)
                AudioDirector.shared.play(.unlock)
                saveGeneration += 1
                let generation = saveGeneration
                withAnimation { savedFlash = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                    guard generation == saveGeneration else { return }
                    withAnimation { savedFlash = false }
                }
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("SAVE CONFIGURATION")
                    Spacer()
                }
            }
            .buttonStyle(RacingButtonStyle(prominent: true, accent: Theme.orange))
            .accessibilityIdentifier("garage.save")
        }
    }

    private var primaryColor: Binding<Color> {
        Binding(
            get: { Color(hex: config.primaryHex) },
            set: { newValue in
                var updated = config
                updated.primaryHex = newValue.nsColor().hexString
                setConfig(updated)
            }
        )
    }

    private var secondaryColor: Binding<Color> {
        Binding(
            get: { Color(hex: config.secondaryHex) },
            set: { newValue in
                var updated = config
                updated.secondaryHex = newValue.nsColor().hexString
                setConfig(updated)
            }
        )
    }

    private func setConfig(_ config: CarConfig) {
        draft = config
        if savedFlash { savedFlash = false }
    }

    private func randomize() {
        var updated = config
        updated.primaryHex = paintSwatches.randomElement() ?? "#E83B2F"
        updated.secondaryHex = ["#F5F2E9", "#121820", "#FFB020", "#52D6D0"].randomElement() ?? "#F5F2E9"
        updated.wheelStyle = Int.random(in: 0...2)
        updated.decalStyle = app.profile.unlockedDecalStyles.randomElement() ?? 0
        setConfig(updated)
        AudioDirector.shared.play(.unlock)
    }
}
