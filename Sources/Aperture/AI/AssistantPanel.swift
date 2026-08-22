import SwiftUI

struct CompactAssistantPanel: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var assistant: AssistantController
    @State private var draft = ""

    init(model: AppModel) {
        self.model = model
        self.assistant = model.assistant
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 7) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                Text("MODEL")
                    .font(.system(size: 7, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.42))
                AssistantModelMenu(model: model, compact: true)
                Text(assistant.webSearchStatus ?? assistant.status.label)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.white.opacity(0.42))
                    .lineLimit(1)
                Spacer()
                Button("Clear") { assistant.clear() }
                    .buttonStyle(.plain)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.white.opacity(0.46))
            }
            .padding(.horizontal, 12)
            .frame(height: 30)

            Rectangle().fill(.white.opacity(0.08)).frame(height: 1)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(assistant.messages) { message in
                            MessageBubble(message: message).id(message.id)
                        }
                        if assistant.isThinking {
                            ThinkingBubble().id("thinking")
                        }
                    }
                    .padding(10)
                }
                .scrollIndicators(.hidden)
                .onChange(of: assistant.messages.count) {
                    if let id = assistant.messages.last?.id {
                        withAnimation { proxy.scrollTo(id, anchor: .bottom) }
                    }
                }
            }

            HStack(spacing: 8) {
                WebSearchButton(assistant: assistant, compact: true)
                TextField("Ask your local model…", text: $draft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 10, weight: .medium))
                    .onSubmit(send)
                Button(action: send) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 25, height: 25)
                        .background(.white, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || assistant.isThinking)
            }
            .padding(.leading, 12)
            .padding(.trailing, 6)
            .frame(height: 37)
            .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .padding(7)
        }
        .foregroundStyle(.white)
        .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 17).stroke(.white.opacity(0.08), lineWidth: 0.6) }
        .onAppear { assistant.probe() }
    }

    private var statusColor: Color {
        switch assistant.status {
        case .checking: return .secondary
        case .ready: return AperturePalette.mint
        case .unavailable: return AperturePalette.accent
        }
    }

    private func send() {
        let message = draft
        draft = ""
        assistant.send(message)
    }
}

struct AssistantPanel: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var assistant: AssistantController
    @State private var draft = ""

    init(model: AppModel) {
        self.model = model
        self.assistant = model.assistant
    }

    var body: some View {
        HStack(spacing: 12) {
            sidecar
                .frame(width: 210)
            conversation
        }
        .onAppear { assistant.probe() }
    }

    private var sidecar: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 7, height: 7)
                        .shadow(color: statusColor.opacity(0.7), radius: 5)
                    Text(assistant.status.label.uppercased()).apertureLabel()
                }
                AssistantModelMenu(model: model, compact: false)
                Text("Inference stays on this Mac. A query leaves only when you switch on Web Search.")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AperturePalette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("TRY ASKING").apertureLabel()
                PromptChip(text: "Turn these notes into a plan") { sendPrompt($0) }
                PromptChip(text: "Draft a calm reply") { sendPrompt($0) }
                PromptChip(text: "Help me reason this through") { sendPrompt($0) }
            }

            Spacer()

            HStack {
                Label(assistant.useWebSearch ? "Search on demand" : "On-device only", systemImage: assistant.useWebSearch ? "globe" : "lock.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(assistant.useWebSearch ? AperturePalette.accent : AperturePalette.mint)
                Spacer()
                Button(action: assistant.probe) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .foregroundStyle(AperturePalette.secondary)
                .help("Test local connection")
            }
        }
        .padding(16)
        .background(AperturePalette.raised, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AperturePalette.line, lineWidth: 1)
        }
    }

    private var conversation: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("LOCAL SIDEKICK").apertureLabel()
                    Text("A private thinking space beside everything else")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AperturePalette.text)
                }
                Spacer()
                Button("Clear") { assistant.clear() }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AperturePalette.secondary)
            }
            .padding(.horizontal, 16)
            .frame(height: 48)

            Rectangle().fill(AperturePalette.line).frame(height: 1)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(assistant.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                        if assistant.isThinking {
                            ThinkingBubble()
                                .id("thinking")
                        }
                    }
                    .padding(14)
                }
                .scrollIndicators(.hidden)
                .onChange(of: assistant.messages.count) {
                    if let id = assistant.messages.last?.id {
                        withAnimation { proxy.scrollTo(id, anchor: .bottom) }
                    }
                }
                .onChange(of: assistant.isThinking) {
                    if assistant.isThinking {
                        withAnimation { proxy.scrollTo("thinking", anchor: .bottom) }
                    }
                }
            }

            composer
        }
        .background(AperturePalette.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AperturePalette.line, lineWidth: 1)
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            WebSearchButton(assistant: assistant, compact: false)
            TextField("Message your local model…", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AperturePalette.text)
                .lineLimit(1...4)
                .onSubmit(sendDraft)
            Button(action: sendDraft) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AperturePalette.ink)
                    .frame(width: 30, height: 30)
                    .background(draft.isEmpty ? AperturePalette.secondary : AperturePalette.accent, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(draft.isEmpty || assistant.isThinking)
        }
        .padding(.leading, 14)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(10)
    }

    private var statusColor: Color {
        switch assistant.status {
        case .checking: return AperturePalette.secondary
        case .ready: return AperturePalette.mint
        case .unavailable: return AperturePalette.accent
        }
    }

    private func sendPrompt(_ text: String) {
        draft = text
    }

    private func sendDraft() {
        let message = draft
        draft = ""
        assistant.send(message)
    }
}

private struct AssistantModelMenu: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var assistant: AssistantController
    let compact: Bool

    init(model: AppModel, compact: Bool) {
        self.model = model
        self.assistant = model.assistant
        self.compact = compact
    }

    var body: some View {
        Menu {
            Button { model.selectAppleModel() } label: {
                modelLabel("Apple On-Device", selected: model.localAIEngine == .apple)
            }
            Divider()
            if assistant.availableModels.isEmpty {
                Text("No Ollama models found")
            } else {
                ForEach(assistant.availableModels, id: \.self) { name in
                    Button { model.selectOllamaModel(name) } label: {
                        modelLabel(name, selected: model.localAIEngine == .ollama && model.ollamaModel == name)
                    }
                }
            }
            Divider()
            Button("Refresh Models", systemImage: "arrow.clockwise") { assistant.probe() }
            SettingsLink {
                Label("Local AI Settings…", systemImage: "gearshape")
            }
        } label: {
            HStack(spacing: compact ? 4 : 7) {
                Image(systemName: model.localAIEngine == .apple ? "apple.intelligence" : "cpu")
                Text(assistant.engineLabel)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: compact ? 6 : 8, weight: .bold))
                    .opacity(0.5)
            }
            .font(.system(size: compact ? 10 : 15, weight: .bold, design: .rounded))
            .foregroundStyle(compact ? Color.white : AperturePalette.text)
            .padding(.horizontal, compact ? 7 : 9)
            .frame(height: compact ? 23 : 30)
            .background(Color.white.opacity(0.055), in: Capsule())
        }
        .menuStyle(.borderlessButton)
        .fixedSize(horizontal: true, vertical: false)
        .help("Choose a local model")
    }

    @ViewBuilder
    private func modelLabel(_ title: String, selected: Bool) -> some View {
        if selected {
            Label(title, systemImage: "checkmark")
        } else {
            Text(title)
        }
    }
}

private struct WebSearchButton: View {
    @ObservedObject var assistant: AssistantController
    let compact: Bool

    var body: some View {
        Button { assistant.useWebSearch.toggle() } label: {
            HStack(spacing: 5) {
                Image(systemName: "globe")
                Text("Web")
            }
            .font(.system(size: compact ? 9 : 10, weight: .bold))
            .foregroundStyle(assistant.useWebSearch ? AperturePalette.ink : AperturePalette.secondary)
            .padding(.horizontal, compact ? 7 : 9)
            .frame(height: compact ? 25 : 30)
            .background(
                assistant.useWebSearch ? AperturePalette.accent : Color.white.opacity(0.06),
                in: Capsule()
            )
            .overlay {
                Capsule().stroke(Color.white.opacity(assistant.useWebSearch ? 0.18 : 0.08), lineWidth: 0.7)
            }
        }
        .buttonStyle(.plain)
        .help(assistant.useWebSearch ? "Web Search is on for the next message" : "Use Web Search for the next message")
    }
}

private struct PromptChip: View {
    let text: String
    let action: (String) -> Void

    var body: some View {
        Button { action(text) } label: {
            HStack(spacing: 7) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 8, weight: .bold))
                Text(text)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundStyle(AperturePalette.text)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
    }
}

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 80) }
            Text(.init(message.content))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(message.role == .user ? AperturePalette.ink : AperturePalette.text)
                .textSelection(.enabled)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    message.role == .user ? AperturePalette.text : Color.white.opacity(0.065),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
            if message.role == .assistant { Spacer(minLength: 80) }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ThinkingBubble: View {
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(AperturePalette.secondary)
                    .frame(width: 5, height: 5)
                    .opacity(0.55 + Double(index) * 0.2)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
    }
}
