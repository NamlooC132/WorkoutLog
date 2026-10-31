import Foundation
import SwiftData
import Observation

/// A file ready to hand to the share sheet.
struct ShareFile: Identifiable {
    let id = UUID()
    let url: URL
}

/// Export / import logic for the Settings screen.
@MainActor
@Observable
final class SettingsViewModel {
    var shareFile: ShareFile?
    var isImporting = false
    var alertTitle = ""
    var alertMessage: String?

    func export(includeHistory: Bool, context: ModelContext) {
        do {
            let url = try BackupService.exportFile(context: context, includeHistory: includeHistory)
            shareFile = ShareFile(url: url)
        } catch {
            show("Export failed", error.localizedDescription)
        }
    }

    func handleImport(_ result: Result<URL, Error>, context: ModelContext) {
        switch result {
        case .success(let url):
            do {
                let summary = try BackupService.importFile(at: url, context: context)
                show("Import complete", summary.message)
            } catch {
                show("Import failed", error.localizedDescription)
            }
        case .failure(let error):
            show("Import failed", error.localizedDescription)
        }
    }

    func addSampleRoutines(context: ModelContext) {
        SampleDataService.seed(context: context)
        show("Sample routines added", "Push, Pull and Legs were added to your Routines.")
    }

    private func show(_ title: String, _ message: String) {
        alertTitle = title
        alertMessage = message
    }
}
