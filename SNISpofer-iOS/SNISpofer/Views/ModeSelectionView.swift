// ModeSelectionView.swift - Bottom sheet for choosing connection mode
import SwiftUI

struct ModeSelectionView: View {
    @Binding var selected: ConnectionMode
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#0D0F1A").ignoresSafeArea()

                VStack(spacing: 12) {
                    ForEach(ConnectionMode.allCases) { mode in
                        ModeCard(mode: mode, isSelected: selected == mode) {
                            withAnimation(.spring()) {
                                selected = mode
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                dismiss()
                            }
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .navigationTitle("حالت اتصال")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("بستن") { dismiss() }
                        .foregroundColor(Color(hex: "#6366F1"))
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct ModeCard: View {
    let mode: ConnectionMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(isSelected
                              ? Color(hex: "#4F46E5")
                              : Color(hex: "#1F2937"))
                        .frame(width: 46, height: 46)
                    Image(systemName: mode.icon)
                        .font(.system(size: 20))
                        .foregroundColor(isSelected ? .white : Color(hex: "#6B7280"))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(mode.rawValue)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Text(mode.description)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#6B7280"))
                        .lineLimit(2)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color(hex: "#6366F1"))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "#111827"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                isSelected
                                    ? Color(hex: "#4F46E5")
                                    : Color(hex: "#1F2937"),
                                lineWidth: isSelected ? 1.5 : 1
                            )
                    )
            )
        }
    }
}
