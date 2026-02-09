import ActivityKit
import SwiftUI
import WidgetKit

struct RidePulseLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RideActivityAttributes.self) { context in
            // MARK: - Lock Screen / Banner View
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // MARK: - Expanded View
                DynamicIslandExpandedRegion(.leading) {
                    expandedMetricView(
                        metric: context.attributes.displayMetrics.count > 0 ? context.attributes.displayMetrics[0] : "power",
                        state: context.state,
                        size: 28,
                        alignment: .leading
                    )
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    expandedMetricView(
                        metric: context.attributes.displayMetrics.count > 1 ? context.attributes.displayMetrics[1] : "heartRate",
                        state: context.state,
                        size: 28,
                        alignment: .trailing
                    )
                }
                
                DynamicIslandExpandedRegion(.center) {
                    expandedMetricView(
                        metric: context.attributes.displayMetrics.count > 2 ? context.attributes.displayMetrics[2] : "cadence",
                        state: context.state,
                        size: 22,
                        alignment: .center
                    )
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        // Goal progress bar
                        if context.state.hasGoal {
                            HStack(spacing: 6) {
                                Text(String(format: "%.1f", context.state.distanceKm))
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(.cyan)
                                    .monospacedDigit()
                                
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color.white.opacity(0.15))
                                            .frame(height: 6)
                                        
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(
                                                LinearGradient(
                                                    colors: [.cyan, .blue],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .frame(width: max(0, geo.size.width * context.state.progress), height: 6)
                                    }
                                }
                                .frame(height: 6)
                                
                                Text(String(format: "%.0f km", context.state.goalDistanceKm))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        
                        HStack {
                            // Connection status
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(context.state.connectionState == "connected" ? Color.green : Color.orange)
                                    .frame(width: 6, height: 6)
                                Text(context.state.connectionState == "connected" ? "연결됨" : "끊김")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            
                            Spacer()
                            
                            // Elapsed time
                            Text(formatTime(context.state.elapsedTime))
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                                .monospacedDigit()
                            
                            Spacer()
                            
                            // Ride state or distance
                            if context.state.rideState == "paused" {
                                Text("일시정지")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.orange)
                            } else if !context.state.hasGoal {
                                Text(String(format: "%.1f km", context.state.distanceKm))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                    }
                    .padding(.top, 4)
                }
                
            } compactLeading: {
                // MARK: - Compact Leading
                if context.state.hasGoal {
                    // Show progress percentage when goal is set
                    HStack(spacing: 3) {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.cyan)
                        Text("\(Int(context.state.progress * 100))%")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .monospacedDigit()
                    }
                } else {
                    HStack(spacing: 3) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.cyan)
                        Text("\(Int(context.state.power))")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .monospacedDigit()
                    }
                }
            } compactTrailing: {
                // MARK: - Compact Trailing
                if context.state.hasGoal {
                    Text(String(format: "%.1f", context.state.distanceKm))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.cyan)
                        .monospacedDigit()
                } else {
                    HStack(spacing: 3) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.red)
                        Text("\(Int(context.state.heartRate))")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .monospacedDigit()
                    }
                }
            } minimal: {
                // MARK: - Minimal
                if context.state.hasGoal {
                    // Show circular progress
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 2)
                        Circle()
                            .trim(from: 0, to: context.state.progress)
                            .stroke(Color.cyan, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 22, height: 22)
                } else {
                    Text("\(Int(context.state.power))")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.cyan)
                        .monospacedDigit()
                }
            }
        }
    }
    
    // MARK: - Lock Screen View
    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<RideActivityAttributes>) -> some View {
        let metrics = context.attributes.displayMetrics.isEmpty
            ? ["power", "heartRate", "cadence"]
            : context.attributes.displayMetrics
        
        VStack(spacing: 12) {
            // Top: App name + connection
            HStack {
                Text("RidePulse")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(context.state.connectionState == "connected" ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                    Text(context.state.connectionState == "connected" ? "연결됨" : "끊김")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            // Goal progress bar (if goal set)
            if context.state.hasGoal {
                VStack(spacing: 6) {
                    HStack {
                        Text(String(format: "%.1f km", context.state.distanceKm))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.cyan)
                            .monospacedDigit()
                        
                        Text("/ \(Int(context.state.goalDistanceKm)) km")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                        
                        Spacer()
                        
                        Text("\(Int(context.state.progress * 100))%")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.15))
                                .frame(height: 8)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [.cyan, .blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(0, geo.size.width * context.state.progress), height: 8)
                        }
                    }
                    .frame(height: 8)
                }
            }
            
            // Metrics — based on user's selected display metrics
            HStack(spacing: 0) {
                ForEach(Array(metrics.prefix(3)), id: \.self) { metric in
                    metricColumn(metric: metric, state: context.state)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Time + distance
            HStack {
                Text(formatTime(context.state.elapsedTime))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
                
                if context.state.rideState == "paused" {
                    Text("일시정지")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(4)
                }
                
                if !context.state.hasGoal {
                    Spacer()
                    Text(String(format: "%.1f km", context.state.distanceKm))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .monospacedDigit()
                }
            }
        }
        .padding(16)
        .activityBackgroundTint(.black.opacity(0.8))
    }
    
    // MARK: - Dynamic Metric Column
    @ViewBuilder
    private func metricColumn(metric: String, state: RideActivityAttributes.ContentState) -> some View {
        switch metric {
        case "power":
            VStack(spacing: 2) {
                Text("\(Int(state.power))")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("W")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
        case "heartRate":
            VStack(spacing: 2) {
                Text("\(Int(state.heartRate))")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.red)
                Text("bpm")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
        case "cadence":
            VStack(spacing: 2) {
                Text("\(Int(state.cadence))")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.green)
                Text("rpm")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
        case "speed":
            VStack(spacing: 2) {
                Text(String(format: "%.1f", state.speed))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.cyan)
                Text("km/h")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
        case "time":
            VStack(spacing: 2) {
                Text(formatTime(state.elapsedTime))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
                Text("시간")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
        default:
            VStack(spacing: 2) {
                Text("\(Int(state.power))")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("W")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }
    
    // MARK: - Expanded Region Metric View
    @ViewBuilder
    private func expandedMetricView(metric: String, state: RideActivityAttributes.ContentState, size: CGFloat, alignment: HorizontalAlignment) -> some View {
        let (value, unit, color) = metricValueUnitColor(metric: metric, state: state)
        VStack(alignment: alignment, spacing: 2) {
            Text(value)
                .font(.system(size: size, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .monospacedDigit()
            Text(unit)
                .font(.system(size: alignment == .center ? 11 : 12, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
    }
    
    private func metricValueUnitColor(metric: String, state: RideActivityAttributes.ContentState) -> (String, String, Color) {
        switch metric {
        case "power":
            return ("\(Int(state.power))", "W", .white)
        case "heartRate":
            return ("\(Int(state.heartRate))", "bpm", .red)
        case "cadence":
            return ("\(Int(state.cadence))", "rpm", .green)
        case "speed":
            return (String(format: "%.1f", state.speed), "km/h", .cyan)
        case "time":
            return (formatTime(state.elapsedTime), "시간", .white)
        default:
            return ("\(Int(state.power))", "W", .white)
        }
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        let h = m / 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m % 60, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
}
