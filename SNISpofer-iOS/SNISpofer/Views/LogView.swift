// LogView.swift - Live tunnel logs viewer
import SwiftUI

struct LogView: View {
    @EnvironmentObject var vpn: VPNManager
    @State private var autoScroll = true
    @State private var searchText = ""

    var filteredLogs: [String] {
        if searchText.isEmpty { return vpn.logs }
        return vpn.logs.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#0D0F1A").ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search bar
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Color(hex: "#6B7280"))
                            .font(.system(size: 14))
                        TextField("جستجو در لاگ...", text: $searchText)
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        if !searchText.isEmpty {
                            Button { searchText = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(Color(hex: "#6B7280"))
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(hex: "#111827"))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color(hex: "#1F2937"), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                    // Log count badge
                    HStack {
                        Text("\(filteredLogs.count) رخداد")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(hex: "#6B7280"))
                        Spacer()
                        Toggle("اسکرول خودکار", isOn: $autoScroll)
                            .toggleStyle(.button)
                            .tint(Color(hex: "#6366F1"))
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "#9CA3AF"))
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 6)

                    // Log list
                    if filteredLogs.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 44))
                                .foregroundColor(Color(hex: "#374151"))
                            Text("لاگی موجود نیست")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(Color(hex: "#4B5563"))
                        }
                        Spacer()
                    } else {
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 2) {
                                    ForEach(Array(filteredLogs.enumerated()), id: \.offset) { idx, log in
                                        LogRow(text: log)
                                            .id(idx)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                            }
                            .onChange(of: vpn.logs.count) { _ in
                                if autoScroll, let last = filteredLogs.indices.last {
                                    withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("لاگ تونل")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        withAnimation { vpn.clearLogs() }
                    } label: {
                        Label("پاک کردن", systemImage: "trash")
                            .foregroundColor(Color(hex: "#EF4444"))
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { vpn.refreshLogs() } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(Color(hex: "#6366F1"))
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { vpn.refreshLogs() }
    }
}

struct LogRow: View {
    let text: String

    var iconAndColor: (String, Color) {
        if text.contains("✅") || text.contains("متصل") {
            return ("circle.fill", Color(hex: "#10B981"))
        } else if text.contains("🔴") || text.contains("قطع") || text.contains("خطا") {
            return ("circle.fill", Color(hex: "#EF4444"))
        } else if text.contains("🟡") || text.contains("در حال") {
            return ("circle.fill", Color(hex: "#F59E0B"))
        } else if text.contains("🔄") {
            return ("arrow.clockwise", Color(hex: "#6366F1"))
        }
        return ("circle.fill", Color(hex: "#374151"))
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: iconAndColor.0)
                .font(.system(size: 6))
                .foregroundColor(iconAndColor.1)
                .padding(.top, 5)

            Text(text)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Color(hex: "#D1D5DB"))
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(hex: "#111827").opacity(0.6))
        )
    }
}
