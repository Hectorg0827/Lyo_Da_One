import SwiftUI
import UniformTypeIdentifiers

// MARK: - Document Picker View
/// A shared document picker supporting multiple content types and security-scoped resources.
struct DocumentPickerView: UIViewControllerRepresentable {
    let onPick: (URL?) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [
            .pdf, .plainText, .rtf,
            .spreadsheet, .presentation,
            .image, .movie, .audio, .data, .item
        ])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, dismiss: dismiss)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL?) -> Void
        let dismiss: DismissAction

        init(onPick: @escaping (URL?) -> Void, dismiss: DismissAction) {
            self.onPick = onPick
            self.dismiss = dismiss
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPick(urls.first)
            dismiss()
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onPick(nil)
            dismiss()
        }
    }
}
