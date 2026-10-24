import UIKit

final class ShareViewController: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        extractText()
    }

    private func extractText() {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = item.attachments else {
            finish()
            return
        }

        let providers = attachments.filter { $0.hasItemConformingToTypeIdentifier("public.plain-text") }
        guard !providers.isEmpty else {
            finish()
            return
        }

        let group = DispatchGroup()
        var texts: [String] = []
        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: "public.plain-text", options: nil) { item, _ in
                if let text = item as? String {
                    texts.append(text)
                }
                group.leave()
            }
        }
        group.notify(queue: .main) { [weak self] in
            self?.openHost(with: texts.joined(separator: "\n"))
        }
    }

    private func openHost(with text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            finish()
            return
        }
        var components = URLComponents()
        components.scheme = "meetrecap"
        components.host = "import"
        components.queryItems = [URLQueryItem(name: "text", value: trimmed)]
        if let url = components.url {
            open(url)
        }
        finish()
    }

    private func open(_ url: URL) {
        var responder: UIResponder? = self
        let selector = sel_registerName("openURL:")
        while let current = responder {
            if current.responds(to: selector) {
                _ = current.perform(selector, with: url)
                break
            }
            responder = current.next
        }
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
