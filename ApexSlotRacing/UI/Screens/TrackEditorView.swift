import SwiftUI

private enum EditorSheet: String, Identifiable {
    case validation
    case paste

    var id: String { rawValue }
}

struct TrackEditorView: View {
    @EnvironmentObject private var app: AppModel
    @StateObject private var model = TrackEditorModel(layout: TrackCatalog.starterLayout())
    @State private var resetSignal = 0
    @State private var activeSheet: EditorSheet?
    @State private var pasteText = ""

    private let straights: [TrackPieceKind] = [.startFinish, .straightLong, .straightShort, .chicane]
    private let curves: [TrackPieceKind] = [.curveSharp90, .curveWide90, .curveWide180, .curve45]
    private let specials: [TrackPieceKind] = [.crossover, .bridge, .loop360]

    var body: some View {
        VStack(spacing: 0) {
            topBar
            HStack(alignment: .top, spacing: 12) {
                palette
                    .frame(width: 218)
                viewport
                inspector
                    .frame(width: 326)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .background(CarbonBackground())
        .onAppear {
            if let track = app.takePendingEditorTrack() {
                model.load(track)
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .validation:
                validationSheet
            case .paste:
                pasteSheet
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 13) {
            BackButton { app.goToMenu() }
                .accessibilityIdentifier("editor.back")
            VStack(alignment: .leading, spacing: 2) {
                Text("TRACK EDITOR")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(Theme.orange)
                TextField("Circuit name", text: Binding(
                    get: { model.layout.name },
                    set: { model.setName($0) }
                ))
                .textFieldStyle(.plain)
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.offWhite)
                .frame(width: 340)
                .accessibilityIdentifier("editor.name")
            }
            Spacer()
            Button {
                resetSignal += 1
            } label: {
                Image(systemName: "scope")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.white.opacity(0.055)))
            }
            .buttonStyle(.plain)
            .help("Fit camera to circuit")
            .accessibilityLabel("Fit camera to circuit")
            .accessibilityIdentifier("editor.fit")

            Button {
                model.validate()
                activeSheet = .validation
            } label: {
                Label("VALIDATE", systemImage: "checkmark.seal.fill")
            }
            .buttonStyle(RacingButtonStyle(accent: Theme.teal, compact: true))
            .frame(width: 118)
            .help("Open the circuit validation report")
            .accessibilityIdentifier("editor.validate")

            Button {
                testDrive()
            } label: {
                Label("TEST DRIVE", systemImage: "play.fill")
            }
            .buttonStyle(RacingButtonStyle(accent: Theme.amber, compact: true))
            .frame(width: 138)
            .help("Race this layout without saving it")
            .accessibilityIdentifier("editor.testDrive")

            Button {
                save()
            } label: {
                Label("SAVE", systemImage: "square.and.arrow.down.fill")
            }
            .buttonStyle(RacingButtonStyle(prominent: true, accent: Theme.orange, compact: true))
            .frame(width: 104)
            .help("Save to the custom circuit library")
            .accessibilityIdentifier("editor.save")
        }
        .padding(.horizontal, 22)
        .padding(.top, 24)
        .padding(.bottom, 8)
    }

    private var palette: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 13) {
                paletteGroup("STRAIGHT & CONTROL", pieces: straights)
                paletteGroup("CORNERS", pieces: curves)
                paletteGroup("SPECIAL", pieces: specials)

                Rectangle().fill(Theme.stroke).frame(height: 1)

                Button {
                    runAutoClose()
                } label: {
                    Label("AUTO CLOSE", systemImage: "arrow.triangle.merge")
                }
                .buttonStyle(RacingButtonStyle(accent: Theme.orange, compact: true))
                .help("Add tangent-continuous link pieces to close an open circuit")
                .accessibilityIdentifier("editor.autoClose")

                HStack(spacing: 6) {
                    Button {
                        model.undo()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(RacingButtonStyle(compact: true))
                    .disabled(!model.canUndo)
                    .accessibilityIdentifier("editor.undo")
                    Button {
                        model.redo()
                    } label: {
                        Image(systemName: "arrow.uturn.forward")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(RacingButtonStyle(compact: true))
                    .disabled(!model.canRedo)
                    .accessibilityIdentifier("editor.redo")
                }

                HStack(spacing: 6) {
                    Button {
                        model.loadStarter()
                    } label: {
                        Label("STARTER", systemImage: "flag.checkered")
                            .font(.system(size: 8, weight: .bold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(RacingButtonStyle(compact: true))
                    .accessibilityIdentifier("editor.starter")
                    Button {
                        model.loadBlank()
                    } label: {
                        Label("BLANK", systemImage: "square.dashed")
                            .font(.system(size: 8, weight: .bold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(RacingButtonStyle(compact: true))
                    .accessibilityIdentifier("editor.blank")
                }

                Menu {
                    Button("Starter Oval") { model.loadStarter() }
                    Button("Blank Circuit") { model.loadBlank() }
                    if !app.customTracks.isEmpty {
                        Divider()
                        ForEach(app.customTracks) { track in
                            Button(track.name) { model.load(track) }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "folder.fill")
                        Text("LOAD CIRCUIT")
                        Spacer()
                        Image(systemName: "chevron.down")
                    }
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.offWhite)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.06)))
                }
                .menuStyle(.borderlessButton)
                .accessibilityIdentifier("editor.loadMenu")
            }
            .padding(12)
        }
        .scrollIndicators(.hidden)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.panel.opacity(0.82))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.stroke, lineWidth: 1))
        )
    }

    private func paletteGroup(_ title: String, pieces: [TrackPieceKind]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 7, weight: .bold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(Theme.muted)
            ForEach(pieces) { kind in
                Button {
                    model.add(kind)
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: kind.symbol)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.orange)
                            .frame(width: 17)
                        Text(kind.displayName)
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.offWhite)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "plus")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(Theme.muted.opacity(0.6))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(model.selectedKind == kind ? Theme.orange.opacity(0.10) : Color.white.opacity(0.035))
                            .overlay(
                                RoundedRectangle(cornerRadius: 7)
                                    .strokeBorder(model.selectedKind == kind ? Theme.orange.opacity(0.28) : Color.clear, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("editor.palette.\(kind.rawValue)")
            }
        }
    }

    private var viewport: some View {
        ZStack {
            TrackEditorSceneView(layout: model.layout,
                                 revision: model.geometryRevision,
                                 quality: app.settings.graphicsQuality,
                                 resetSignal: resetSignal)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.stroke, lineWidth: 1))

            VStack {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        MiniPill(text: model.isClosed ? "CLOSED CIRCUIT" : "OPEN CIRCUIT",
                                 tint: model.isClosed ? Theme.success : Theme.danger,
                                 icon: model.isClosed ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        Text(String(format: "%.2f m · %d pieces", model.built.length, model.layout.pieces.count))
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.muted)
                            .accessibilityIdentifier("editor.summary")
                    }
                    Spacer()
                    Text("DRAG TO ORBIT  ·  SCROLL TO ZOOM")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .tracking(0.9)
                        .foregroundStyle(Theme.muted.opacity(0.7))
                        .lineLimit(1)
                        .padding(.trailing, 44)
                }
                Spacer()
                if let message = model.message {
                    HStack(spacing: 10) {
                        Image(systemName: model.messageIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(model.messageIsError ? Theme.amber : Theme.success)
                        Text(message)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.offWhite)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("editor.message")
                        Spacer(minLength: 6)
                        Button {
                            model.message = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(Theme.muted)
                                .frame(width: 22, height: 22)
                        }
                        .buttonStyle(.plain)
                        .help("Dismiss message")
                        .accessibilityIdentifier("editor.dismissMessage")
                    }
                    .padding(.leading, 14)
                    .padding(.trailing, 8)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Color.black.opacity(0.82)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder((model.messageIsError ? Theme.amber : Theme.success).opacity(0.35), lineWidth: 1)
                    )
                    .frame(maxWidth: 620)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(14)
            .animation(.easeOut(duration: 0.18), value: model.message)
        }
        .overlay(alignment: .topTrailing) {
            VStack(spacing: 6) {
                Button {
                    resetSignal += 1
                } label: {
                    Image(systemName: "scope")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.offWhite)
                        .frame(width: 29, height: 29)
                        .background(Circle().fill(Color.black.opacity(0.45)))
                }
                .buttonStyle(.plain)
                .help("Reset camera")
                .accessibilityIdentifier("editor.resetCamera")
                Button {
                    runAutoClose()
                } label: {
                    Image(systemName: "arrow.triangle.merge")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.offWhite)
                        .frame(width: 29, height: 29)
                        .background(Circle().fill(Color.black.opacity(0.45)))
                }
                .buttonStyle(.plain)
                .help("Auto close circuit")
                .accessibilityIdentifier("editor.autoCloseHUD")
            }
            .padding(12)
        }
    }

    private var inspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                validationCard
                environmentCard
                selectedInspector
                pieceList
                fileActions
            }
            .padding(12)
        }
        .scrollIndicators(.hidden)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.panel.opacity(0.82))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.stroke, lineWidth: 1))
        )
    }

    private var validationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: model.isClosed ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(model.isClosed ? Theme.success : Theme.amber)
                Text(model.isClosed ? "RACE READY" : "VALIDATION")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(model.isClosed ? Theme.success : Theme.amber)
                Spacer()
                Text(model.built.isClosed ? "LOOP" : String(format: "GAP %.2f", model.built.closureError))
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.muted)
            }
            Text(model.built.validationMessage)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.muted)
                .accessibilityIdentifier("editor.validationMessage")
            HStack(spacing: 6) {
                MiniPill(text: "\(model.layout.pieces.count) PIECES", tint: Theme.offWhite)
                MiniPill(text: "2 LANES", tint: Theme.teal)
                MiniPill(text: String(format: "%.1f M", model.built.length), tint: Theme.orange)
            }
        }
        .padding(11)
        .background(RoundedRectangle(cornerRadius: 11).fill(Color.black.opacity(0.28)))
        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder((model.isClosed ? Theme.success : Theme.amber).opacity(0.25), lineWidth: 1))
    }

    private var environmentCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ENVIRONMENT")
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(Theme.muted)
            Picker("Environment", selection: Binding(
                get: { model.layout.environment },
                set: { model.setEnvironment($0) }
            )) {
                ForEach(TrackEnvironment.allCases) { environment in
                    Text(environment.displayName).tag(environment)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .tint(Theme.orange)
            .accessibilityIdentifier("editor.environment")
        }
        .padding(11)
        .background(RoundedRectangle(cornerRadius: 11).fill(Color.black.opacity(0.28)))
        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Theme.stroke, lineWidth: 1))
    }

    @ViewBuilder
    private var selectedInspector: some View {
        if let piece = model.selectedPiece {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text("SELECTED PIECE")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(Theme.muted)
                    Spacer()
                    Text("\((model.selectedIndex ?? 0) + 1)")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.muted)
                }
                HStack(spacing: 7) {
                    Image(systemName: piece.kind.symbol)
                        .foregroundStyle(Theme.orange)
                    Text(piece.kind.displayName)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.offWhite)
                }

                Picker("Replace", selection: Binding(
                    get: { piece.kind },
                    set: { model.replaceSelected(with: $0) }
                )) {
                    ForEach(replaceableKinds(for: piece)) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .tint(Theme.offWhite)
                .accessibilityIdentifier("editor.replacePiece")

                if piece.kind.defaultLength != nil || piece.kind.isStraightLike {
                    Stepper(value: Binding(
                        get: { Double(piece.effectiveLength) },
                        set: { model.setLength(Float($0)) }
                    ), in: 0.5...24, step: 0.5) {
                        HStack {
                            Text("Length")
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.muted)
                            Spacer()
                            Text(String(format: "%.1f", piece.effectiveLength))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(Theme.offWhite)
                        }
                    }
                    .accessibilityIdentifier("editor.length")
                }
                if piece.kind.defaultRadius != nil {
                    Stepper(value: Binding(
                        get: { Double(piece.effectiveRadius) },
                        set: { model.setRadius(Float($0)) }
                    ), in: 0.8...8, step: 0.1) {
                        HStack {
                            Text("Radius")
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.muted)
                            Spacer()
                            Text(String(format: "%.1f", piece.effectiveRadius))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(Theme.offWhite)
                        }
                    }
                    .accessibilityIdentifier("editor.radius")
                }
                Toggle(isOn: Binding(get: { piece.mirrored }, set: { _ in model.toggleMirror() })) {
                    Text("Mirror piece")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.muted)
                }
                .toggleStyle(.switch)
                .tint(Theme.orange)
                .accessibilityIdentifier("editor.mirrorToggle")

                HStack(spacing: 6) {
                    Button {
                        model.removeSelected()
                    } label: {
                        Label("DELETE", systemImage: "trash.fill")
                            .font(.system(size: 8, weight: .bold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(RacingButtonStyle(accent: Theme.danger, compact: true))
                    .accessibilityIdentifier("editor.delete")
                    Button {
                        model.toggleMirror()
                    } label: {
                        Label("MIRROR", systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right.fill")
                            .font(.system(size: 8, weight: .bold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(RacingButtonStyle(compact: true))
                    .accessibilityIdentifier("editor.mirror")
                }
            }
            .padding(11)
            .background(RoundedRectangle(cornerRadius: 11).fill(Color.white.opacity(0.025)))
            .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Theme.stroke, lineWidth: 1))
        }
    }

    private var pieceList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PIECE CHAIN")
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(Theme.muted)
            ScrollView {
                LazyVStack(spacing: 3) {
                    ForEach(Array(model.layout.pieces.enumerated()), id: \.element.id) { index, piece in
                        Button {
                            model.select(piece)
                        } label: {
                            HStack(spacing: 7) {
                                Text("\(index + 1)")
                                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Theme.muted.opacity(0.7))
                                    .frame(width: 14, alignment: .trailing)
                                Image(systemName: piece.kind.symbol)
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundStyle(model.selectedPieceID == piece.id ? Theme.orange : Theme.muted)
                                    .frame(width: 14)
                                Text(piece.kind.displayName)
                                    .font(.system(size: 9, weight: .medium, design: .rounded))
                                    .foregroundStyle(model.selectedPieceID == piece.id ? Theme.offWhite : Theme.muted)
                                    .lineLimit(1)
                                Spacer()
                                if piece.mirrored {
                                    Image(systemName: "arrow.left.and.right")
                                        .font(.system(size: 7, weight: .bold))
                                        .foregroundStyle(Theme.muted.opacity(0.6))
                                }
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(model.selectedPieceID == piece.id ? Theme.orange.opacity(0.09) : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("editor.piece.\(index)")
                    }
                }
            }
            .frame(height: 176)
        }
    }

    private var fileActions: some View {
        VStack(spacing: 7) {
            HStack(spacing: 6) {
                Button {
                    exportTrack()
                } label: {
                    Label("EXPORT", systemImage: "square.and.arrow.up")
                        .font(.system(size: 8, weight: .bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(RacingButtonStyle(compact: true))
                .accessibilityIdentifier("editor.export")
                Button {
                    importTrack()
                } label: {
                    Label("IMPORT", systemImage: "square.and.arrow.down")
                        .font(.system(size: 8, weight: .bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(RacingButtonStyle(compact: true))
                .accessibilityIdentifier("editor.import")
            }
            Button {
                activeSheet = .paste
            } label: {
                Label("PASTE JSON", systemImage: "doc.on.clipboard")
                    .font(.system(size: 8, weight: .bold))
            }
            .buttonStyle(RacingButtonStyle(compact: true))
            .accessibilityIdentifier("editor.pasteJSON")
            Button {
                save()
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.down.fill")
                    Text("SAVE CUSTOM TRACK")
                    Spacer()
                }
            }
            .buttonStyle(RacingButtonStyle(prominent: true, accent: Theme.orange, compact: true))
            .accessibilityIdentifier("editor.saveCustom")
            Text("Saved to Application Support/ApexSlotRacing/Tracks")
                .font(.system(size: 7, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.muted.opacity(0.65))
        }
    }

    private var validationSheet: some View {
        TrackValidationSheet(model: model,
                             onClose: { activeSheet = nil },
                             onTestDrive: {
                                 activeSheet = nil
                                 testDrive()
                             })
    }

    private var pasteSheet: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("IMPORT TRACK JSON")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1.3)
                        .foregroundStyle(Theme.orange)
                    Text("Paste a circuit export")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.offWhite)
                }
                Spacer()
                Button("CLOSE") { activeSheet = nil }
                    .buttonStyle(RacingButtonStyle(compact: true))
                    .frame(width: 90)
                    .accessibilityIdentifier("editor.paste.close")
            }
            TextEditor(text: $pasteText)
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundStyle(Theme.offWhite)
                .scrollContentBackground(.hidden)
                .padding(9)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.4)))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.stroke, lineWidth: 1))
                .frame(minHeight: 260)
                .accessibilityIdentifier("editor.paste.text")
            HStack {
                Button("CLEAR") { pasteText = "" }
                    .buttonStyle(RacingButtonStyle(compact: true))
                    .frame(width: 90)
                    .accessibilityIdentifier("editor.paste.clear")
                Spacer()
                Button("VALIDATE & LOAD") {
                    do {
                        let track = try TrackFileService.validate(text: pasteText)
                        model.load(track)
                        activeSheet = nil
                    } catch {
                        model.message = error.localizedDescription
                        model.messageIsError = true
                        activeSheet = nil
                    }
                }
                .buttonStyle(RacingButtonStyle(prominent: true, accent: Theme.teal, compact: true))
                .frame(width: 180)
                .accessibilityIdentifier("editor.paste.load")
            }
        }
        .padding(22)
        .frame(width: 620, height: 430)
        .background(Theme.panel)
    }

    private func save() {
        let name = model.layout.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            model.message = "Give the circuit a name before saving."
            model.messageIsError = true
            return
        }
        var track = model.layout
        track.name = name
        model.setName(name)
        app.saveTrack(track)
        model.message = "Saved \(name) to the custom circuit library."
        model.messageIsError = false
        AudioDirector.shared.play(.unlock)
    }

    private func replaceableKinds(for piece: TrackPiece) -> [TrackPieceKind] {
        TrackPieceKind.allCases.filter { kind in
            if kind == .closureArc && piece.kind != .closureArc { return false }
            if kind == .startFinish &&
                piece.kind != .startFinish &&
                model.layout.pieces.contains(where: { $0.kind == .startFinish }) {
                return false
            }
            return true
        }
    }

    private func testDrive() {
        guard model.isClosed else {
            model.validate()
            activeSheet = .validation
            return
        }
        app.startTestDrive(track: model.layout)
    }

    private func runAutoClose() {
        let wasClosed = model.built.isClosed
        model.autoClose()
        if wasClosed || model.messageIsError {
            activeSheet = .validation
        }
    }

    private func exportTrack() {
        switch TrackFileService.export(model.layout) {
        case .success(let url):
            model.message = "Exported to \(url.lastPathComponent)."
            model.messageIsError = false
        case .failure(let error):
            if (error as NSError).code == NSUserCancelledError { return }
            model.message = error.localizedDescription
            model.messageIsError = true
        }
    }

    private func importTrack() {
        switch TrackFileService.importTrack() {
        case .success(let track):
            model.load(track)
        case .failure(let error):
            if (error as NSError).code == NSUserCancelledError { return }
            model.message = error.localizedDescription
            model.messageIsError = true
        }
    }
}
