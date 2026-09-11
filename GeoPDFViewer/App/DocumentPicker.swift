import SwiftUI
import UniformTypeIdentifiers

/// A thin SwiftUI wrapper over `UIDocumentPickerViewController` for choosing a
/// PDF from Files/iCloud. Copies the picked file into the app's temporary
/// directory so we hold a stable, readable URL (avoids security-scoped-resource
/// lifetime issues).
struct DocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf], asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController,
                            didPickDocumentsAt urls: [URL]) {
            // asCopy: true delivers a URL in a temporary location we can read
            // directly, so no security-scoped access dance is needed.
            guard let url = urls.first else { return }
            onPick(url)
        }
    }
}
