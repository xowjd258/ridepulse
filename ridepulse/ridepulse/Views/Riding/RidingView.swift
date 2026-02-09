import SwiftUI
import SwiftData

struct RidingView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var bleManager = BLEManager.shared
    @ObservedObject var sessionManager = RideSessionManager.shared
    @Query private var sensors: [SensorDevice]
    @Environment(\.modelContext) private var modelContext
    
    @State private var goalKm: Double = 0
    @State private var showGoalPicker = false
    
    private let goalOptions: [Double] = [0, 5, 10, 15, 20, 25, 30, 40, 50, 75, 100]
    
    var body: some View {
        ZStack {
            Color.tossBg.ignoresSafeArea()
            
            switch sessionManager.state {
            case .idle:
                readyView
            case .riding:
                ridingView
            case .paused:
                pausedView
            case .ended:
                // Will show report via appState
                ProgressView()
            }
        }
        .sheet(isPresented: $showGoalPicker) {
            goalPickerSheet
        }
    }
    
    // MARK: - Goal Picker Sheet
    private var goalPickerSheet: some View {
        NavigationView {
            List {
                ForEach(goalOptions, id: \.self) { km in
                    Button(action: {
                        goalKm = km
                        showGoalPicker = false
                    }) {
                        HStack {
                            if km == 0 {
                                Text("목표 없음")
                                    .foregroundColor(.tossTextPrimary)
                            } else {
                                Text("\(Int(km)) km")
                                    .foregroundColor(.tossTextPrimary)
                            }
                            
                            Spacer()
                            
                            if km == goalKm {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.tossPrimary)
                                    .font(.system(size: 14, weight: .semibold))
                            }
                        }
                    }
                }
            }
            .navigationTitle("목표 거리")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { showGoalPicker = false }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Ready View
    private var readyView: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text("라이딩")
                    .font(.tossTitle())
                    .foregroundColor(.tossTextPrimary)
                
                HStack(spacing: 8) {
                    StatusDot(state: bleManager.connectionState)
                    
                    let connectedCount = bleManager.connectedPeripherals.count
                    let totalCount = sensors.count
                    if totalCount > 0 {
                        Text("센서 연결 (\(connectedCount)/\(totalCount))")
                            .font(.tossCaption())
                            .foregroundColor(.tossTextSecondary)
                    }
                }
            }
            .padding(.top, 40)
            
            Spacer()
            
            // Preview metrics
            VStack(spacing: 24) {
                ForEach(appState.selectedDisplayMetrics) { metric in
                    VStack(spacing: 4) {
                        Text(currentValue(for: metric))
                            .font(.tossMetricMedium())
                            .foregroundColor(.tossTextTertiary)
                            .monospacedDigit()
                        Text(metric.label)
                            .font(.tossCaption())
                            .foregroundColor(.tossTextTertiary)
                    }
                }
            }
            
            Spacer()
            
            // Goal setting card
            VStack(spacing: 0) {
                Button(action: { showGoalPicker = true }) {
                    HStack {
                        Image(systemName: "flag.checkered")
                            .font(.system(size: 18))
                            .foregroundColor(.tossPrimary)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("목표 거리")
                                .font(.tossBody())
                                .foregroundColor(.tossTextPrimary)
                            if goalKm > 0 {
                                Text("\(Int(goalKm)) km")
                                    .font(.tossCaption())
                                    .foregroundColor(.tossPrimary)
                            } else {
                                Text("설정 안됨")
                                    .font(.tossCaption())
                                    .foregroundColor(.tossTextTertiary)
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(.tossTextTertiary)
                    }
                    .padding(16)
                    .background(Color.tossCardBg)
                    .cornerRadius(16)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            
            // Start button
            VStack(spacing: 16) {
                Button(action: startRide) {
                    Text(goalKm > 0 ? "\(Int(goalKm))km 라이딩 시작" : "라이딩 시작")
                }
                .buttonStyle(TossPrimaryButtonStyle())
                
                if bleManager.connectionState != .connected && !sensors.isEmpty {
                    Button("연결 없이 시작") {
                        startRide()
                    }
                    .font(.tossCaption())
                    .foregroundColor(.tossTextSecondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100) // 탭바 높이 고려
        }
    }
    
    // MARK: - Riding View (Big Numbers)
    private var ridingView: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                StatusDot(state: bleManager.connectionState)
                
                // Resistance Level
                if bleManager.liveData.resistanceLevel > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "dial.low.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.tossOrange)
                        Text("R\(Int(bleManager.liveData.resistanceLevel))")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.tossOrange)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.tossOrange.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Spacer()
                
                Text(sessionManager.formattedTime)
                    .font(.tossHeadline())
                    .foregroundColor(.tossTextPrimary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Goal progress bar
            if sessionManager.hasGoal {
                VStack(spacing: 8) {
                    HStack {
                        Text(String(format: "%.1f km", sessionManager.distanceKm))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.tossPrimary)
                            .monospacedDigit()
                        
                        Spacer()
                        
                        Text(String(format: "%.0f km", sessionManager.goalDistanceKm))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.tossTextTertiary)
                    }
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.tossPrimary.opacity(0.15))
                                .frame(height: 12)
                            
                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    LinearGradient(
                                        colors: [.tossPrimary, .tossPrimary.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(0, geo.size.width * sessionManager.goalProgress), height: 12)
                                .animation(.easeInOut(duration: 0.5), value: sessionManager.goalProgress)
                        }
                    }
                    .frame(height: 12)
                    
                    Text("\(Int(sessionManager.goalProgress * 100))% 달성")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.tossTextSecondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
            
            Spacer()
            
            // Big metrics
            VStack(spacing: 32) {
                ForEach(appState.selectedDisplayMetrics) { metric in
                    BigMetricView(
                        value: currentRidingValue(for: metric),
                        unit: metric.unit,
                        label: metric.label,
                        color: metricColor(for: metric)
                    )
                }
            }
            
            Spacer()
            
            // Secondary metrics strip
            secondaryMetricsStrip
            
            // Lap indicator
            HStack {
                Text("Lap \(sessionManager.currentLap)")
                    .font(.tossCaption())
                    .foregroundColor(.tossTextSecondary)
            }
            .padding(.bottom, 12)
            
            // Control buttons
            HStack(spacing: 20) {
                // Lap button
                Button(action: { sessionManager.addLap() }) {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(Color.tossPrimary.opacity(0.1))
                                .frame(width: 64, height: 64)
                            Image(systemName: "flag.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.tossPrimary)
                        }
                        Text("랩")
                            .font(.tossCaption())
                            .foregroundColor(.tossTextSecondary)
                    }
                }
                
                // Pause button
                Button(action: { sessionManager.pauseRide() }) {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(Color.tossOrange.opacity(0.1))
                                .frame(width: 64, height: 64)
                            Image(systemName: "pause.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.tossOrange)
                        }
                        Text("일시정지")
                            .font(.tossCaption())
                            .foregroundColor(.tossTextSecondary)
                    }
                }
                
                // End button
                Button(action: endRide) {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(Color.tossRed.opacity(0.1))
                                .frame(width: 64, height: 64)
                            Image(systemName: "stop.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.tossRed)
                        }
                        Text("종료")
                            .font(.tossCaption())
                            .foregroundColor(.tossTextSecondary)
                    }
                }
            }
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Paused View
    private var pausedView: some View {
        VStack(spacing: 0) {
            HStack {
                StatusDot(state: bleManager.connectionState)
                Spacer()
                Text(sessionManager.formattedTime)
                    .font(.tossHeadline())
                    .foregroundColor(.tossTextPrimary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            Spacer()
            
            VStack(spacing: 24) {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.tossOrange)
                
                Text("일시정지")
                    .font(.tossTitle())
                    .foregroundColor(.tossTextPrimary)
                
                // Goal progress
                if sessionManager.hasGoal {
                    VStack(spacing: 6) {
                        HStack {
                            Text(String(format: "%.1f km", sessionManager.distanceKm))
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.tossPrimary)
                            Text("/")
                                .foregroundColor(.tossTextTertiary)
                            Text(String(format: "%.0f km", sessionManager.goalDistanceKm))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.tossTextTertiary)
                        }
                        
                        ProgressView(value: sessionManager.goalProgress)
                            .tint(.tossPrimary)
                            .padding(.horizontal, 40)
                        
                        Text("\(Int(sessionManager.goalProgress * 100))% 달성")
                            .font(.tossCaption())
                            .foregroundColor(.tossTextSecondary)
                    }
                    .padding(.bottom, 8)
                }
                
                // Summary so far
                VStack(spacing: 12) {
                    HStack(spacing: 20) {
                        MetricTile(
                            label: "평균 파워",
                            value: "\(Int(sessionManager.avgPower))",
                            unit: "W",
                            icon: "bolt.fill",
                            color: .tossPrimary
                        )
                        MetricTile(
                            label: "평균 속도",
                            value: String(format: "%.1f", sessionManager.sampleCount > 0 ? sessionManager.totalSpeed / Double(sessionManager.sampleCount) : 0),
                            unit: "km/h",
                            icon: "speedometer",
                            color: .tossOrange
                        )
                        MetricTile(
                            label: "평균 케이던스",
                            value: "\(Int(sessionManager.avgCadence))",
                            unit: "rpm",
                            icon: "arrow.triangle.2.circlepath",
                            color: .tossGreen
                        )
                    }
                    
                    HStack(spacing: 20) {
                        MetricTile(
                            label: "거리",
                            value: String(format: "%.1f", sessionManager.distanceKm),
                            unit: "km",
                            icon: "location.fill",
                            color: .tossPrimary
                        )
                        MetricTile(
                            label: "칼로리",
                            value: "\(Int(bleManager.liveData.totalEnergy))",
                            unit: "kcal",
                            icon: "flame.fill",
                            color: .tossRed
                        )
                        if sessionManager.avgHR > 0 {
                            MetricTile(
                                label: "평균 심박",
                                value: "\(Int(sessionManager.avgHR))",
                                unit: "bpm",
                                icon: "heart.fill",
                                color: .tossRed
                            )
                        } else {
                            MetricTile(
                                label: "시간",
                                value: sessionManager.formattedTime,
                                unit: "",
                                icon: "clock.fill",
                                color: .tossTextSecondary
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            
            Spacer()
            
            VStack(spacing: 12) {
                Button(action: { sessionManager.resumeRide() }) {
                    Text("계속하기")
                }
                .buttonStyle(TossPrimaryButtonStyle())
                
                Button(action: endRide) {
                    Text("종료하기")
                }
                .buttonStyle(TossSecondaryButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100) // 탭바 높이 고려
        }
    }
    
    // MARK: - Secondary Metrics Strip
    private var secondaryMetricsStrip: some View {
        HStack(spacing: 0) {
            // Avg Power
            VStack(spacing: 2) {
                Text("\(Int(sessionManager.avgPower))")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.tossTextSecondary)
                    .monospacedDigit()
                Text("평균W")
                    .font(.system(size: 10))
                    .foregroundColor(.tossTextTertiary)
            }
            .frame(maxWidth: .infinity)
            
            Rectangle()
                .fill(Color.tossTextTertiary.opacity(0.2))
                .frame(width: 1, height: 24)
            
            // Avg Speed
            VStack(spacing: 2) {
                Text(String(format: "%.1f", sessionManager.sampleCount > 0 ? sessionManager.totalSpeed / Double(sessionManager.sampleCount) : 0))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.tossTextSecondary)
                    .monospacedDigit()
                Text("평균km/h")
                    .font(.system(size: 10))
                    .foregroundColor(.tossTextTertiary)
            }
            .frame(maxWidth: .infinity)
            
            Rectangle()
                .fill(Color.tossTextTertiary.opacity(0.2))
                .frame(width: 1, height: 24)
            
            // Calories (from FTMS or estimated)
            VStack(spacing: 2) {
                Text("\(Int(bleManager.liveData.totalEnergy))")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.tossTextSecondary)
                    .monospacedDigit()
                Text("kcal")
                    .font(.system(size: 10))
                    .foregroundColor(.tossTextTertiary)
            }
            .frame(maxWidth: .infinity)
            
            Rectangle()
                .fill(Color.tossTextTertiary.opacity(0.2))
                .frame(width: 1, height: 24)
            
            // Distance
            VStack(spacing: 2) {
                Text(String(format: "%.1f", sessionManager.distanceKm))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.tossTextSecondary)
                    .monospacedDigit()
                Text("km")
                    .font(.system(size: 10))
                    .foregroundColor(.tossTextTertiary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.tossCardBg.opacity(0.5))
        .cornerRadius(12)
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
    
    // MARK: - Actions
    
    private func startRide() {
        // Auto-connect sensors
        if bleManager.connectionState != .connected {
            for sensor in sensors {
                if let uuid = UUID(uuidString: sensor.peripheralUUID) {
                    bleManager.connectToSaved(uuid: uuid)
                }
            }
        }
        
        // Set goal distance (km -> meters)
        sessionManager.goalDistance = goalKm * 1000.0
        sessionManager.startRide()
    }
    
    private func endRide() {
        let session = sessionManager.endRide()
        modelContext.insert(session)
        
        // Save time series
        let timeSeriesData = sessionManager.timeSeriesBuffer.map { point -> (timestamp: Date, hr: Double, power: Double, cadence: Double) in
            (timestamp: point.timestamp, hr: point.heartRate, power: point.power, cadence: point.cadence)
        }
        
        for point in sessionManager.timeSeriesBuffer {
            point.session = session
            modelContext.insert(point)
        }
        
        try? modelContext.save()
        
        // Save to HealthKit
        Task {
            await HealthKitManager.shared.saveRide(
                startDate: session.startTime,
                endDate: session.endTime ?? Date(),
                duration: session.duration,
                distance: session.distance,
                calories: session.calories,
                avgHR: session.avgHR,
                maxHR: session.maxHR,
                avgPower: session.avgPower,
                avgCadence: session.avgCadence,
                timeSeries: timeSeriesData
            )
        }
        
        appState.lastCompletedSession = session
        appState.showRideSummary = true
    }
    
    // MARK: - Helpers
    
    private func currentValue(for metric: DisplayMetric) -> String {
        switch metric {
        case .power: return "--"
        case .heartRate:
            let hr = Int(bleManager.liveData.heartRate)
            return hr > 0 ? "\(hr)" : "--"
        case .cadence:
            let cad = Int(bleManager.liveData.cadence)
            return cad > 0 ? "\(cad)" : "--"
        case .speed:
            let spd = bleManager.liveData.speed
            return spd > 0 ? String(format: "%.1f", spd) : "--"
        case .time: return "00:00"
        }
    }
    
    private func currentRidingValue(for metric: DisplayMetric) -> String {
        switch metric {
        case .power: return "\(Int(sessionManager.liveData.power))"
        case .heartRate: return "\(Int(sessionManager.liveData.heartRate))"
        case .cadence: return "\(Int(sessionManager.liveData.cadence))"
        case .speed: return String(format: "%.1f", sessionManager.liveData.speed)
        case .time: return sessionManager.formattedTime
        }
    }
    
    private func metricColor(for metric: DisplayMetric) -> Color {
        switch metric {
        case .power: return .tossPrimary
        case .heartRate: return .tossRed
        case .cadence: return .tossGreen
        case .speed: return .tossOrange
        case .time: return .tossTextSecondary
        }
    }
}
