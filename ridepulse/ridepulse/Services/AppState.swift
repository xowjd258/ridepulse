import Foundation
import SwiftUI

// MARK: - App State Manager
@MainActor
class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }
    @Published var hasRegisteredSensor: Bool {
        didSet { UserDefaults.standard.set(hasRegisteredSensor, forKey: "hasRegisteredSensor") }
    }
    @Published var selectedDisplayMetrics: [DisplayMetric] {
        didSet {
            let rawValues = selectedDisplayMetrics.map(\.rawValue)
            UserDefaults.standard.set(rawValues, forKey: "selectedDisplayMetrics")
        }
    }
    @Published var selectedTab: AppTab = .home
    @Published var showRideSummary: Bool = false
    @Published var lastCompletedSession: RideSession?
    
    init() {
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        self.hasRegisteredSensor = UserDefaults.standard.bool(forKey: "hasRegisteredSensor")
        
        if let saved = UserDefaults.standard.array(forKey: "selectedDisplayMetrics") as? [String] {
            self.selectedDisplayMetrics = saved.compactMap { DisplayMetric(rawValue: $0) }
        } else {
            self.selectedDisplayMetrics = [.power, .heartRate, .cadence]
        }
    }
}

// MARK: - App Tab
enum AppTab: String, CaseIterable {
    case home = "홈"
    case riding = "라이딩"
    case report = "리포트"
    case settings = "설정"
    
    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .riding: return "bicycle"
        case .report: return "chart.bar.fill"
        case .settings: return "gearshape.fill"
        }
    }
}
