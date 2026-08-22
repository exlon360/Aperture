import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct PocketNotchView: View {
    @ObservedObject var controller: PocketController
    @State private var isTargeted = false

    private let columns = [
        GridItem(.flexible(), spacing: 9),
        GridItem(.flexible(), spacing: 9)
    ]

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(AperturePalette.accent.opacity(0.12))
                    Image(systemName: "tray.full.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AperturePalette.accent)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Pocket")
                        .font(.system(size: 15, weight: .semibold))
                    Text("A temporary glass shelf. Originals stay where they are.")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !controller.items.isEmpty {
                    Text("\(controller.items.count) \(controller.items.count == 1 ? "ITEM" : "ITEMS")")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.white.opacity(0.06), in: Capsule())
                    Button("Clear", action: controller.clear)
                        .buttonStyle(.borderless)
                        .font(.system(size: 9, weight: .semibold))
                }
            }

            if controller.items.isEmpty {
                dropZone
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 9) {
                        ForEach(controller.items) { item in
                            PocketItemCard(item: item, controller: controller)
                        }
                    }
                }
                .scrollIndicators(.hidden)

                compactDropZone
            }
        }
        .foregroundStyle(.primary)
        .padding(13)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white.opacity(isTargeted ? 0.07 : 0.035), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(isTargeted ? AperturePalette.accent.opacity(0.60) : .white.opacity(0.08), lineWidth: isTargeted ? 1.5 : 0.7)
        }
        .shadow(color: isTargeted ? AperturePalette.accent.opacity(0.14) : .clear, radius: 14)
        .animation(.easeOut(duration: 0.18), value: isTargeted)
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isTargeted, perform: accept)
    }

    private var dropZone: some View {
        VStack(spacing: 11) {
            ZStack {
                Circle()
                    .fill(AperturePalette.accent.opacity(isTargeted ? 0.18 : 0.08))
                    .frame(width: 58, height: 58)
                Image(systemName: isTargeted ? "arrow.down.circle.fill" : "arrow.down.doc")
                    .font(.system(size: 25, weight: .light))
                    .foregroundStyle(isTargeted ? AperturePalette.accent : .secondary)
            }
            Text(isTargeted ? "Release into Pocket" : "Drag files onto the notch")
                .font(.system(size: 15, weight: .semibold))
            Text("Open them later, reveal them in Finder, or copy their paths.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 6]))
                .foregroundStyle(isTargeted ? AperturePalette.accent.opacity(0.6) : .white.opacity(0.12))
        }
    }

    private var compactDropZone: some View {
        HStack(spacing: 7) {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(AperturePalette.accent)
            Text(isTargeted ? "Release to add" : "Drop more files anywhere in this glass")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func accept(_ providers: [NSItemProvider]) -> Bool {
        var foundFile = false
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            foundFile = true
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else {
                    url = item as? URL
                }
                guard let url else { return }
                Task { @MainActor in _ = controller.add([url]) }
            }
        }
        return foundFile
    }
}

private struct PocketItemCard: View {
    let item: PocketItem
    @ObservedObject var controller: PocketController
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                .resizable()
                .scaledToFit()
                .frame(width: 38, height: 38)
                .padding(3)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(item.url.lastPathComponent)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(controller.detail(for: item).uppercased())
                    .font(.system(size: 7, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 2)

            Menu {
                Button("Open", systemImage: "arrow.up.forward.app") { controller.open(item) }
                Button("Reveal in Finder", systemImage: "folder") { controller.reveal(item) }
                Button("Copy Path", systemImage: "doc.on.doc") { controller.copyPath(item) }
                Divider()
                Button("Remove from Pocket", systemImage: "xmark", role: .destructive) { controller.remove(item) }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 26, height: 26)
                    .background(.white.opacity(isHovering ? 0.09 : 0.04), in: Circle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(9)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(isHovering ? 0.085 : 0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(isHovering ? 0.14 : 0.07), lineWidth: 0.6)
        }
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture { controller.open(item) }
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovering)
    }
}
