import SwiftUI
import UIKit
import _PhotosUI_SwiftUI

struct MainScreen: View {
    @Bindable var model: MainModel
    @State private var showCamera = false
    @State private var showPhotos = false
    @State private var photoItem: PhotosPickerItem?
    @State private var showShare = false
    @State private var copied = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                inputSection
                languageSection
                generateButton
                if let message = model.errorMessage {
                    errorBanner(message)
                }
                if let recap = model.currentRecap {
                    recapResult(recap)
                }
            }
            .padding(20)
        }
        .navigationTitle("MeetRecap")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink("History") {
                    HistoryScreen(repository: model.repository) { id in
                        Task { await model.load(id: id) }
                    }
                }
            }
        }
        .environment(\.layoutDirection, model.selectedLanguage.isRtl ? .rightToLeft : .leftToRight)
        .overlay {
            if model.isScanning {
                scanningOverlay
            }
        }
        .photosPicker(isPresented: $showPhotos, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            photoItem = nil
            Task { await model.scan(item: item) }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                model.scan(image: image)
            }
        }
        .sheet(isPresented: $showShare) {
            if let recap = model.currentRecap {
                ShareSheet(items: [recap.shareText()])
            }
        }
        .overlay(alignment: .bottom) {
            if copied {
                Text("Copied recap")
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 24)
            }
        }
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(
                "Paste meeting notes or transcript",
                text: $model.inputText,
                axis: .vertical
            )
            .lineLimit(6...10)
            .textFieldStyle(.roundedBorder)
            .textInputAutocapitalization(.sentences)

            HStack {
                Text("\(model.charCount) / 10,000")
                    .font(.caption)
                    .foregroundStyle(countColor)
                Spacer()
                Menu {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button("Take photo") { showCamera = true }
                    }
                    Button("Choose image") { showPhotos = true }
                } label: {
                    Label("Scan", systemImage: "doc.text.viewfinder")
                }
                Button("Clear", action: model.clear)
            }

            if !model.inputText.isEmpty && !model.isValidLength {
                Text(AppError.invalidInput.message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var countColor: Color {
        if model.inputText.isEmpty || model.isValidLength {
            return .secondary
        }
        return .red
    }

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Output language")
                .font(.subheadline.weight(.semibold))
            HStack {
                ForEach(RecapLanguage.allCases, id: \.self) { language in
                    Button(language.displayName) {
                        model.selectedLanguage = language
                    }
                    .buttonStyle(.bordered)
                    .tint(model.selectedLanguage == language ? .accentColor : .secondary)
                }
            }
        }
    }

    private var generateButton: some View {
        Button(action: model.generate) {
            if model.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                Text("Generate")
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(!model.canGenerate)
    }

    private func errorBanner(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message)
                .foregroundStyle(.red)
            HStack {
                Button("Retry", action: model.generate)
                Button("Dismiss", action: model.dismissError)
            }
            .font(.subheadline)
        }
    }

    private func recapResult(_ recap: MeetingRecap) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button("Copy") {
                    UIPasteboard.general.string = recap.shareText()
                    copied = true
                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        copied = false
                    }
                }
                Button("Share") { showShare = true }
            }
            section(recap.language.labels.summary, text: recap.tldr)
            if !recap.decisions.isEmpty {
                bullets(recap.language.labels.decisions, recap.decisions)
            }
            if !recap.actionItems.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(recap.language.labels.actionItems)
                        .font(.headline)
                    ForEach(Array(recap.actionItems.enumerated()), id: \.offset) { _, item in
                        Text(actionLine(item))
                    }
                }
            }
            if !recap.nextSteps.isEmpty {
                bullets(recap.language.labels.nextSteps, recap.nextSteps)
            }
            if !recap.followUpEmail.isEmpty {
                section(recap.language.labels.followUpEmail, text: recap.followUpEmail)
            }
        }
    }

    private func section(_ title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Text(text)
        }
    }

    private func bullets(_ title: String, _ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            ForEach(items, id: \.self) { item in
                Text("• \(item)")
            }
        }
    }

    private func actionLine(_ item: ActionItem) -> String {
        let meta = [item.owner.map { "owner: \($0)" }, item.due.map { "due: \($0)" }]
            .compactMap { $0 }
            .joined(separator: ", ")
        if meta.isEmpty { return "• \(item.task)" }
        return "• \(item.task) (\(meta))"
    }

    private var scanningOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView()
                    .tint(.white)
                Text("Scanning…")
                    .foregroundStyle(.white)
            }
        }
    }
}

struct HistoryScreen: View {
    let repository: any RecapRepository
    var onOpen: (Int64) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var recaps: [MeetingRecap] = []
    @State private var pendingDelete: MeetingRecap?

    var body: some View {
        Group {
            if recaps.isEmpty {
                ContentUnavailableView(
                    "No recaps yet",
                    systemImage: "doc.text",
                    description: Text("Recaps you generate will appear here.")
                )
            } else {
                List {
                    ForEach(recaps, id: \.id) { recap in
                        Button {
                            onOpen(recap.id)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(recap.title)
                                    .font(.body)
                                    .lineLimit(2)
                                Text(recap.language.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions {
                            Button("Delete", role: .destructive) {
                                pendingDelete = recap
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
        .confirmationDialog(
            "Delete this recap?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                guard let pendingDelete else { return }
                Task {
                    await repository.delete(id: pendingDelete.id)
                    self.pendingDelete = nil
                    await reload()
                }
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        }
    }

    private func reload() async {
        recaps = await repository.history()
    }
}
