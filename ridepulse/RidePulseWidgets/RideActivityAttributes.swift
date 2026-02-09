import Foundation
import ActivityKit

// Shared definition - must match the one in the main app
struct RideActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var power: Double
        var heartRate: Double
        var cadence: Double
        var speed: Double
        var elapsedTime: TimeInterval
        var distance: Double // meters
        var goalDistance: Double // meters, 0 = no goal
        var connectionState: String // "connected", "disconnected"
        var rideState: String // "riding", "paused"
        
        var distanceKm: Double { distance / 1000.0 }
        var goalDistanceKm: Double { goalDistance / 1000.0 }
        var progress: Double {
            guard goalDistance > 0 else { return 0 }
            return min(distance / goalDistance, 1.0)
        }
        var hasGoal: Bool { goalDistance > 0 }
    }
    
    var rideName: String
    var startTime: Date
    var displayMetrics: [String] // DisplayMetric raw values: "power", "heartRate", "cadence", "speed", "time"
}
