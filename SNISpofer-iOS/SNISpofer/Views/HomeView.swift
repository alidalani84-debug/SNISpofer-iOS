// HomeView.swift - Main connection screen with animated UI
import SwiftUI
import Combine

struct HomeView: View {
    @EnvironmentObject var vpn: VPNManager
    @EnvironmentObject var configStore: AppConfigStore
    @State private var pulseScale: CGFloat = 1.0
    @State private var ringOpacity: Double = 0.0
    @State private var showModeSheet = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(hex: "#0D0F1A"), Color(hex: "#111827")],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerSection
                    .padding(.top, 20)

                Spacer()

                // Mode badge
                modeBadge
                    .padding(.bottom, 28)

                // Main connect button
                connectButton
                    .padding(.bottom, 36)

                // Stats row
                if vpn.state.isConnected {
                    statsRow
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 32)
                }

                Spacer()

                // Status label
                statusLabel
                    .padding(.bottom, 40)
            }
            .padding(.horizontal, 24)
        }
        .sheet(isPresented: $showModeSheet) {
            ModeSelectionView(selected: $configStore.config.connectionMode)
        }
        .onAppear { startPulse() }
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("SNI Spoofer")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("ضد فیلتر هوشمند")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "#6B7280"))
            }
            Spacer()
            // Signal strength indicator
            HStack(spacing: 3) {
                ForEach(0..<4) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i < signalBars ? Color(hex: "#6366F1") : Color(hex: "#1F2937"))
                        .frame(width: 4, height: CGFloat(6 + i * 4))
                }
            }
        }
    }

    private var signalBars: Int {
        switch vpn.state {
        case .connected:    return 4
        case .connecting:   return 2
        default:            return 0
        }
    }

    // MARK: - Mode Badge
    private var modeBadge: some View {
        Button { showModeSheet = true } label: {
            HStack(spacing: 8) {
                Image(systemName: configStore.config.connectionMode.icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(configStore.config.connectionMode.rawValue)
                    .font(.system(size: 14, weight: .semibold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .opacity(0.6)
            }
            .foregroundColor(Color(hex: "#A5B4FC"))
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(hex: "#1E1B4B").opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(Color(hex: "#4338CA").opacity(0.5), lineWidth: 1)
                    )
            )
        }
        .disabled(vpn.state.isConnected || vpn.state == .connecting)
    }

    // MARK: - Connect Button
    private var connectButton: some View {
        ZStack {
            // Outer pulse rings (visible only when connected)
            if vpn.state.isConnected {
                ForEach(0..<3) { i in
                    Circle()
                        .strokeBorder(
                            buttonColor.opacity(ringOpacity / Double(i + 1)),
                            lineWidth: 1.5
                        )
                        .frame(width: 160 + CGFloat(i * 30),
                               height: 160 + CGFloat(i * 30))
                        .scaleEffect(pulseScale - CGFloat(i) * 0.08)
                }
            }

            // Button glow
            Circle()
                .fill(buttonColor.opacity(0.15))
                .frame(width: 150, height: 150)
                .blur(radius: 20)

            // Main button
            Button(action: handleTap) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: buttonGradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 140, height: 140)
                        .shadow(color: buttonColor.opacity(0.6), radius: 24, x: 0, y: 8)

                    VStack(spacing: 6) {
                        if vpn.state == .connecting || vpn.state == .disconnecting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.4)
                        } else {
                            Image(systemName: vpn.state.isConnected ? "power" : "power")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.white)
                        }
                        Text(buttonLabel)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white.opacity(0.85))
                            .tracking(1.5)
                    }
                }
            }
            .scaleEffect(pulseScale)
            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: vpn.state.isConnected)
            .disabled(vpn.state == .connecting || vpn.state == .disconnecting)
        }
    }

    private var buttonLabel: String {
        switch vpn.state {
        case .connected:     return "CONNECTED"
        case .connecting:    return "CONNECTING"
        case .disconnecting: return "STOPPING"
        default:             return "CONNECT"
        }
    }

    private var buttonColor: Color {
        switch vpn.state {
        case .connected:  return Color(hex: "#6366F1")
        case .connecting: return Color(hex: "#F59E0B")
        case .failed:     return Color(hex: "#EF4444")
        default:          return Color(hex: "#374151")
        }
    }

    private var buttonGradient: [Color] {
        switch vpn.state {
        case .connected:
            return [Color(hex: "#6366F1"), Color(hex: "#4F46E5")]
        case .connecting:
            return [Color(hex: "#F59E0B"), Color(hex: "#D97706")]
        case .failed:
            return [Color(hex: "#EF4444"), Color(hex: "#DC2626")]
        default:
            return [Color(hex: "#1F2937"), Color(hex: "#111827")]
        }
    }

    private func handleTap() {
        if vpn.state.isConnected {
            vpn.disconnect()
        } else {
            vpn.connect(config: configStore.config)
        }
    }

    // MARK: - Stats Row
    private var statsRow: some View {
        HStack(spacing: 0) {
            statCard(icon: "arrow.down.circle.fill",
                     label: "دریافت",
                     value: vpn.stats.formattedIn,
                     color: Color(hex: "#10B981"))
            Divider()
                .background(Color(hex: "#1F2937"))
                .frame(height: 40)
            statCard(icon: "clock.fill",
                     label: "مدت",
                     value: vpn.stats.formattedDuration,
                     color: Color(hex: "#6366F1"))
            Divider()
                .background(Color(hex: "#1F2937"))
                .frame(height: 40)
            statCard(icon: "arrow.up.circle.fill",
                     label: "ارسال",
                     value: vpn.stats.formattedOut,
                     color: Color(hex: "#F59E0B"))
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(hex: "#111827"))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(Color(hex: "#1F2937"), lineWidth: 1)
                )
        )
    }

    private func statCard(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "#6B7280"))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Status Label
    private var statusLabel: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusDotColor)
                .frame(width: 8, height: 8)
                .shadow(color: statusDotColor.opacity(0.8), radius: 4)
            Text(vpn.state.displayTitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "#9CA3AF"))
        }
    }

    private var statusDotColor: Color {
        switch vpn.state {
        case .connected:                return Color(hex: "#10B981")
        case .connecting, .disconnecting: return Color(hex: "#F59E0B")
        case .failed:                   return Color(hex: "#EF4444")
        default:                        return Color(hex: "#374151")
        }
    }

    // MARK: - Pulse Animation
    private func startPulse() {
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            pulseScale  = 1.05
            ringOpacity = 0.6
        }
    }
}

// MARK: - Color Hex Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a,r,g,b) = (255,(int>>8)*17,(int>>4&0xF)*17,(int&0xF)*17)
        case 6:  (a,r,g,b) = (255,int>>16,int>>8&0xFF,int&0xFF)
        case 8:  (a,r,g,b) = (int>>24,int>>16&0xFF,int>>8&0xFF,int&0xFF)
        default: (a,r,g,b) = (255,0,0,0)
        }
        self.init(.sRGB,
                  red:   Double(r)/255,
                  green: Double(g)/255,
                  blue:  Double(b)/255,
                  opacity: Double(a)/255)
    }
}
