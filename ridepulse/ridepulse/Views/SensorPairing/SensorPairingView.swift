import SwiftUI

// MARK: - Sensor Pairing Flow
struct SensorPairingView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var bleManager = BLEManager.shared
    @State private var step: PairingStep = .selectType
    @State private var selectedType: SensorType?
    @State private var selectedDevice: DiscoveredDevice?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    enum PairingStep {
        case selectType, scanning, verifying, displayMetrics
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.tossBg.ignoresSafeArea()
                
                switch step {
                case .selectType:
                    SensorTypeSelectionView(
                        selectedType: $selectedType,
                        onNext: {
                            withAnimation(.spring(response: 0.4)) {
                                step = .scanning
                                bleManager.startScan()
                            }
                        },
                        onSkip: {
                            appState.hasRegisteredSensor = true
                            dismiss()
                        }
                    )
                    .transition(.move(edge: .trailing))
                    
                case .scanning:
                    ScanListView(
                        devices: bleManager.discoveredDevices,
                        isScanning: bleManager.isScanning,
                        onSelect: { device in
                            selectedDevice = device
                            bleManager.connect(to: device)
                            withAnimation(.spring(response: 0.4)) {
                                step = .verifying
                            }
                        },
                        onBack: {
                            bleManager.stopScan()
                            withAnimation(.spring(response: 0.4)) {
                                step = .selectType
                            }
                        }
                    )
                    .transition(.move(edge: .trailing))
                    
                case .verifying:
                    VerificationView(
                        device: selectedDevice,
                        bleManager: bleManager,
                        onSave: {
                            saveDevice()
                            withAnimation(.spring(response: 0.4)) {
                                step = .displayMetrics
                            }
                        },
                        onBack: {
                            bleManager.disconnectAll()
                            withAnimation(.spring(response: 0.4)) {
                                step = .scanning
                                bleManager.startScan()
                            }
                        }
                    )
                    .transition(.move(edge: .trailing))
                    
                case .displayMetrics:
                    DisplayMetricSelectionView(
                        selectedMetrics: $appState.selectedDisplayMetrics,
                        onComplete: {
                            appState.hasRegisteredSensor = true
                            dismiss()
                        }
                    )
                    .transition(.move(edge: .trailing))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func saveDevice() {
        guard let device = selectedDevice else { return }
        let sensorDevice = SensorDevice(
            name: device.name,
            peripheralUUID: device.peripheral.identifier.uuidString,
            sensorType: selectedType?.rawValue ?? "ftms",
            isPrimary: true
        )
        modelContext.insert(sensorDevice)
    }
}

// MARK: - Sensor Type Selection
struct SensorTypeSelectionView: View {
    @Binding var selectedType: SensorType?
    let onNext: () -> Void
    let onSkip: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text("센서 등록")
                    .font(.tossTitle())
                    .foregroundColor(.tossTextPrimary)
                Text("어떤 센서를 쓰나요?")
                    .font(.tossBody())
                    .foregroundColor(.tossTextSecondary)
            }
            .padding(.top, 40)
            .padding(.bottom, 32)
            
            VStack(spacing: 12) {
                ForEach([SensorType.power, .heartRate, .cadence, .ftms], id: \.self) { type in
                    Button(action: {
                        selectedType = type
                    }) {
                        HStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedType == type ? Color.tossPrimary.opacity(0.1) : Color.tossBg)
                                    .frame(width: 44, height: 44)
                                Image(systemName: type.icon)
                                    .font(.system(size: 18))
                                    .foregroundColor(selectedType == type ? .tossPrimary : .tossTextSecondary)
                            }
                            
                            Text(type.displayName)
                                .font(.tossHeadline())
                                .foregroundColor(.tossTextPrimary)
                            
                            Spacer()
                            
                            if type == .power {
                                Text("추천")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.tossPrimary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.tossPrimary.opacity(0.1))
                                    .cornerRadius(6)
                            }
                            
                            if selectedType == type {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.tossPrimary)
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.tossCardBg)
                                .shadow(color: selectedType == type ? Color.tossPrimary.opacity(0.1) : Color.clear, radius: 8)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(selectedType == type ? Color.tossPrimary.opacity(0.3) : Color.clear, lineWidth: 1)
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            VStack(spacing: 12) {
                Button(action: onNext) {
                    Text("센서 스캔 시작")
                }
                .buttonStyle(TossPrimaryButtonStyle(isEnabled: selectedType != nil))
                .disabled(selectedType == nil)
                
                Button("나중에 할게요", action: onSkip)
                    .font(.tossBody())
                    .foregroundColor(.tossTextSecondary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Scan List View
struct ScanListView: View {
    let devices: [DiscoveredDevice]
    let isScanning: Bool
    let onSelect: (DiscoveredDevice) -> Void
    let onBack: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.tossTextPrimary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                
                if isScanning {
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(.tossPrimary)
                        Text("근처 센서 찾는 중...")
                            .font(.tossBody())
                            .foregroundColor(.tossTextSecondary)
                    }
                } else {
                    Text("검색 완료")
                        .font(.tossBody())
                        .foregroundColor(.tossTextSecondary)
                }
                
                Text("센서를 깨우기 위해 페달 몇 번 밟아주세요")
                    .font(.tossCaption())
                    .foregroundColor(.tossTextTertiary)
            }
            .padding(.vertical, 20)
            
            // Device list
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(devices) { device in
                        Button(action: { onSelect(device) }) {
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(device.name)
                                        .font(.tossHeadline())
                                        .foregroundColor(.tossTextPrimary)
                                    
                                    HStack(spacing: 8) {
                                        ForEach(device.supportedSensors) { sensor in
                                            SensorBadge(type: sensor)
                                        }
                                        if device.supportedSensors.isEmpty {
                                            Text("센서 감지 중...")
                                                .font(.tossCaption())
                                                .foregroundColor(.tossTextTertiary)
                                        }
                                    }
                                }
                                
                                Spacer()
                                
                                RSSIIndicator(rssi: device.rssi)
                            }
                            .padding(16)
                            .background(Color.tossCardBg)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - Verification View
struct VerificationView: View {
    let device: DiscoveredDevice?
    let bleManager: BLEManager
    let onSave: () -> Void
    let onBack: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.tossTextPrimary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            VStack(spacing: 8) {
                Text("연결 확인")
                    .font(.tossTitle())
                    .foregroundColor(.tossTextPrimary)
                
                if let device = device {
                    Text(device.name)
                        .font(.tossBody())
                        .foregroundColor(.tossTextSecondary)
                }
            }
            .padding(.vertical, 24)
            
            // Verification data
            VStack(spacing: 16) {
                if bleManager.connectionState == .connected {
                    VerificationRow(
                        icon: "checkmark.circle.fill",
                        color: .tossGreen,
                        label: "파워 수신됨",
                        value: "\(Int(bleManager.liveData.power)) W"
                    )
                    VerificationRow(
                        icon: "checkmark.circle.fill",
                        color: .tossGreen,
                        label: "케이던스 수신됨",
                        value: "\(Int(bleManager.liveData.cadence)) rpm"
                    )
                    VerificationRow(
                        icon: "checkmark.circle.fill",
                        color: .tossGreen,
                        label: "심박 수신됨",
                        value: "\(Int(bleManager.liveData.heartRate)) bpm"
                    )
                } else {
                    HStack(spacing: 12) {
                        ProgressView()
                            .tint(.tossPrimary)
                        Text("연결 중...")
                            .font(.tossBody())
                            .foregroundColor(.tossTextSecondary)
                    }
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            VStack(spacing: 12) {
                Button(action: onSave) {
                    Text("이 기기 저장")
                }
                .buttonStyle(TossPrimaryButtonStyle(isEnabled: bleManager.connectionState == .connected))
                .disabled(bleManager.connectionState != .connected)
                
                Button("표시 지표 선택", action: onSave)
                    .font(.tossBody())
                    .foregroundColor(.tossPrimary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }
}

struct VerificationRow: View {
    let icon: String
    let color: Color
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            
            Text(label)
                .font(.tossBody())
                .foregroundColor(.tossTextPrimary)
            
            Spacer()
            
            Text(value)
                .font(.tossHeadline())
                .foregroundColor(.tossTextPrimary)
                .monospacedDigit()
        }
        .padding(16)
        .background(Color.tossCardBg)
        .cornerRadius(12)
    }
}

// MARK: - Display Metric Selection
struct DisplayMetricSelectionView: View {
    @Binding var selectedMetrics: [DisplayMetric]
    let onComplete: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text("라이딩 중 표시할 지표")
                    .font(.tossTitle())
                    .foregroundColor(.tossTextPrimary)
                Text("최대 3개를 선택하세요")
                    .font(.tossBody())
                    .foregroundColor(.tossTextSecondary)
            }
            .padding(.top, 40)
            .padding(.bottom, 32)
            
            VStack(spacing: 12) {
                ForEach(DisplayMetric.allCases) { metric in
                    Button(action: {
                        toggleMetric(metric)
                    }) {
                        HStack(spacing: 16) {
                            Image(systemName: metric.icon)
                                .font(.system(size: 18))
                                .foregroundColor(isSelected(metric) ? .tossPrimary : .tossTextSecondary)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(metric.label)
                                    .font(.tossHeadline())
                                    .foregroundColor(.tossTextPrimary)
                                if !metric.unit.isEmpty {
                                    Text(metric.unit)
                                        .font(.tossCaption())
                                        .foregroundColor(.tossTextSecondary)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: isSelected(metric) ? "checkmark.square.fill" : "square")
                                .font(.system(size: 22))
                                .foregroundColor(isSelected(metric) ? .tossPrimary : .tossTextTertiary)
                        }
                        .padding(16)
                        .background(Color.tossCardBg)
                        .cornerRadius(12)
                    }
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            Button(action: onComplete) {
                Text("완료")
            }
            .buttonStyle(TossPrimaryButtonStyle(isEnabled: !selectedMetrics.isEmpty))
            .disabled(selectedMetrics.isEmpty)
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }
    
    private func isSelected(_ metric: DisplayMetric) -> Bool {
        selectedMetrics.contains(metric)
    }
    
    private func toggleMetric(_ metric: DisplayMetric) {
        if let index = selectedMetrics.firstIndex(of: metric) {
            selectedMetrics.remove(at: index)
        } else if selectedMetrics.count < 3 {
            selectedMetrics.append(metric)
        }
    }
}
