import Foundation
import Observation
import SwiftUI
import UIKit
import _PhotosUI_SwiftUI

@MainActor
@Observable
final class MainModel {
    var inputText = ""
    var selectedLanguage = RecapLanguage.english
    var isLoading = false
    var isScanning = false
    var currentRecap: MeetingRecap?
    var errorMessage: String?

    let repository: any RecapRepository
    private let generateRecap: GenerateRecap

    init(repository: any RecapRepository) {
        self.repository = repository
        self.generateRecap = GenerateRecap(repository: repository)
    }

    var charCount: Int { inputText.count }

    var isValidLength: Bool {
        let count = inputText.trimmingCharacters(in: .whitespacesAndNewlines).count
        return count >= GenerateRecap.minimumLength && count <= GenerateRecap.maximumLength
    }

    var canGenerate: Bool { isValidLength && !isLoading }

    func generate() {
        guard canGenerate else { return }
        isLoading = true
        errorMessage = nil
        let text = inputText
        let language = selectedLanguage
        Task {
            defer { isLoading = false }
            do {
                currentRecap = try await generateRecap(text: text, language: language)
            } catch let error as AppError {
                errorMessage = error.message
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func dismissError() {
        errorMessage = nil
    }

    func clear() {
        inputText = ""
        selectedLanguage = .english
        isLoading = false
        isScanning = false
        currentRecap = nil
        errorMessage = nil
    }

    func prefill(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, inputText.isEmpty else { return }
        inputText = text
    }

    func load(id: Int64) async {
        guard let recap = await repository.recap(id: id) else { return }
        inputText = recap.sourceText
        selectedLanguage = recap.language
        currentRecap = recap
        errorMessage = nil
    }

    func scan(item: PhotosPickerItem) async {
        isScanning = true
        errorMessage = nil
        defer { isScanning = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                errorMessage = "Couldn't read text from that image."
                return
            }
            applyScan(try TextRecognizer.recognize(image))
        } catch {
            errorMessage = "Couldn't read text from that image."
        }
    }

    func scan(image: UIImage) {
        isScanning = true
        errorMessage = nil
        do {
            applyScan(try TextRecognizer.recognize(image))
        } catch {
            errorMessage = "Couldn't read text from that image."
        }
        isScanning = false
    }

    private func applyScan(_ text: String) {
        let extracted = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if extracted.isEmpty {
            errorMessage = "No text found in the image."
        } else {
            inputText = extracted
            errorMessage = nil
        }
    }
}
