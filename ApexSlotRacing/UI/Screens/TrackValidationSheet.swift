import SwiftUI

struct TrackValidationSheet: View {
    @ObservedObject var model: TrackEditorModel
    var onClose: () -> Void
    var onTestDrive: () -> Void

    var body: some View {
        let report = model.validationReport()
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill((report.isReady ? Theme.success : Theme.amber).opacity(0.14))
                        .frame(width: 38, height: 38)
                    Image(systemName: report.isReady ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(report.isReady ? Theme.success : Theme.amber)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("CIRCUIT VALIDATION")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1.3)
                        .foregroundStyle(Theme.orange)
                    Text(report.headline)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.offWhite)
                        .accessibilityIdentifier("validation.headline")
                    Text(report.detail)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("validation.detail")
                }
                Spacer(minLength: 8)
                Button("CLOSE", action: onClose)
                    .buttonStyle(RacingButtonStyle(compact: true))
                    .frame(width: 90)
                    .accessibilityIdentifier("validation.close")
            }

            HStack(spacing: 7) {
                MiniPill(text: "\(model.layout.pieces.count) PIECES", tint: Theme.offWhite)
                MiniPill(text: "2 LANES", tint: Theme.teal)
                MiniPill(text: String(format: "%.1f M", model.built.length), tint: Theme.orange)
                MiniPill(text: model.built.isClosed ? "LOOP" : String(format: "GAP %.2f", model.built.closureError),
                         tint: model.built.isClosed ? Theme.success : Theme.danger)
            }

            if !report.issues.isEmpty {
                issueCard(report.issues)
            }

            if !report.suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text(report.isReady ? "NEXT STEP" : "HOW TO FIX IT")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(Theme.muted)
                    ForEach(report.suggestions, id: \.self) { suggestion in
                        Text(suggestion)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.muted)
                    }
                }
            }

            if let message = model.message {
                HStack(spacing: 8) {
                    Image(systemName: model.messageIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(model.messageIsError ? Theme.amber : Theme.success)
                    Text(message)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.offWhite)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 9).fill(Color.black.opacity(0.26)))
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                if report.isReady {
                    Button(action: onTestDrive) {
                        Label("TEST DRIVE", systemImage: "play.fill")
                    }
                    .buttonStyle(RacingButtonStyle(prominent: true, accent: Theme.amber, compact: true))
                    .frame(width: 165)
                    .accessibilityIdentifier("validation.testDrive")
                } else {
                    Button {
                        model.autoClose()
                    } label: {
                        Label("AUTO CLOSE", systemImage: "arrow.triangle.merge")
                    }
                    .buttonStyle(RacingButtonStyle(prominent: true, accent: Theme.orange, compact: true))
                    .frame(width: 165)
                    .accessibilityIdentifier("validation.autoClose")
                }
                Spacer()
                Button("DONE", action: onClose)
                    .buttonStyle(RacingButtonStyle(compact: true))
                    .frame(width: 100)
                    .accessibilityIdentifier("validation.done")
            }
        }
        .padding(22)
        .frame(width: 590)
        .frame(minHeight: 430, alignment: .topLeading)
        .background(Theme.panel)
    }

    private func issueCard(_ issues: [String]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("ISSUES")
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(Theme.muted)
            ForEach(issues, id: \.self) { issue in
                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 4, weight: .bold))
                        .foregroundStyle(Theme.amber)
                        .padding(.top, 5)
                    Text(issue)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.offWhite)
                }
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.amber.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.amber.opacity(0.18), lineWidth: 1))
    }
}
