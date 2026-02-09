import Foundation
import SwiftData

// MARK: - Sensor Device Model
@Model
final class SensorDevice {
    var id: UUID
    var name: String
    var peripheralUUID: String
    var sensorType: String // "power", "heartRate", "cadence", "speed", "ftms"
    var isPrimary: Bool
    var lastConnected: Date?
    var addedAt: Date
    
    init(name: String, peripheralUUID: String, sensorType: String, isPrimary: Bool = false) {
        self.id = UUID()
        self.name = name
        self.peripheralUUID = peripheralUUID
        self.sensorType = sensorType
        self.isPrimary = isPrimary
        self.addedAt = Date()
    }
}

// MARK: - Ride Session Model
@Model
final class RideSession {
    var id: UUID
    var startTime: Date
    var endTime: Date?
    var rideType: String // "outdoor", "indoor"
    var avgPower: Double
    var maxPower: Double
    var avgHR: Double
    var maxHR: Double
    var avgCadence: Double
    var maxCadence: Double
    var avgSpeed: Double
    var maxSpeed: Double
    var distance: Double // meters
    var duration: TimeInterval
    var calories: Double
    var dropoutCount: Int
    
    // 3-line report
    var reportLine1: String?
    var reportLine2: String?
    var reportLine3: String?
    var recommendation: String?
    var highlightText: String?
    
    @Relationship(deleteRule: .cascade)
    var timeSeries: [TimeSeriesPoint]?
    
    @Relationship(deleteRule: .cascade)
    var laps: [RideLap]?
    
    init(rideType: String = "indoor") {
        self.id = UUID()
        self.startTime = Date()
        self.rideType = rideType
        self.avgPower = 0
        self.maxPower = 0
        self.avgHR = 0
        self.maxHR = 0
        self.avgCadence = 0
        self.maxCadence = 0
        self.avgSpeed = 0
        self.maxSpeed = 0
        self.distance = 0
        self.duration = 0
        self.calories = 0
        self.dropoutCount = 0
    }
}

// MARK: - Time Series Point
@Model
final class TimeSeriesPoint {
    var timestamp: Date
    var power: Double
    var heartRate: Double
    var cadence: Double
    var speed: Double
    
    var session: RideSession?
    
    init(timestamp: Date = Date(), power: Double = 0, heartRate: Double = 0, cadence: Double = 0, speed: Double = 0) {
        self.timestamp = timestamp
        self.power = power
        self.heartRate = heartRate
        self.cadence = cadence
        self.speed = speed
    }
}

// MARK: - Ride Lap
@Model
final class RideLap {
    var id: UUID
    var lapNumber: Int
    var startTime: Date
    var endTime: Date?
    var avgPower: Double
    var avgHR: Double
    var avgCadence: Double
    var duration: TimeInterval
    
    var session: RideSession?
    
    init(lapNumber: Int, startTime: Date = Date()) {
        self.id = UUID()
        self.lapNumber = lapNumber
        self.startTime = startTime
        self.avgPower = 0
        self.avgHR = 0
        self.avgCadence = 0
        self.duration = 0
    }
}

// MARK: - User Goal
@Model
final class UserGoal {
    var id: UUID
    var weeklyRideCount: Int
    var weeklyMinutes: Int
    var targetZone: String // "Z2", "Z3", etc.
    var createdAt: Date
    
    init(weeklyRideCount: Int = 3, weeklyMinutes: Int = 90, targetZone: String = "Z2") {
        self.id = UUID()
        self.weeklyRideCount = weeklyRideCount
        self.weeklyMinutes = weeklyMinutes
        self.targetZone = targetZone
        self.createdAt = Date()
    }
}

// MARK: - Sensor Type Enum
enum SensorType: String, CaseIterable, Identifiable {
    case power = "power"
    case heartRate = "heartRate"
    case cadence = "cadence"
    case speed = "speed"
    case ftms = "ftms"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .power: return "파워미터"
        case .heartRate: return "심박계"
        case .cadence: return "케이던스"
        case .speed: return "속도"
        case .ftms: return "스마트 트레이너"
        }
    }
    
    var icon: String {
        switch self {
        case .power: return "bolt.fill"
        case .heartRate: return "heart.fill"
        case .cadence: return "arrow.triangle.2.circlepath"
        case .speed: return "speedometer"
        case .ftms: return "bicycle"
        }
    }
    
    var unit: String {
        switch self {
        case .power: return "W"
        case .heartRate: return "bpm"
        case .cadence: return "rpm"
        case .speed: return "km/h"
        case .ftms: return ""
        }
    }
    
    var serviceUUID: String {
        switch self {
        case .power: return "1818"
        case .heartRate: return "180D"
        case .cadence, .speed: return "1816"
        case .ftms: return "1826"
        }
    }
}

// MARK: - Display Metric
enum DisplayMetric: String, CaseIterable, Identifiable {
    case power, heartRate, cadence, speed, time
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .power: return "Power"
        case .heartRate: return "Heart Rate"
        case .cadence: return "Cadence"
        case .speed: return "Speed"
        case .time: return "Time"
        }
    }
    
    var unit: String {
        switch self {
        case .power: return "W"
        case .heartRate: return "bpm"
        case .cadence: return "rpm"
        case .speed: return "km/h"
        case .time: return ""
        }
    }
    
    var icon: String {
        switch self {
        case .power: return "bolt.fill"
        case .heartRate: return "heart.fill"
        case .cadence: return "arrow.triangle.2.circlepath"
        case .speed: return "speedometer"
        case .time: return "clock.fill"
        }
    }
}

// MARK: - Condition Level
enum ConditionLevel: String {
    case good = "좋음"
    case normal = "보통"
    case tired = "피곤"
    
    var color: String {
        switch self {
        case .good: return "green"
        case .normal: return "orange"
        case .tired: return "red"
        }
    }
}

// MARK: - Ride State
enum RideState: String {
    case idle
    case riding
    case paused
    case ended
}
