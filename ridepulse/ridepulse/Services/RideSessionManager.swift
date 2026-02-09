import Foundation
import SwiftData
import Combine

// MARK: - Ride Session Manager
@MainActor
class RideSessionManager: ObservableObject {
    static let shared = RideSessionManager()
    
    @Published var state: RideState = .idle
    @Published var elapsedTime: TimeInterval = 0
    @Published var currentLap: Int = 1
    @Published var liveData = LiveSensorData()
    @Published var goalDistance: Double = 0 // meters, 0 = no goal
    
    // Current session accumulator
    @Published var totalPower: Double = 0
    @Published var maxPower: Double = 0
    @Published var totalHR: Double = 0
    @Published var maxHR: Double = 0
    @Published var totalCadence: Double = 0
    @Published var maxCadence: Double = 0
    @Published var totalSpeed: Double = 0
    @Published var maxSpeed: Double = 0
    @Published var sampleCount: Int = 0
    @Published var distance: Double = 0 // meters
    private var ftmsBaseDistance: Double? = nil // FTMS total distance at ride start
    private var usesFTMSDistance: Bool = false
    
    // Lap data
    @Published var lapStartTime: Date = Date()
    @Published var lapPower: Double = 0
    @Published var lapHR: Double = 0
    @Published var lapCadence: Double = 0
    @Published var lapSamples: Int = 0
    
    // Time series buffer
    var timeSeriesBuffer: [TimeSeriesPoint] = []
    
    private var timer: Timer?
    private var startTime: Date?
    private var pausedDuration: TimeInterval = 0
    private var pauseStartTime: Date?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        observeBLEData()
    }
    
    private var lastSampleTime: Date = Date()
    
    private func observeBLEData() {
        BLEManager.shared.$liveData
            .receive(on: RunLoop.main)
            .sink { [weak self] data in
                guard let self = self, self.state == .riding else { return }
                self.liveData = data
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Session Control
    
    func startRide() {
        state = .riding
        startTime = Date()
        elapsedTime = 0
        pausedDuration = 0
        currentLap = 1
        resetAccumulators()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        
        // Start Live Activity
        LiveActivityManager.shared.startActivity(
            power: 0, heartRate: 0, cadence: 0,
            elapsedTime: 0, distance: 0, goalDistance: goalDistance,
            state: .riding
        )
    }
    
    func pauseRide() {
        state = .paused
        pauseStartTime = Date()
        timer?.invalidate()
        
        LiveActivityManager.shared.updateActivity(
            power: liveData.power,
            heartRate: liveData.heartRate,
            cadence: liveData.cadence,
            speed: liveData.speed,
            elapsedTime: elapsedTime,
            distance: distance,
            goalDistance: goalDistance,
            state: .paused
        )
    }
    
    func resumeRide() {
        state = .riding
        if let pauseStart = pauseStartTime {
            pausedDuration += Date().timeIntervalSince(pauseStart)
        }
        pauseStartTime = nil
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        
        LiveActivityManager.shared.updateActivity(
            power: liveData.power,
            heartRate: liveData.heartRate,
            cadence: liveData.cadence,
            speed: liveData.speed,
            elapsedTime: elapsedTime,
            distance: distance,
            goalDistance: goalDistance,
            state: .riding
        )
    }
    
    func endRide() -> RideSession {
        state = .ended
        timer?.invalidate()
        
        let session = buildSession()
        
        LiveActivityManager.shared.endActivity()
        
        // Reset for next ride
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.state = .idle
        }
        
        return session
    }
    
    func addLap() {
        currentLap += 1
        lapStartTime = Date()
        lapPower = 0
        lapHR = 0
        lapCadence = 0
        lapSamples = 0
    }
    
    // MARK: - Private
    
    private func tick() {
        guard let start = startTime else { return }
        elapsedTime = Date().timeIntervalSince(start) - pausedDuration
        
        // Record sample once per second (timer-driven, not BLE-event-driven)
        recordSample(liveData)
        
        // Update Live Activity every 2 seconds
        if Int(elapsedTime) % 2 == 0 {
            LiveActivityManager.shared.updateActivity(
                power: liveData.power,
                heartRate: liveData.heartRate,
                cadence: liveData.cadence,
                speed: liveData.speed,
                elapsedTime: elapsedTime,
                distance: distance,
                goalDistance: goalDistance,
                state: state
            )
        }
    }
    
    private func recordSample(_ data: LiveSensorData) {
        sampleCount += 1
        totalPower += data.power
        totalHR += data.heartRate
        totalCadence += data.cadence
        totalSpeed += data.speed
        
        maxPower = max(maxPower, data.power)
        maxHR = max(maxHR, data.heartRate)
        maxCadence = max(maxCadence, data.cadence)
        maxSpeed = max(maxSpeed, data.speed)
        
        // Distance: prefer FTMS Total Distance (exact), fallback to speed integration
        if let ftmsDist = data.totalDistance {
            if ftmsBaseDistance == nil {
                ftmsBaseDistance = ftmsDist
            }
            usesFTMSDistance = true
            distance = ftmsDist - (ftmsBaseDistance ?? 0)
        } else if !usesFTMSDistance {
            // Fallback: speed (km/h) * time (1 sec) -> meters
            distance += data.speed / 3.6
        }
        
        // Lap accumulation
        lapSamples += 1
        lapPower += data.power
        lapHR += data.heartRate
        lapCadence += data.cadence
        
        // Store time series (1 per second)
        let point = TimeSeriesPoint(
            timestamp: Date(),
            power: data.power,
            heartRate: data.heartRate,
            cadence: data.cadence,
            speed: data.speed
        )
        timeSeriesBuffer.append(point)
    }
    
    private func resetAccumulators() {
        totalPower = 0; maxPower = 0
        totalHR = 0; maxHR = 0
        totalCadence = 0; maxCadence = 0
        totalSpeed = 0; maxSpeed = 0
        sampleCount = 0; distance = 0
        ftmsBaseDistance = nil; usesFTMSDistance = false
        lapStartTime = Date()
        lapPower = 0; lapHR = 0; lapCadence = 0; lapSamples = 0
        timeSeriesBuffer.removeAll()
    }
    
    private func buildSession() -> RideSession {
        let session = RideSession(rideType: "indoor")
        session.endTime = Date()
        session.duration = elapsedTime
        session.distance = distance
        
        let count = max(Double(sampleCount), 1)
        session.avgPower = totalPower / count
        session.maxPower = maxPower
        session.avgHR = totalHR / count
        session.maxHR = maxHR
        session.avgCadence = totalCadence / count
        session.maxCadence = maxCadence
        session.avgSpeed = totalSpeed / count
        session.maxSpeed = maxSpeed
        // Use FTMS total energy if available, otherwise estimate
        let ftmsEnergy = BLEManager.shared.liveData.totalEnergy
        session.calories = ftmsEnergy > 0 ? ftmsEnergy : estimateCalories()
        
        // Generate report
        let report = MetricsAnalyzer.generateReport(for: session, timeSeries: timeSeriesBuffer)
        session.reportLine1 = report.line1
        session.reportLine2 = report.line2
        session.reportLine3 = report.line3
        session.recommendation = report.recommendation
        session.highlightText = report.highlight
        
        session.timeSeries = timeSeriesBuffer
        
        return session
    }
    
    private func estimateCalories() -> Double {
        // Rough estimate: ~1 kcal per watt per hour
        let avgP = sampleCount > 0 ? totalPower / Double(sampleCount) : 0
        let hours = elapsedTime / 3600.0
        return avgP * hours * 3.6 // simplified estimate
    }
    
    // MARK: - Computed Properties
    
    var avgPower: Double {
        sampleCount > 0 ? totalPower / Double(sampleCount) : 0
    }
    var avgHR: Double {
        sampleCount > 0 ? totalHR / Double(sampleCount) : 0
    }
    var avgCadence: Double {
        sampleCount > 0 ? totalCadence / Double(sampleCount) : 0
    }
    
    var distanceKm: Double {
        distance / 1000.0
    }
    
    var goalDistanceKm: Double {
        goalDistance / 1000.0
    }
    
    var goalProgress: Double {
        guard goalDistance > 0 else { return 0 }
        return min(distance / goalDistance, 1.0)
    }
    
    var hasGoal: Bool {
        goalDistance > 0
    }
    
    var formattedTime: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        let hours = minutes / 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes % 60, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
