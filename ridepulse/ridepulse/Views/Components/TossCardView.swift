import SwiftUI

// MARK: - Toss-style Card View
struct TossCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.tossCardBg)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Status Dot
struct StatusDot: View {
    let state: BLEConnectionState
    
    var color: Color {
        switch state {
        case .connected: return .tossGreen
        case .connecting: return .tossOrange
        case .disconnected, .disconnecting: return .tossRed
        }
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(state.label)
                .font(.tossCaption())
                .foregroundColor(.tossTextSecondary)
        }
    }
}

// MARK: - Metric Tile
struct MetricTile: View {
    let label: String
    let value: String
    let unit: String
    let icon: String
    var color: Color = .tossPrimary
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            Text(value)
                .font(.tossMetricSmall())
                .foregroundColor(.tossTextPrimary)
            Text(unit)
                .font(.tossCaption())
                .foregroundColor(.tossTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Big Metric View (for riding)
struct BigMetricView: View {
    let value: String
    let unit: String
    let label: String
    var color: Color = .tossPrimary
    
    var body: some View {
        VStack(spacing: 2) {
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(.tossMetric())
                    .foregroundColor(.tossTextPrimary)
                    .monospacedDigit()
                Text(unit)
                    .font(.tossBody())
                    .foregroundColor(.tossTextSecondary)
            }
            Text(label)
                .font(.tossCaption())
                .foregroundColor(.tossTextTertiary)
        }
    }
}

// MARK: - RSSI Signal Indicator
struct RSSIIndicator: View {
    let rssi: Int
    
    var bars: Int {
        if rssi >= -50 { return 4 }
        if rssi >= -65 { return 3 }
        if rssi >= -80 { return 2 }
        return 1
    }
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(i < bars ? Color.tossGreen : Color.tossTextTertiary.opacity(0.3))
                    .frame(width: 4, height: CGFloat(6 + i * 4))
            }
        }
    }
}

// MARK: - Sensor Badge
struct SensorBadge: View {
    let type: SensorType
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: type.icon)
                .font(.system(size: 10))
            Text(type.displayName)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(.tossPrimary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.tossPrimary.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Empty State Card
struct EmptyStateCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let actionLabel: String
    let action: () -> Void
    
    var body: some View {
        TossCard {
            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(.tossTextTertiary)
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.tossHeadline())
                        .foregroundColor(.tossTextPrimary)
                    Text(subtitle)
                        .font(.tossBody())
                        .foregroundColor(.tossTextSecondary)
                }
                
                Button(action: action) {
                    Text(actionLabel)
                }
                .buttonStyle(TossPrimaryButtonStyle())
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Anomaly Alert Card
struct AnomalyAlertCard: View {
    let message: String
    let action: () -> Void
    
    var body: some View {
        TossCard {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.tossOrange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(message)
                        .font(.tossBody())
                        .foregroundColor(.tossTextPrimary)
                    
                    Button("회복 모드로 전환") {
                        action()
                    }
                    .font(.tossCaption())
                    .foregroundColor(.tossPrimary)
                }
                
                Spacer()
            }
        }
    }
}
