import SwiftUI

@main
struct ZhihuFundsApp: App {
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .preferredColorScheme(viewModel.state.theme.colorScheme)
                .task {
                    await viewModel.bootstrap()
                }
        }
    }
}
