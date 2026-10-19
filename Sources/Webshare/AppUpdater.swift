import SwiftUI
import Sparkle
import Combine

@MainActor final class AppUpdater: NSObject, ObservableObject, SPUUpdaterDelegate {
    @Published var canCheck = false
    private var controller: SPUStandardUpdaterController!
    private weak var store: Store?
    private var pendingInstall: (() -> Void)?
    private var transferObservation: AnyCancellable?
    init(store: Store) {
        self.store = store
        super.init()
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: self, userDriverDelegate: nil)
        controller.updater.publisher(for: \.canCheckForUpdates).assign(to: &$canCheck)
        transferObservation = store.$jobs.sink { [weak self] jobs in
            guard !jobs.contains(where: { $0.state == .running }), let handler = self?.pendingInstall else { return }
            self?.pendingInstall = nil
            Task { @MainActor in handler() }
        }
    }
    func check() { controller.checkForUpdates(nil) }
    func updater(_ updater: SPUUpdater, shouldPostponeRelaunchForUpdate item: SUAppcastItem, untilInvokingBlock installHandler: @escaping () -> Void) -> Bool {
        guard store?.jobs.contains(where: { $0.state == .running }) == true else { return false }
        store?.running = false
        pendingInstall = installHandler
        return true
    }
}
