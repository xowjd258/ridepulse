import SwiftUI
import SwiftData

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var bleManager = BLEManager.shared
    @Query private var sensors: [SensorDevice]
    @State private var showSensorPairing = false
    @State private var showDisplayMetricSheet = false
    @ObservedObject var healthKit = HealthKitManager.shared
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        ZStack {
            Color.tossBg.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    // Header
                    HStack {
                        Text("설정")
                            .font(.tossTitle())
                            .foregroundColor(.tossTextPrimary)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    
                    // Sensor settings
                    sensorSection
                    
                    // Device info (when connected)
                    if bleManager.connectionState == .connected {
                        sensorInfoSection
                        sensorSpecSection
                    }
                    
                    // Display settings
                    displaySection
                    
                    // Health integration
                    healthSection
                    
                    // App info
                    appInfoSection
                }
                .padding(.bottom, 100)
            }
        }
        .sheet(isPresented: $showSensorPairing) {
            SensorPairingView()
        }
        .sheet(isPresented: $showDisplayMetricSheet) {
            NavigationStack {
                DisplayMetricSelectionView(
                    selectedMetrics: $appState.selectedDisplayMetrics,
                    onComplete: { showDisplayMetricSheet = false }
                )
                .navigationTitle("표시 지표 변경")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("닫기") { showDisplayMetricSheet = false }
                            .foregroundColor(.tossPrimary)
                    }
                }
            }
        }
    }
    
    // MARK: - Sensor Section
    private var sensorSection: some View {
        TossCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .foregroundColor(.tossPrimary)
                    Text("센서")
                        .font(.tossHeadline())
                        .foregroundColor(.tossTextPrimary)
                }
                
                if sensors.isEmpty {
                    Text("등록된 센서가 없어요")
                        .font(.tossBody())
                        .foregroundColor(.tossTextSecondary)
                } else {
                    ForEach(sensors) { sensor in
                        HStack(spacing: 12) {
                            Image(systemName: SensorType(rawValue: sensor.sensorType)?.icon ?? "questionmark")
                                .font(.system(size: 16))
                                .foregroundColor(.tossPrimary)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(sensor.name)
                                    .font(.tossBody())
                                    .foregroundColor(.tossTextPrimary)
                                Text(SensorType(rawValue: sensor.sensorType)?.displayName ?? "")
                                    .font(.tossCaption())
                                    .foregroundColor(.tossTextSecondary)
                            }
                            
                            Spacer()
                            
                            StatusDot(state: bleManager.connectionState)
                            
                            Button(action: {
                                modelContext.delete(sensor)
                            }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 14))
                                    .foregroundColor(.tossRed)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Button(action: { showSensorPairing = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                        Text("센서 추가")
                    }
                }
                .buttonStyle(TossSecondaryButtonStyle())
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Display Section
    private var displaySection: some View {
        TossCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "iphone.radiowaves.left.and.right")
                        .foregroundColor(.tossPrimary)
                    Text("표시 (다이나믹 아일랜드)")
                        .font(.tossHeadline())
                        .foregroundColor(.tossTextPrimary)
                }
                
                ForEach(appState.selectedDisplayMetrics) { metric in
                    HStack(spacing: 12) {
                        Image(systemName: metric.icon)
                            .foregroundColor(.tossPrimary)
                            .frame(width: 24)
                        Text(metric.label)
                            .font(.tossBody())
                            .foregroundColor(.tossTextPrimary)
                        if !metric.unit.isEmpty {
                            Text("(\(metric.unit))")
                                .font(.tossCaption())
                                .foregroundColor(.tossTextSecondary)
                        }
                        Spacer()
                    }
                }
                
                Button(action: { showDisplayMetricSheet = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "pencil")
                        Text("변경")
                    }
                }
                .buttonStyle(TossSecondaryButtonStyle())
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Health Section
    private var healthSection: some View {
        TossCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "heart.text.square.fill")
                        .foregroundColor(.tossRed)
                    Text("건강 앱")
                        .font(.tossHeadline())
                        .foregroundColor(.tossTextPrimary)
                }
                
                HStack {
                    Text("연동 상태")
                        .font(.tossBody())
                        .foregroundColor(.tossTextSecondary)
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Circle()
                            .fill(healthKit.isAuthorized ? Color.tossGreen : Color.tossOrange)
                            .frame(width: 8, height: 8)
                        Text(healthKit.authorizationStatus)
                            .font(.tossBody())
                            .foregroundColor(.tossTextPrimary)
                    }
                }
                
                if healthKit.isAuthorized {
                    Text("라이딩 종료 시 운동 기록, 심박수, 파워, 케이던스, 칼로리가 자동으로 건강 앱에 저장됩니다.")
                        .font(.tossCaption())
                        .foregroundColor(.tossTextTertiary)
                } else {
                    Button(action: {
                        Task {
                            await healthKit.requestAuthorization()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "heart.fill")
                            Text("건강 앱 연동하기")
                        }
                    }
                    .buttonStyle(TossSecondaryButtonStyle())
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Sensor Info Section
    private var sensorInfoSection: some View {
        TossCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "cpu")
                        .foregroundColor(.tossPrimary)
                    Text("기기 정보")
                        .font(.tossHeadline())
                        .foregroundColor(.tossTextPrimary)
                }
                
                let info = bleManager.deviceInfo
                
                if let manufacturer = info.manufacturer {
                    deviceInfoRow(label: "제조사", value: manufacturer)
                }
                if let model = info.modelNumber {
                    deviceInfoRow(label: "모델", value: model)
                }
                if let serial = info.serialNumber {
                    deviceInfoRow(label: "시리얼", value: serial)
                }
                if let hw = info.hardwareRevision {
                    deviceInfoRow(label: "하드웨어", value: hw)
                }
                if let fw = info.firmwareRevision {
                    deviceInfoRow(label: "펌웨어", value: fw)
                }
                if let sw = info.softwareRevision {
                    deviceInfoRow(label: "소프트웨어", value: sw)
                }
                
                if info.manufacturer == nil && info.modelNumber == nil {
                    Text("기기 정보를 읽는 중...")
                        .font(.tossCaption())
                        .foregroundColor(.tossTextTertiary)
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Sensor Spec Section
    private var sensorSpecSection: some View {
        let ranges = bleManager.supportedRanges
        let hasData = ranges.powerMax != nil || ranges.speedMax != nil || ranges.resistanceMax != nil
        
        return Group {
            if hasData {
                TossCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "slider.horizontal.3")
                                .foregroundColor(.tossGreen)
                            Text("센서 스펙")
                                .font(.tossHeadline())
                                .foregroundColor(.tossTextPrimary)
                        }
                        
                        if let min = ranges.powerMin, let max = ranges.powerMax {
                            specRow(label: "파워 범위", value: "\(Int(min))~\(Int(max)) W")
                        }
                        if let min = ranges.speedMin, let max = ranges.speedMax {
                            specRow(label: "속도 범위", value: String(format: "%.0f~%.0f km/h", min, max))
                        }
                        if let min = ranges.resistanceMin, let max = ranges.resistanceMax {
                            specRow(label: "저항 범위", value: "\(Int(min))~\(Int(max))")
                        }
                        if let min = ranges.heartRateMin, let max = ranges.heartRateMax {
                            specRow(label: "심박 범위", value: "\(Int(min))~\(Int(max)) bpm")
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    private func deviceInfoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.tossBody())
                .foregroundColor(.tossTextSecondary)
            Spacer()
            Text(value)
                .font(.tossBody())
                .foregroundColor(.tossTextPrimary)
        }
    }
    
    private func specRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.tossBody())
                .foregroundColor(.tossTextSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.tossTextPrimary)
        }
    }
    
    // MARK: - App Info Section
    private var appInfoSection: some View {
        TossCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.tossTextSecondary)
                    Text("앱 정보")
                        .font(.tossHeadline())
                        .foregroundColor(.tossTextPrimary)
                }
                
                HStack {
                    Text("버전")
                        .font(.tossBody())
                        .foregroundColor(.tossTextSecondary)
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .font(.tossBody())
                        .foregroundColor(.tossTextPrimary)
                }
            }
        }
        .padding(.horizontal, 20)
    }
}
