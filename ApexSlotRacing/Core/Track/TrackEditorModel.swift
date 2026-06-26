import Foundation
import SwiftUI
import simd

struct TrackValidationReport {
    var isReady: Bool
    var headline: String
    var detail: String
    var issues: [String]
    var suggestions: [String]
}

final class TrackEditorModel: ObservableObject {
    @Published var layout: TrackLayout
    @Published var selectedKind: TrackPieceKind = .straightLong
    @Published var selectedPieceID: UUID?
    @Published private(set) var built: BuiltTrack
    @Published var message: String?
    @Published var messageIsError = false
    @Published private(set) var geometryRevision = 0

    private var undoStack: [TrackLayout] = []
    private var redoStack: [TrackLayout] = []

    init(layout: TrackLayout) {
        self.layout = layout
        self.built = TrackPathBuilder.build(layout)
        self.selectedPieceID = layout.pieces.last?.id
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    var selectedPiece: TrackPiece? {
        guard let selectedPieceID else { return nil }
        return layout.pieces.first(where: { $0.id == selectedPieceID })
    }

    var selectedIndex: Int? {
        guard let selectedPieceID else { return nil }
        return layout.pieces.firstIndex(where: { $0.id == selectedPieceID })
    }

    var isClosed: Bool { built.isClosed && built.length >= 8 }

    func validationReport() -> TrackValidationReport {
        if layout.pieces.isEmpty {
            return TrackValidationReport(
                isReady: false,
                headline: "Empty Circuit",
                detail: "Add a start/finish piece and some track sections to begin.",
                issues: ["There are no pieces in this circuit."],
                suggestions: ["Use Blank Circuit or Starter to begin."]
            )
        }

        if built.isClosed, built.length < 8 {
            return TrackValidationReport(
                isReady: false,
                headline: "Circuit Too Short",
                detail: String(format: "The loop is closed but only %.2f units long. Add more track before racing.", built.length),
                issues: [String(format: "Circuit length is %.2f units; at least 8 units are required.", built.length)],
                suggestions: ["Undo the last change or replace a section with a longer piece."]
            )
        }

        if built.isClosed {
            return TrackValidationReport(
                isReady: true,
                headline: "Circuit Ready",
                detail: "The loop is closed, the lane path is continuous, and the circuit is raceable.",
                issues: [],
                suggestions: ["Test Drive the circuit, then save it to your custom library."]
            )
        }

        let headingError = acos(max(-1, min(1, built.closureHeadingDot))) * 180 / .pi
        var issues = [String(format: "The circuit is open by %.2f units.", built.closureError)]
        if headingError > 3 {
            issues.append(String(format: "The exit heading is %.1f° away from the start direction.", headingError))
        }
        var suggestions: [String] = []
        if built.length >= 1 {
            suggestions.append("Use Auto Close to add a continuous connector back to the start.")
        }
        if headingError > 3 {
            suggestions.append("If Auto Close cannot connect it, add a corner before the final straight.")
        }
        if suggestions.isEmpty {
            suggestions.append("Add track pieces or use Auto Close to finish the loop.")
        }
        return TrackValidationReport(
            isReady: false,
            headline: "Circuit Open",
            detail: String(format: "The circuit is open by %.2f units. Use Auto Close or add pieces to finish the loop.", built.closureError),
            issues: issues,
            suggestions: suggestions
        )
    }

    func validate() {
        let report = validationReport()
        show(report.detail, error: !report.isReady)
    }

    func add(_ kind: TrackPieceKind) {
        if kind == .startFinish, layout.pieces.contains(where: { $0.kind == .startFinish }) {
            show("A circuit can only contain one start/finish piece.", error: true)
            return
        }
        pushUndo()
        let piece = TrackPiece(kind: kind)
        layout.pieces.append(piece)
        layout.updatedAt = Date()
        selectedPieceID = piece.id
        selectedKind = kind
        rebuild()
        show("Added \(kind.displayName).", error: false)
    }

    func removeSelected() {
        guard let index = selectedIndex else {
            show("Select a piece to remove.", error: true)
            return
        }
        guard layout.pieces.count > 1 else {
            show("The circuit needs at least one piece.", error: true)
            return
        }
        pushUndo()
        layout.pieces.remove(at: index)
        selectedPieceID = layout.pieces[min(index, layout.pieces.count - 1)].id
        layout.updatedAt = Date()
        rebuild()
        show("Piece removed.", error: false)
    }

    func replaceSelected(with kind: TrackPieceKind) {
        guard let index = selectedIndex else { return }
        if kind == .startFinish, layout.pieces.enumerated().contains(where: { $0.offset != index && $0.element.kind == .startFinish }) {
            show("A circuit can only contain one start/finish piece.", error: true)
            return
        }
        pushUndo()
        let existing = layout.pieces[index]
        layout.pieces[index] = TrackPiece(
            id: existing.id,
            kind: kind,
            length: kind.defaultLength,
            radius: kind.defaultRadius,
            mirrored: existing.mirrored,
            position: existing.position,
            rotationY: existing.rotationY
        )
        selectedKind = kind
        layout.updatedAt = Date()
        rebuild()
        show("Piece replaced with \(kind.displayName).", error: false)
    }

    func select(_ piece: TrackPiece) {
        selectedPieceID = piece.id
        selectedKind = piece.kind
    }

    func toggleMirror() {
        guard let index = selectedIndex else { return }
        pushUndo()
        layout.pieces[index].mirrored.toggle()
        layout.updatedAt = Date()
        rebuild()
    }

    func setLength(_ length: Float?) {
        guard let index = selectedIndex else { return }
        pushUndo()
        layout.pieces[index].length = length
        layout.updatedAt = Date()
        rebuild()
    }

    func setRadius(_ radius: Float?) {
        guard let index = selectedIndex else { return }
        pushUndo()
        layout.pieces[index].radius = radius
        layout.updatedAt = Date()
        rebuild()
    }

    func setName(_ name: String) {
        layout.name = name
        layout.updatedAt = Date()
    }

    func setEnvironment(_ environment: TrackEnvironment) {
        guard layout.environment != environment else { return }
        layout.environment = environment
        layout.updatedAt = Date()
        rebuild()
    }

    func autoClose() {
        if built.isClosed {
            if built.length < 8 {
                show("This circuit is closed but too short to race. Undo and add more track.", error: true)
            } else {
                show("This circuit is already closed and race ready.", error: false)
            }
            return
        }
        guard !layout.pieces.isEmpty, let end = built.centerFrames.last else {
            show("Add pieces before closing the loop.", error: true)
            return
        }

        let start = built.startFrame
        let isFlat = abs(end.up.y - 1) < 0.02
            && abs(end.forward.y) < 0.02
            && abs(start.up.y - 1) < 0.02
            && abs(end.position.y - start.position.y) < 0.06
        guard isFlat else {
            show("Auto Close only works on flat sections. Finish the bridge or loop with a flat piece first.", error: true)
            return
        }

        let dx = start.position.x - end.position.x
        let dz = start.position.z - end.position.z
        let gap = sqrt(dx * dx + dz * dz)
        guard gap > 0.12 else {
            show("The gap is too small to close cleanly. Adjust the final piece or undo the last change.", error: true)
            return
        }
        guard gap < 60 else {
            show("The gap is too large for Auto Close. Add corner pieces first, then try again.", error: true)
            return
        }
        guard let plan = TrackClosurePlanner.plan(from: end, to: start) else {
            show("Couldn't find a clean connector for this layout. Add a corner or undo the trailing pieces.", error: true)
            return
        }

        let previous = layout
        let previousSelection = selectedPieceID
        pushUndo()
        layout.pieces.append(contentsOf: plan.pieces)
        layout.updatedAt = Date()
        selectedPieceID = plan.pieces.last?.id
        rebuild()

        if built.isClosed, built.length >= 8 {
            show(plan.summary, error: false)
        } else if built.isClosed {
            show("Auto Close created a loop that is too short to race. Undo and lengthen the circuit.", error: true)
        } else {
            layout = previous
            if !undoStack.isEmpty { undoStack.removeLast() }
            selectedPieceID = previousSelection
            rebuild()
            show(String(format: "Auto Close could not connect the loop. It is still open by %.2f units.", built.closureError), error: true)
        }
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(layout)
        layout = previous
        selectedPieceID = layout.pieces.last?.id
        rebuild()
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(layout)
        layout = next
        selectedPieceID = layout.pieces.last?.id
        rebuild()
    }

    func loadStarter() {
        pushUndo()
        layout = TrackCatalog.starterLayout()
        selectedPieceID = layout.pieces.last?.id
        selectedKind = .straightLong
        redoStack.removeAll()
        rebuild()
        show("Starter oval loaded. It is a closed, race-ready circuit.", error: false)
    }

    func loadBlank() {
        pushUndo()
        layout = TrackCatalog.blankLayout()
        selectedPieceID = layout.pieces.first?.id
        selectedKind = .startFinish
        redoStack.removeAll()
        rebuild()
        show("Blank circuit created. Add pieces to build a loop.", error: false)
    }

    func load(_ track: TrackLayout) {
        pushUndo()
        layout = track
        selectedPieceID = layout.pieces.last?.id
        redoStack.removeAll()
        rebuild()
        show("Loaded \(track.name).", error: false)
    }

    private func pushUndo() {
        undoStack.append(layout)
        if undoStack.count > 60 { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    private func rebuild() {
        built = TrackPathBuilder.build(layout)
        geometryRevision &+= 1
    }

    private func show(_ text: String, error: Bool) {
        message = text
        messageIsError = error
    }
}
