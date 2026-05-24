// SNISpoferApp.swift - App Entry Point
import SwiftUI

@main
struct SNISpoferApp: App {
    @StateObject private var vpnManager = VPNManager.shared
    @StateObject private var configManager = AppConfigStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vpnManager)
                .environmentObject(configManager)
                .preferredColorScheme(.dark)
        }
    }
}

// Stores config with @Published for live UI binding
class AppConfigStore: ObservableObject {
    @Published var config: AppConfig {
        didSet { ConfigManager.shared.save(config) }
    }
    init() { config = ConfigManager.shared.load() }
}

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("اتصال", systemImage: "shield.fill")
                }
            ConfigView()
                .tabItem {
                    Label("تنظیمات", systemImage: "gearshape.fill")
                }
            LogView()
                .tabItem {
                    Label("لاگ", systemImage: "list.bullet.rectangle.fill")
                }
        }
        .accentColor(Color("AccentColor"))
    }
}
