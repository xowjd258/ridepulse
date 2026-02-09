import Foundation
import ActivityKit

// MARK: - Ride Activity Attributes
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

// MARK: - Live Activity Manager
@MainActor
class LiveActivityManager: ObservableObject {
    static let shared = LiveActivityManager()
    
    @Published var isActivityActive = false
    
    private var currentActivity: Activity<RideActivityAttributes>?
    
    func startActivity(power: Double, heartRate: Double, cadence: Double, speed: Double = 0, elapsedTime: TimeInterval, distance: Double, goalDistance: Double, state: RideState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        
        let metrics = AppState.shared.selectedDisplayMetrics.map(\.rawValue)
        
        let attributes = RideActivityAttributes(
            rideName: "라이딩",
            startTime: Date(),
            displayMetrics: metrics
        )
        
        let contentState = RideActivityAttributes.ContentState(
            power: power,
            heartRate: heartRate,
            cadence: cadence,
            speed: speed,
            elapsedTime: elapsedTime,
            distance: distance,
            goalDistance: goalDistance,
            connectionState: "connected",
            rideState: state.rawValue
        )
        
        let content = ActivityContent(state: contentState, staleDate: nil)
        
        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            isActivityActive = true
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }
    
    func updateActivity(power: Double, heartRate: Double, cadence: Double, speed: Double = 0, elapsedTime: TimeInterval, distance: Double, goalDistance: Double, state: RideState) {
        guard let activity = currentActivity else { return }
        
        let contentState = RideActivityAttributes.ContentState(
            power: power,
            heartRate: heartRate,
            cadence: cadence,
            speed: speed,
            elapsedTime: elapsedTime,
            distance: distance,
            goalDistance: goalDistance,
            connectionState: BLEManager.shared.connectionState == .connected ? "connected" : "disconnected",
            rideState: state.rawValue
        )
        
        let content = ActivityContent(state: contentState, staleDate: nil)
        
        Task {
            await activity.update(content)
        }
    }
    
    func endActivity() {
        guard let activity = currentActivity else { return }
        
        let finalState = RideActivityAttributes.ContentState(
            power: 0,
            heartRate: 0,
            cadence: 0,
            speed: 0,
            elapsedTime: 0,
            distance: 0,
            goalDistance: 0,
            connectionState: "disconnected",
            rideState: "ended"
        )
        
        let content = ActivityContent(state: finalState, staleDate: nil)
        
        Task {
            await activity.end(content, dismissalPolicy: .default)
            await MainActor.run {
                self.currentActivity = nil
                self.isActivityActive = false
            }
        }
    }
}
