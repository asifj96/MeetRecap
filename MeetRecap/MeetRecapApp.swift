import SwiftData
import SwiftUI

enum AppModelStore {
    static let container: ModelContainer = {
        let testing = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        let configuration = ModelConfiguration(isStoredInMemoryOnly: testing)
        do {
            return try ModelContainer(for: MeetingRecapRecord.self, configurations: configuration)
        } catch {
            fatalError("Could not open the recap store: \(error)")
        }
    }()
}

@main
struct MeetRecapApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(AppModelStore.container)
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var model: MainModel?
    @State private var pendingImport: String?

    var body: some View {
        NavigationStack {
            if let model {
                MainScreen(model: model)
            } else {
                ProgressView()
            }
        }
        .task {
            guard model == nil else { return }
            let repository = LiveRecapRepository(
                context: modelContext,
                api: ProxyRecapAPI(),
                connectivity: NetworkMonitor()
            )
            let created = MainModel(repository: repository)
            if let pendingImport {
                created.prefill(pendingImport)
            }
            model = created
        }
        .onOpenURL { url in
            guard let text = ImportURL.text(from: url) else { return }
            if let model {
                model.prefill(text)
            } else {
                pendingImport = text
            }
        }
    }
}

enum ImportURL {
    static func text(from url: URL) -> String? {
        guard url.scheme == "meetrecap", url.host == "import" else { return nil }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first { $0.name == "text" }?
            .value
    }
}
