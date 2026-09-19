import SwiftUI
import SafariServices

struct BrowserPresentation: Identifiable {
    let url: URL

    var id: URL { url }
}

struct BrowserSheetView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss

    let url: URL

    // Safari Services owns the browser chrome and status-bar appearance. Its public
    // API doesn't expose a webpage's colors or loading content, and its former
    // static bar-tint customization is deprecated. Leaving the controller unstyled
    // lets the system apply Safari's supported appearance behavior.

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let configuration = SFSafariViewController.Configuration()
        configuration.entersReaderIfAvailable = false
        configuration.barCollapsingEnabled = true

        let viewController = SFSafariViewController(url: url, configuration: configuration)
        viewController.delegate = context.coordinator
        viewController.dismissButtonStyle = .close
        return viewController
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss)
    }

    final class Coordinator: NSObject, SFSafariViewControllerDelegate {
        private let dismiss: DismissAction

        init(dismiss: DismissAction) {
            self.dismiss = dismiss
        }

        func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
            dismiss()
        }
    }
}
