import SwiftUI

@main
struct ZhihuFundsApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .preferredColorScheme(viewModel.state.theme.colorScheme)
                .task {
                    await viewModel.syncAppIcon()
                    await viewModel.bootstrap()
                    if scenePhase == .active {
                        viewModel.startAutoRefresh()
                    }
                }
                .onChange(of: scenePhase) { newPhase in
                    switch newPhase {
                    case .active:
                        viewModel.sceneDidBecomeActive()
                    case .inactive, .background:
                        viewModel.stopAutoRefresh()
                    @unknown default:
                        viewModel.stopAutoRefresh()
                    }
                }
        }
    }
}
