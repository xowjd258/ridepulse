import SwiftUI
import SwiftData

// MARK: - Report List View
struct ReportView: View {
    @Query(sort: \RideSession.startTime, order: .reverse) private var sessions: [RideSession]
    @ObservedObject var healthKit = HealthKitManager.shared
    @State private var selectedSession: RideSession?
    @State private var selectedHKWorkout: HKCyclingWorkout?
    @State private var showHKWorkouts = false
    
    var body: some View {
        ZStack {
            Color.tossBg.ignoresSafeArea()
            
            let hasAnyData = !sessions.isEmpty || !healthKit.hkCyclingWorkouts.filter({ !$0.isFromRidePulse }).isEmpty
            
            if !hasAnyData {
                VStack(spacing: 16) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 48))
                        .foregroundColor(.tossTextTertiary)
                    Text("아직 라이딩 기록이 없어요")
                        .font(.tossHeadline())
                        .foregroundColor(.tossTextSecondary)
                    Text("첫 라이딩을 시작해보세요")
                        .font(.tossBody())
                        .foregroundColor(.tossTextTertiary)
                }
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        // Header
                        HStack {
                            Text("리포트")
                                .font(.tossTitle())
                                .foregroundColor(.tossTextPrimary)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        
                        // App session cards
                        ForEach(sessions) { session in
                            Button(action: { selectedSession = session }) {
                                SessionCard(session: session)
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // HealthKit external cycling records
                        let externalWorkouts = healthKit.hkCyclingWorkouts.filter { !$0.isFromRidePulse }
                        if !externalWorkouts.isEmpty {
                            VStack(spacing: 12) {
                                HStack(spacing: 8) {
                                    Image(systemName: "heart.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.tossRed)
                                    Text("건강 앱 사이클링 기록")
                                        .font(.tossHeadline())
                                        .foregroundColor(.tossTextPrimary)
                                    Spacer()
                                    Button(action: { showHKWorkouts.toggle() }) {
                                        Text(showHKWorkouts ? "접기" : "\(externalWorkouts.count)건 보기")
                                            .font(.tossCaption())
                                            .foregroundColor(.tossPrimary)
                                    }
                                }
                                .padding(.horizontal, 20)
                                
                                if showHKWorkouts {
                                    ForEach(externalWorkouts) { workout in
                                        Button(action: { selectedHKWorkout = workout }) {
                                            HKWorkoutCard(workout: workout)
                                        }
                                        .padding(.horizontal, 20)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.bottom, 100)
                }
            }
        }
        .task {
            if healthKit.isAuthorized {
                await healthKit.fetchCyclingWorkouts()
            }
        }
        .sheet(item: $selectedSession) { session in
            RideSummaryView(session: session)
        }
        .sheet(item: $selectedHKWorkout) { workout in
            HKWorkoutDetailView(workout: workout)
        }
    }
}

// MARK: - Session Card
struct SessionCard: View {
    let session: RideSession
    
    var body: some View {
        TossCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(formatDate(session.startTime))
                            .font(.tossCaption())
                            .foregroundColor(.tossTextSecondary)
                        Text(session.rideType == "indoor" ? "실내 라이딩" : "실외 라이딩")
                            .font(.tossHeadline())
                            .foregroundColor(.tossTextPrimary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(.tossTextTertiary)
                }
                
                HStack(spacing: 16) {
                    MetricTile(
                        label: "시간",
                        value: formatDuration(session.duration),
                        unit: "",
                        icon: "clock.fill",
                        color: .tossPrimary
                    )
                    MetricTile(
                        label: "거리",
                        value: String(format: "%.1f", session.distance / 1000),
                        unit: "km",
                        icon: "location.fill",
                        color: .tossGreen
                    )
                    MetricTile(
                        label: "파워",
                        value: "\(Int(session.avgPower))",
                        unit: "W",
                        icon: "bolt.fill",
                        color: .tossOrange
                    )
                    if session.calories > 0 {
                        MetricTile(
                            label: "칼로리",
                            value: "\(Int(session.calories))",
                            unit: "kcal",
                            icon: "flame.fill",
                            color: .tossRed
                        )
                    }
                }
                
                if let highlight = session.highlightText {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.tossYellow)
                        Text(highlight)
                            .font(.tossCaption())
                            .foregroundColor(.tossTextSecondary)
                    }
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M월 d일 (E) HH:mm"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let h = m / 60
        if h > 0 { return "\(h):\(String(format: "%02d", m % 60))" }
        return "\(m)분"
    }
}

// MARK: - Ride Summary View (Post-ride / Detail)
struct RideSummaryView: View {
    let session: RideSession
    @Environment(\.dismiss) private var dismiss
    @State private var showReport = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.tossBg.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // One-page summary
                        summaryCard
                        
                        // 3-line report
                        reportCard
                        
                        // Recommendation
                        recommendationCard
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("오늘의 라이딩")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                        .foregroundColor(.tossPrimary)
                }
            }
        }
    }
    
    // MARK: - Summary Card
    private var summaryCard: some View {
        TossCard {
            VStack(spacing: 20) {
                // Big numbers
                HStack(spacing: 0) {
                    VStack(spacing: 4) {
                        Text(formatDuration(session.duration))
                            .font(.tossMetricMedium())
                            .foregroundColor(.tossTextPrimary)
                        Text("시간")
                            .font(.tossCaption())
                            .foregroundColor(.tossTextSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    
                    Rectangle()
                        .fill(Color.tossTextTertiary.opacity(0.3))
                        .frame(width: 1, height: 40)
                    
                    VStack(spacing: 4) {
                        Text(String(format: "%.1f", session.distance / 1000))
                            .font(.tossMetricMedium())
                            .foregroundColor(.tossTextPrimary)
                        Text("km")
                            .font(.tossCaption())
                            .foregroundColor(.tossTextSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    
                    Rectangle()
                        .fill(Color.tossTextTertiary.opacity(0.3))
                        .frame(width: 1, height: 40)
                    
                    VStack(spacing: 4) {
                        Text("\(Int(session.calories))")
                            .font(.tossMetricMedium())
                            .foregroundColor(.tossTextPrimary)
                        Text("kcal")
                            .font(.tossCaption())
                            .foregroundColor(.tossTextSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                
                // Metric grid
                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        MetricTile(
                            label: "평균 파워",
                            value: "\(Int(session.avgPower))",
                            unit: "W",
                            icon: "bolt.fill",
                            color: .tossPrimary
                        )
                        MetricTile(
                            label: "평균 속도",
                            value: String(format: "%.1f", session.avgSpeed),
                            unit: "km/h",
                            icon: "speedometer",
                            color: .tossOrange
                        )
                        MetricTile(
                            label: "평균 케이던스",
                            value: "\(Int(session.avgCadence))",
                            unit: "rpm",
                            icon: "arrow.triangle.2.circlepath",
                            color: .tossGreen
                        )
                    }
                    if session.avgHR > 0 {
                        HStack(spacing: 16) {
                            MetricTile(
                                label: "평균 심박",
                                value: "\(Int(session.avgHR))",
                                unit: "bpm",
                                icon: "heart.fill",
                                color: .tossRed
                            )
                            MetricTile(
                                label: "최대 파워",
                                value: "\(Int(session.maxPower))",
                                unit: "W",
                                icon: "bolt.fill",
                                color: .tossOrange
                            )
                            MetricTile(
                                label: "최대 속도",
                                value: String(format: "%.1f", session.maxSpeed),
                                unit: "km/h",
                                icon: "speedometer",
                                color: .tossOrange
                            )
                        }
                    }
                }
                
                // Highlight
                if let highlight = session.highlightText {
                    HStack(spacing: 8) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.tossYellow)
                        Text(highlight)
                            .font(.tossBody())
                            .foregroundColor(.tossTextPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Color.tossYellow.opacity(0.08))
                    .cornerRadius(12)
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Report Card
    private var reportCard: some View {
        TossCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .foregroundColor(.tossPrimary)
                    Text("3줄 리포트")
                        .font(.tossHeadline())
                        .foregroundColor(.tossTextPrimary)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    if let line1 = session.reportLine1 {
                        ReportLine(number: 1, text: line1)
                    }
                    if let line2 = session.reportLine2 {
                        ReportLine(number: 2, text: line2)
                    }
                    if let line3 = session.reportLine3 {
                        ReportLine(number: 3, text: line3)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Recommendation Card
    private var recommendationCard: some View {
        TossCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.tossYellow)
                    Text("다음 추천")
                        .font(.tossHeadline())
                        .foregroundColor(.tossTextPrimary)
                }
                
                if let recommendation = session.recommendation {
                    Text(recommendation)
                        .font(.tossBody())
                        .foregroundColor(.tossTextSecondary)
                }
                
                Button(action: { dismiss() }) {
                    Text("추천대로 시작")
                }
                .buttonStyle(TossPrimaryButtonStyle())
            }
        }
        .padding(.horizontal, 20)
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let h = m / 60
        if h > 0 { return "\(h):\(String(format: "%02d", m % 60))" }
        return "\(m)분"
    }
}

// MARK: - Report Line
struct ReportLine: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.tossPrimary)
                .cornerRadius(12)
            
            Text(text)
                .font(.tossBody())
                .foregroundColor(.tossTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - HealthKit Workout Card (external cycling records)
struct HKWorkoutCard: View {
    let workout: HKCyclingWorkout
    
    var body: some View {
        TossCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(formatDate(workout.startDate))
                            .font(.tossCaption())
                            .foregroundColor(.tossTextSecondary)
                        HStack(spacing: 6) {
                            Text(workout.locationType == "indoor" ? "실내 라이딩" : "실외 라이딩")
                                .font(.tossHeadline())
                                .foregroundColor(.tossTextPrimary)
                            
                            // Source badge
                            Text(workout.sourceName)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.tossPrimary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.tossPrimary.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(.tossTextTertiary)
                }
                
                HStack(spacing: 16) {
                    MetricTile(
                        label: "시간",
                        value: formatDuration(workout.duration),
                        unit: "",
                        icon: "clock.fill",
                        color: .tossPrimary
                    )
                    MetricTile(
                        label: "거리",
                        value: String(format: "%.1f", workout.distance / 1000),
                        unit: "km",
                        icon: "location.fill",
                        color: .tossGreen
                    )
                    if workout.avgPower > 0 {
                        MetricTile(
                            label: "파워",
                            value: "\(Int(workout.avgPower))",
                            unit: "W",
                            icon: "bolt.fill",
                            color: .tossOrange
                        )
                    }
                    if workout.calories > 0 {
                        MetricTile(
                            label: "칼로리",
                            value: "\(Int(workout.calories))",
                            unit: "kcal",
                            icon: "flame.fill",
                            color: .tossRed
                        )
                    }
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M월 d일 (E) HH:mm"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let h = m / 60
        if h > 0 { return "\(h):\(String(format: "%02d", m % 60))" }
        return "\(m)분"
    }
}

// MARK: - HealthKit Workout Detail View
struct HKWorkoutDetailView: View {
    let workout: HKCyclingWorkout
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.tossBg.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Source info
                        TossCard {
                            HStack(spacing: 12) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.tossRed)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("건강 앱에서 가져온 기록")
                                        .font(.tossCaption())
                                        .foregroundColor(.tossTextSecondary)
                                    Text(workout.sourceName)
                                        .font(.tossHeadline())
                                        .foregroundColor(.tossTextPrimary)
                                }
                                Spacer()
                                Text(workout.locationType == "indoor" ? "실내" : "실외")
                                    .font(.tossCaption())
                                    .foregroundColor(.tossPrimary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.tossPrimary.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Summary card
                        TossCard {
                            VStack(spacing: 20) {
                                // Big numbers
                                HStack(spacing: 0) {
                                    VStack(spacing: 4) {
                                        Text(formatDuration(workout.duration))
                                            .font(.tossMetricMedium())
                                            .foregroundColor(.tossTextPrimary)
                                        Text("시간")
                                            .font(.tossCaption())
                                            .foregroundColor(.tossTextSecondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    
                                    Rectangle()
                                        .fill(Color.tossTextTertiary.opacity(0.3))
                                        .frame(width: 1, height: 40)
                                    
                                    VStack(spacing: 4) {
                                        Text(String(format: "%.1f", workout.distance / 1000))
                                            .font(.tossMetricMedium())
                                            .foregroundColor(.tossTextPrimary)
                                        Text("km")
                                            .font(.tossCaption())
                                            .foregroundColor(.tossTextSecondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    
                                    Rectangle()
                                        .fill(Color.tossTextTertiary.opacity(0.3))
                                        .frame(width: 1, height: 40)
                                    
                                    VStack(spacing: 4) {
                                        Text("\(Int(workout.calories))")
                                            .font(.tossMetricMedium())
                                            .foregroundColor(.tossTextPrimary)
                                        Text("kcal")
                                            .font(.tossCaption())
                                            .foregroundColor(.tossTextSecondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                
                                // Metric grid
                                VStack(spacing: 12) {
                                    HStack(spacing: 16) {
                                        if workout.avgPower > 0 {
                                            MetricTile(
                                                label: "평균 파워",
                                                value: "\(Int(workout.avgPower))",
                                                unit: "W",
                                                icon: "bolt.fill",
                                                color: .tossPrimary
                                            )
                                        }
                                        MetricTile(
                                            label: "평균 속도",
                                            value: String(format: "%.1f", workout.avgSpeed),
                                            unit: "km/h",
                                            icon: "speedometer",
                                            color: .tossOrange
                                        )
                                        if workout.avgCadence > 0 {
                                            MetricTile(
                                                label: "평균 케이던스",
                                                value: "\(Int(workout.avgCadence))",
                                                unit: "rpm",
                                                icon: "arrow.triangle.2.circlepath",
                                                color: .tossGreen
                                            )
                                        }
                                    }
                                    if workout.avgHR > 0 {
                                        HStack(spacing: 16) {
                                            MetricTile(
                                                label: "평균 심박",
                                                value: "\(Int(workout.avgHR))",
                                                unit: "bpm",
                                                icon: "heart.fill",
                                                color: .tossRed
                                            )
                                            if workout.maxHR > 0 {
                                                MetricTile(
                                                    label: "최대 심박",
                                                    value: "\(Int(workout.maxHR))",
                                                    unit: "bpm",
                                                    icon: "heart.fill",
                                                    color: .tossOrange
                                                )
                                            }
                                            Spacer()
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(formatDate(workout.startDate))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                        .foregroundColor(.tossPrimary)
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M월 d일 (E) HH:mm"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let h = m / 60
        if h > 0 { return "\(h):\(String(format: "%02d", m % 60))" }
        return "\(m)분"
    }
}
