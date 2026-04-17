import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    private var showsError: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { newValue in
                if !newValue {
                    viewModel.errorMessage = nil
                }
            }
        )
    }

    var body: some View {
        TabView {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("基金", systemImage: "list.bullet.rectangle")
            }

            NavigationStack {
                SearchView()
            }
            .tabItem {
                Label("搜索", systemImage: "magnifyingglass")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("设置", systemImage: "gearshape.fill")
            }
        }
        .alert("请求失败", isPresented: showsError) {
            Button("知道了", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "未知错误")
        }
    }
}