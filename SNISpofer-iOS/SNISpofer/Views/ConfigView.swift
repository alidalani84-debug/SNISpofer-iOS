// ConfigView.swift - Full settings screen matching Windows config.json
import SwiftUI

struct ConfigView: View {
    @EnvironmentObject var configStore: AppConfigStore
    @EnvironmentObject var vpn: VPNManager
    @State private var showSaveAlert = false

    var config: Binding<AppConfig> { $configStore.config }

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#0D0F1A").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {

                        // General Section
                        SettingsSection(title: "تنظیمات عمومی", icon: "network") {
                            SettingsField(label: "آدرس سرور (IP)",
                                          placeholder: "104.19.229.21",
                                          text: config.connectIP)
                            Divider().background(Color(hex: "#1F2937"))
                            SettingsIntField(label: "پورت سرور",
                                            value: config.connectPort)
                            Divider().background(Color(hex: "#1F2937"))
                            SettingsField(label: "Fake SNI",
                                          placeholder: "www.hcaptcha.com",
                                          text: config.fakeSNI)
                            Divider().background(Color(hex: "#1F2937"))
                            SettingsIntField(label: "پورت Listen",
                                            value: config.listenPort)
                        }

                        // Trojan Section
                        if configStore.config.connectionMode == .trojan ||
                           configStore.config.connectionMode == .sniOnly {
                            SettingsSection(title: "تنظیمات Trojan", icon: "bolt.shield.fill") {
                                SettingsField(label: "پسورد",
                                              placeholder: "humanity",
                                              text: config.trojanPassword,
                                              isSecure: true)
                                Divider().background(Color(hex: "#1F2937"))
                                SettingsField(label: "SNI سرور",
                                              placeholder: "www.creationlong.org",
                                              text: config.trojanSNI)
                                Divider().background(Color(hex: "#1F2937"))
                                SettingsField(label: "مسیر WebSocket",
                                              placeholder: "/assignment",
                                              text: config.trojanPath)
                                Divider().background(Color(hex: "#1F2937"))
                                SettingsField(label: "هاست WebSocket",
                                              placeholder: "www.creationlong.org",
                                              text: config.trojanHost)
                            }
                        }

                        // WARP Section
                        if configStore.config.connectionMode == .warp {
                            SettingsSection(title: "تنظیمات WARP", icon: "cloud.fill") {
                                SettingsField(label: "Endpoint",
                                              placeholder: "162.159.192.1",
                                              text: config.warpEndpoint)
                                Divider().background(Color(hex: "#1F2937"))
                                SettingsField(label: "لایسنس (اختیاری)",
                                              placeholder: "",
                                              text: config.warpLicense)
                            }
                        }

                        // Psiphon Section
                        if configStore.config.connectionMode == .psiphon {
                            SettingsSection(title: "تنظیمات Psiphon", icon: "antenna.radiowaves.left.and.right") {
                                SettingsPicker(label: "کشور خروجی",
                                               selection: config.psiphonCountry,
                                               options: ["DE","US","GB","FR","NL","CA","JP","SG"])
                                Divider().background(Color(hex: "#1F2937"))
                                SettingsField(label: "Endpoint",
                                              placeholder: "162.159.193.1",
                                              text: config.psiphonEndpoint)
                            }
                        }

                        // Proxy Ports Section
                        SettingsSection(title: "پورت‌های پروکسی محلی", icon: "point.3.filled.connected.trianglepath.dotted") {
                            SettingsIntField(label: "SOCKS5 Port", value: config.socksPort)
                            Divider().background(Color(hex: "#1F2937"))
                            SettingsIntField(label: "HTTP Port",  value: config.httpPort)
                        }

                        // Reset to defaults
                        Button {
                            withAnimation {
                                configStore.config = .default
                                showSaveAlert = true
                            }
                        } label: {
                            Label("بازگشت به پیش‌فرض", systemImage: "arrow.counterclockwise")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "#EF4444"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color(hex: "#7F1D1D").opacity(0.2))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .strokeBorder(Color(hex: "#EF4444").opacity(0.3), lineWidth: 1)
                                        )
                                )
                        }
                        .padding(.horizontal, 2)

                        Spacer(minLength: 80)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("تنظیمات")
            .navigationBarTitleDisplayMode(.large)
        }
        .preferredColorScheme(.dark)
        .alert("ذخیره شد", isPresented: $showSaveAlert) {
            Button("باشه", role: .cancel) {}
        } message: {
            Text("تنظیمات با موفقیت ذخیره شد.")
        }
    }
}

// MARK: - Reusable Settings Components

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "#6366F1"))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "#6B7280"))
                    .textCase(.uppercase)
                    .tracking(0.8)
            }
            .padding(.bottom, 8)
            .padding(.leading, 4)

            VStack(spacing: 0) { content }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(hex: "#111827"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(Color(hex: "#1F2937"), lineWidth: 1)
                        )
                )
        }
    }
}

struct SettingsField: View {
    let label: String
    let placeholder: String
    var text: Binding<String>
    var isSecure: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "#D1D5DB"))
                .frame(minWidth: 100, alignment: .leading)

            Spacer()

            if isSecure {
                SecureField(placeholder, text: text)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(Color(hex: "#A5B4FC"))
                    .multilineTextAlignment(.trailing)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            } else {
                TextField(placeholder, text: text)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(Color(hex: "#A5B4FC"))
                    .multilineTextAlignment(.trailing)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .keyboardType(.URL)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

struct SettingsIntField: View {
    let label: String
    var value: Binding<Int>

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "#D1D5DB"))
            Spacer()
            TextField("", value: value, format: .number)
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(Color(hex: "#A5B4FC"))
                .multilineTextAlignment(.trailing)
                .keyboardType(.numberPad)
                .frame(width: 80)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

struct SettingsPicker: View {
    let label: String
    var selection: Binding<String>
    let options: [String]

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "#D1D5DB"))
            Spacer()
            Picker("", selection: selection) {
                ForEach(options, id: \.self) { opt in
                    Text(opt).tag(opt)
                }
            }
            .pickerStyle(.menu)
            .accentColor(Color(hex: "#A5B4FC"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
