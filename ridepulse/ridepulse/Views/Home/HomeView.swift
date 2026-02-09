import SwiftUI
import SwiftData

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var bleManager = BLEManager.shared
    @ObservedObject var sessionManager = RideSessionManager.shared
    @ObservedObject var healthKit = HealthKitManager.shared
    @Query(sort: \RideSession.startTime, order: .reverse) private var sessions: [RideSession]
    @Query private var sensors: [SensorDevice]
    @State private var showSensorPairing = false
    @State private var hkExternalSummary: (rideCount: Int, totalMinutes: Int, totalDistanceKm: Double, totalCalories: Double) = (0, 0, 0, 0)
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("안녕하세요")
                            .font(.tossCaption())
                            .foregroundColor(.tossTextSecondary)
                        Text("오늘의 라이딩")
                            .font(.tossTitle())
                            .foregroundColor(.tossTextPrimary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                
                // Today's Riding Card
                todayRidingCard
                
                // Weekly Summary Card
                weeklySummaryCard
                
                // Condition Card
                conditionCard
                
                // Recommendation Card
                recommendationCard
                
                // Sensor Status Card
                sensorStatusCard
                
                // Anomaly alerts (if riding)
                if sessionManager.state == .riding {
                    anomalyCards
                }
            }
            .padding(.bottom, 100)
        }
        .background(Color.tossBg)
        .task {
            if healthKit.isAuthorized {
                hkExternalSummary = await healthKit.fetchWeeklyCyclingSummary()
            }
        }
        .sheet(isPresented: $showSensorPairing) {
            SensorPairingView()
        }
    }
    
    // MARK: - Today's Riding Card
    private var todayRidingCard: some View {
        let todaySessions = sessions.filter { Calendar.current.isDateInToday($0.startTime) }
        
        return TossCard {
            if todaySessions.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "bicycle")
                            .font(.system(size: 16))
                            .foregroundColor(.tossPrimary)
                        Text("오늘의 라이딩")
                            .font(.tossHeadline())
                            .foregroundColor(.tossTextPrimary)
                    }
                    
                    Text("오늘 아직 시작 전이에요")
                        .font(.tossBody())
                        .foregroundColor(.tossTextSecondary)
                    
                    Text("지금 시작하면 기록돼요")
                        .font(.tossCaption())
                        .foregroundColor(.tossTextTertiary)
                    
                    Button(action: {
                        appState.selectedTab = .riding
                    }) {
                        Text("시작")
                    }
                    .buttonStyle(TossPrimaryButtonStyle())
                }
            } else {
                let lastSession = todaySessions.first!
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "bicycle")
                            .font(.system(size: 16))
                            .foregroundColor(.tossPrimary)
                        Text("오늘의 라이딩")
                            .font(.tossHeadline())
                            .foregroundColor(.tossTextPrimary)
                    }
                    
                    HStack(spacing: 20) {
                        MetricTile(
                            label: "시간",
                            value: formatDuration(lastSession.duration),
                            unit: "",
                            icon: "clock.fill",
                            color: .tossPrimary
                        )
                        MetricTile(
                            label: "거리",
                            value: String(format: "%.1f", lastSession.distance / 1000),
                            unit: "km",
                            icon: "location.fill",
                            color: .tossGreen
                        )
                        MetricTile(
                            label: "평균 파워",
                            value: "\(Int(lastSession.avgPower))",
                            unit: "W",
                            icon: "bolt.fill",
                            color: .tossOrange
                        )
                    }
                    
                    Button(action: {
                        appState.selectedTab = .report
                    }) {
                        Text("지난 라이딩 보기")
                    }
                    .buttonStyle(TossSecondaryButtonStyle())
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Weekly Summary Card
    private var weeklySummaryCard: some View {
        let appSummary = MetricsAnalyzer.weeklySummary(sessions: sessions)
        
        // Combine: app internal + HealthKit external (no double counting)
        let totalRides = appSummary.rideCount + hkExternalSummary.rideCount
        let totalMinutes = appSummary.totalMinutes + hkExternalSummary.totalMinutes
        let totalDistanceKm = appSummary.totalDistance + hkExternalSummary.totalDistanceKm
        let totalCalories = appSummary.totalCalories + hkExternalSummary.totalCalories
        let hasExternal = hkExternalSummary.rideCount > 0
        
        return TossCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 16))
                        .foregroundColor(.tossGreen)
                    Text("이번 주 누적")
                        .font(.tossHeadline())
                        .foregroundColor(.tossTextPrimary)
                    
                    if hasExternal {
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.tossRed)
                            Text("건강 앱 포함")
                                .font(.system(size: 11))
                                .foregroundColor(.tossTextTertiary)
                        }
                    }
                }
                
                HStack(spacing: 0) {
                    VStack(spacing: 2) {
                        Text("\(totalRides)회")
                            .font(.tossMetricSmall())
                            .foregroundColor(.tossTextPrimary)
                        Text("라이딩")
                            .font(.system(size: 11))
                            .foregroundColor(.tossTextTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    
                    Rectangle()
                        .fill(Color.tossTextTertiary.opacity(0.3))
                        .frame(width: 1, height: 28)
                    
                    VStack(spacing: 2) {
                        Text(formatMinutes(totalMinutes))
                            .font(.tossMetricSmall())
                            .foregroundColor(.tossTextPrimary)
                        Text("시간")
                            .font(.system(size: 11))
                            .foregroundColor(.tossTextTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    
                    Rectangle()
                        .fill(Color.tossTextTertiary.opacity(0.3))
                        .frame(width: 1, height: 28)
                    
                    VStack(spacing: 2) {
                        Text(String(format: "%.0f", totalDistanceKm))
                            .font(.tossMetricSmall())
                            .foregroundColor(.tossTextPrimary)
                        Text("km")
                            .font(.system(size: 11))
                            .foregroundColor(.tossTextTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    
                    Rectangle()
                        .fill(Color.tossTextTertiary.opacity(0.3))
                        .frame(width: 1, height: 28)
                    
                    VStack(spacing: 2) {
                        Text("\(Int(totalCalories))")
                            .font(.tossMetricSmall())
                            .foregroundColor(.tossTextPrimary)
                        Text("kcal")
                            .font(.system(size: 11))
                            .foregroundColor(.tossTextTertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
                
                if totalRides < 3 {
                    Text("남은 \(3 - totalRides)회는 Z2 60분 추천")
                        .font(.tossCaption())
                        .foregroundColor(.tossTextSecondary)
                }
                
                Button(action: {}) {
                    Text("목표 확정")
                }
                .buttonStyle(TossSecondaryButtonStyle())
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Condition Card
    private var conditionCard: some View {
        let condition = MetricsAnalyzer.assessCondition(recentSessions: sessions)
        
        return TossCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 16))
                        .foregroundColor(conditionColor(condition.level))
                    Text("지금 컨디션")
                        .font(.tossHeadline())
                        .foregroundColor(.tossTextPrimary)
                }
                
                HStack(spacing: 8) {
                    Text(condition.level.rawValue)
                        .font(.tossMetricSmall())
                        .foregroundColor(conditionColor(condition.level))
                    
                    Text(condition.message)
                        .font(.tossCaption())
                        .foregroundColor(.tossTextSecondary)
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Recommendation Card
    private var recommendationCard: some View {
        let recommendation: String = {
            if let last = sessions.first {
                return MetricsAnalyzer.generateReport(
                    for: last,
                    timeSeries: last.timeSeries ?? []
                ).recommendation
            }
            return "첫 라이딩을 시작해보세요"
        }()
        
        return TossCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.tossYellow)
                    Text("다음 추천")
                        .font(.tossHeadline())
                        .foregroundColor(.tossTextPrimary)
                }
                
                Text(recommendation)
                    .font(.tossBody())
                    .foregroundColor(.tossTextSecondary)
                
                Button(action: {
                    appState.selectedTab = .riding
                }) {
                    Text("추천대로 시작")
                }
                .buttonStyle(TossSecondaryButtonStyle())
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Sensor Status Card
    private var sensorStatusCard: some View {
        TossCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 16))
                        .foregroundColor(.tossPrimary)
                    Text("센서 상태")
                        .font(.tossHeadline())
                        .foregroundColor(.tossTextPrimary)
                    
                    Spacer()
                    
                    StatusDot(state: bleManager.connectionState)
                }
                
                if sensors.isEmpty {
                    Text("등록된 센서가 없어요")
                        .font(.tossBody())
                        .foregroundColor(.tossTextSecondary)
                    
                    Button(action: { showSensorPairing = true }) {
                        Text("센서 추가")
                    }
                    .buttonStyle(TossPrimaryButtonStyle())
                } else {
                    ForEach(sensors) { sensor in
                        HStack(spacing: 8) {
                            Image(systemName: SensorType(rawValue: sensor.sensorType)?.icon ?? "questionmark")
                                .foregroundColor(.tossPrimary)
                            Text(sensor.name)
                                .font(.tossBody())
                                .foregroundColor(.tossTextPrimary)
                            Spacer()
                            Text(bleManager.connectionState == .connected ? "연결됨" : "대기")
                                .font(.tossCaption())
                                .foregroundColor(bleManager.connectionState == .connected ? .tossGreen : .tossTextTertiary)
                        }
                    }
                    
                    // Training status + Resistance (when connected)
                    if bleManager.connectionState == .connected {
                        Divider().background(Color.tossTextTertiary.opacity(0.2))
                        
                        HStack(spacing: 16) {
                            // Training Status
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(trainingStatusColor)
                                    .frame(width: 8, height: 8)
                                Text(bleManager.trainingStatus.rawValue)
                                    .font(.tossCaption())
                                    .foregroundColor(.tossTextPrimary)
                            }
                            
                            Spacer()
                            
                            // Resistance Level
                            if bleManager.liveData.resistanceLevel > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "dial.low.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.tossOrange)
                                    Text("저항 \(Int(bleManager.liveData.resistanceLevel))")
                                        .font(.tossCaption())
                                        .foregroundColor(.tossTextSecondary)
                                }
                            }
                        }
                    }
                    
                    if bleManager.connectionState != .connected {
                        Button(action: {
                            if let sensor = sensors.first,
                               let uuid = UUID(uuidString: sensor.peripheralUUID) {
                                bleManager.connectToSaved(uuid: uuid)
                            }
                        }) {
                            Text("자동 연결")
                        }
                        .buttonStyle(TossSecondaryButtonStyle())
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var trainingStatusColor: Color {
        switch bleManager.trainingStatus {
        case .idle, .preWorkout: return .tossTextTertiary
        case .warmingUp, .coolDown: return .tossOrange
        case .lowIntensity, .manualMode, .quickStart: return .tossGreen
        case .highIntensity: return .tossRed
        case .recovery: return .tossPrimary
        case .postWorkout: return .tossTextSecondary
        default: return .tossTextTertiary
        }
    }
    
    // MARK: - Anomaly Cards
    @ViewBuilder
    private var anomalyCards: some View {
        let anomalies = MetricsAnalyzer.detectAnomalies(
            current: sessionManager.liveData,
            recentSessions: sessions
        )
        ForEach(anomalies, id: \.self) { anomaly in
            AnomalyAlertCard(message: anomaly) {
                // Switch to recovery mode
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Helpers
    
    private func conditionColor(_ level: ConditionLevel) -> Color {
        switch level {
        case .good: return .tossGreen
        case .normal: return .tossOrange
        case .tired: return .tossRed
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let h = m / 60
        if h > 0 {
            return "\(h)시간 \(m % 60)분"
        }
        return "\(m)분"
    }
    
    private func formatMinutes(_ minutes: Int) -> String {
        let h = minutes / 60
        if h > 0 {
            return "\(h)시간 \(minutes % 60)분"
        }
        return "\(minutes)분"
    }
}
