import AppKit
import Foundation
import LinkPresentation

struct LinkPreview: Hashable {
    let title: String?
    let iconPNGData: Data?
    let imagePNGData: Data?

    var iconImage: NSImage? {
        guard let iconPNGData else { return nil }
        return NSImage(data: iconPNGData)
    }

    var image: NSImage? {
        guard let imagePNGData else { return nil }
        return NSImage(data: imagePNGData)
    }
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

        provider.startFetchingMetadata(for: url) { metadata, _ in
            guard let metadata else {
                DispatchQueue.main.async {
                    LinkPreviewStore.shared.loadingURLs.remove(url)
                }
                return
            }

            Self.buildPreview(from: metadata) { preview in
                DispatchQueue.main.async {
                    LinkPreviewStore.shared.loadingURLs.remove(url)
                    guard preview.title != nil || preview.iconPNGData != nil || preview.imagePNGData != nil else { return }
                    LinkPreviewStore.shared.previews[url] = preview
                }
            }
        }
    }

    private nonisolated static func buildPreview(from metadata: LPLinkMetadata, completion: @escaping @Sendable (LinkPreview) -> Void) {
        let title = metadata.title
        let group = DispatchGroup()
        let accumulator = PreviewAccumulator()

        if let iconProvider = metadata.iconProvider, iconProvider.canLoadObject(ofClass: NSImage.self) {
            group.enter()
            loadPNGData(from: iconProvider) { data in
                accumulator.setIcon(data)
                group.leave()
            }
        }

        if let imageProvider = metadata.imageProvider, imageProvider.canLoadObject(ofClass: NSImage.self) {
            group.enter()
            loadPNGData(from: imageProvider) { data in
                accumulator.setImage(data)
                group.leave()
            }
        }

        group.notify(queue: .global(qos: .userInitiated)) {
            completion(
                LinkPreview(
                    title: title,
                    iconPNGData: accumulator.iconPNGData,
                    imagePNGData: accumulator.imagePNGData
                )
            )
        }
    }

    private nonisolated static func loadPNGData(from provider: NSItemProvider, completion: @escaping @Sendable (Data?) -> Void) {
        provider.loadObject(ofClass: NSImage.self) { object, _ in
            let image = object as? NSImage
            completion(image?.pngData)
        }
    }
}

private final class PreviewAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var iconPNGData: Data?
    private(set) var imagePNGData: Data?

    func setIcon(_ data: Data?) {
        lock.lock()
        iconPNGData = data
        lock.unlock()
    }

    func setImage(_ data: Data?) {
        lock.lock()
        imagePNGData = data
        lock.unlock()
    }
}

private extension NSImage {
    var pngData: Data? {
        guard let tiffData = tiffRepresentation else { return nil }
        guard let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}
