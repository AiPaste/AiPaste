import Foundation
import LinkPresentation

struct LinkPreview: Hashable {
    let title: String?
}

@MainActor
final class LinkPreviewStore: ObservableObject {
    static let shared = LinkPreviewStore()

    @Published private var previews: [URL: LinkPreview] = [:]
    private var loadingURLs: Set<URL> = []

    private init() {}

    func preview(for url: URL) -> LinkPreview? {
        previews[url]
    }

    func fetchIfNeeded(for url: URL) {
        guard PrivacySettingsStore.shared.generateLinkPreviews else { return }
        guard previews[url] == nil, !loadingURLs.contains(url) else { return }

        loadingURLs.insert(url)
        let provider = LPMetadataProvider()
        provider.timeout = 4

        provider.startFetchingMetadata(for: url) { [weak self] metadata, _ in
            let title = metadata?.title
            Task { @MainActor in
                guard let self else { return }
                self.loadingURLs.remove(url)
                guard let title else { return }
                self.previews[url] = LinkPreview(title: title)
            }
        }
    }
}
