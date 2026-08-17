import SwiftUI

struct HelpView: View {
    var onClose: () -> Void
    @State private var selectedTopicID: String

    init(onClose: @escaping () -> Void = {}) {
        self.onClose = onClose
        _selectedTopicID = State(initialValue: HelpContent.topics[0].id)
    }

    private var selectedTopic: HelpTopic {
        HelpContent.topic(id: selectedTopicID)
    }

    private var selectedIndex: Int {
        HelpContent.topics.firstIndex(where: { $0.id == selectedTopicID }) ?? 0
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle()
                .fill(Theme.stroke)
                .frame(height: 1)
            HStack(spacing: 0) {
                sidebar
                Rectangle()
                    .fill(Theme.stroke)
                    .frame(width: 1)
                detail
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(CarbonBackground())
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.orange.opacity(0.16))
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.orange)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text("DRIVER'S HANDBOOK")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(2.2)
                    .foregroundStyle(Theme.orange)
                Text("Help & Controls")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.offWhite)
                    .accessibilityIdentifier("help.title")
                Text("Everything you need to get on track, stay on track and build the next circuit.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.muted)
            }

            Spacer()

            MiniPill(text: "Cmd-?",
                     tint: Theme.amber,
                     icon: "keyboard")
            Button(action: onClose) {
                HStack(spacing: 7) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                    Text("CLOSE")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1.2)
                }
                .foregroundStyle(Theme.offWhite)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule().fill(Color.white.opacity(0.065))
                        .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
                )
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
            .accessibilityIdentifier("help.close")
            .accessibilityLabel("Close help")
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("TOPICS")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(1.8)
                .foregroundStyle(Theme.muted)
                .padding(.horizontal, 18)
                .padding(.top, 20)
                .padding(.bottom, 10)

            VStack(spacing: 5) {
                ForEach(HelpContent.topics) { topic in
                    topicButton(topic)
                }
            }
            .padding(.horizontal, 12)

            Spacer(minLength: 16)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Theme.amber)
                    Text("LOCAL FIRST")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(Theme.amber)
                }
                Text("Every race is playable offline. Help is always available from the Help menu.")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.035))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Theme.stroke, lineWidth: 1)
                    )
            )
            .padding(14)
        }
        .frame(width: 272)
        .background(Theme.panel.opacity(0.35))
    }

    private func topicButton(_ topic: HelpTopic) -> some View {
        let selected = topic.id == selectedTopicID
        return Button {
            selectedTopicID = topic.id
        } label: {
            HStack(spacing: 10) {
                Image(systemName: topic.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(selected ? Theme.orange : Theme.muted)
                    .frame(width: 20)
                Text(topic.title)
                    .font(.system(size: 11, weight: selected ? .bold : .semibold, design: .rounded))
                    .foregroundStyle(selected ? Theme.offWhite : Theme.muted)
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(selected ? Theme.orange.opacity(0.8) : Theme.muted.opacity(0.35))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(selected ? Theme.orange.opacity(0.13) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(selected ? Theme.orange.opacity(0.35) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("help.topic.\(topic.id)")
        .accessibilityLabel(topic.title)
    }

    private var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 8) {
                    Text(String(format: "TOPIC %02d / %02d", selectedIndex + 1, HelpContent.topics.count))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(Theme.orange)
                    Rectangle()
                        .fill(Theme.stroke)
                        .frame(height: 1)
                }

                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(Theme.orange.opacity(0.12))
                        Image(systemName: selectedTopic.icon)
                            .font(.system(size: 19, weight: .bold))
                            .foregroundStyle(Theme.orange)
                    }
                    .frame(width: 48, height: 48)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(selectedTopic.title)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.offWhite)
                            .accessibilityIdentifier("help.detail.title")
                        Text(selectedTopic.summary)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("help.detail.summary")
                    }
                }

                Rectangle()
                    .fill(Theme.stroke)
                    .frame(height: 1)

                VStack(alignment: .leading, spacing: 18) {
                    ForEach(selectedTopic.sections) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.title.uppercased())
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .tracking(1.3)
                                .foregroundStyle(Theme.amber)
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(section.items, id: \.self) { item in
                                    HStack(alignment: .top, spacing: 9) {
                                        Circle()
                                            .fill(Theme.orange.opacity(0.75))
                                            .frame(width: 4, height: 4)
                                            .padding(.top, 6)
                                        Text(item)
                                            .font(.system(size: 11, weight: .medium, design: .rounded))
                                            .foregroundStyle(Theme.offWhite.opacity(0.9))
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                    }
                }

                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.teal)
                        .padding(.top, 1)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("TIP")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .tracking(1.2)
                            .foregroundStyle(Theme.teal)
                        Text(selectedTopic.tip)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.teal.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Theme.teal.opacity(0.18), lineWidth: 1)
                        )
                )

                Text("APEX SLOT RACING  ·  DRIVER'S HANDBOOK  ·  v1.0")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(Theme.muted.opacity(0.55))
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .id(selectedTopicID)
        }
    }
}
