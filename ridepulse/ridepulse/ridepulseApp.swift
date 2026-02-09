import SwiftUI
import SwiftData

@main
struct ridepulseApp: App {
    @StateObject private var appState = AppState.shared
    @StateObject private var bleManager = BLEManager.shared
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            SensorDevice.self,
            RideSession.self,
            TimeSeriesPoint.self,
            RideLap.self,
            UserGoal.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            Group {
                if appState.hasCompletedOnboarding {
                    ContentView()
                        .environmentObject(appState)
                } else {
                    OnboardingView()
                        .environmentObject(appState)
                }
            }
            .preferredColorScheme(.light)
            .onAppear {
                // Auto-connect saved sensors on launch
                autoConnectSensors()
            }
        }
        .modelContainer(sharedModelContainer)
    }
    
    private func autoConnectSensors() {
        // Attempt to reconnect saved sensors
        let context = sharedModelContainer.mainContext
        let descriptor = FetchDescriptor<SensorDevice>()
        if let sensors = try? context.fetch(descriptor) {
            for sensor in sensors {
                if let uuid = UUID(uuidString: sensor.peripheralUUID) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        bleManager.connectToSaved(uuid: uuid)
                    }
                }
            }
        }
    }
}
