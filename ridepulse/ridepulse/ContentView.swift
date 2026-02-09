import SwiftUI
import SwiftData

// MARK: - Main Content View (Tab Navigation)
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var sessionManager = RideSessionManager.shared
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab content
            Group {
                switch appState.selectedTab {
                case .home:
                    HomeView()
                case .riding:
                    RidingView()
                case .report:
                    ReportView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Custom tab bar (토스 스타일)
            if sessionManager.state != .riding {
                customTabBar
            }
        }
        .sheet(isPresented: $appState.showRideSummary) {
            if let session = appState.lastCompletedSession {
                RideSummaryView(session: session)
            }
        }
    }
    
    // MARK: - Custom Tab Bar
    private var customTabBar: some View {
        HStack {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        appState.selectedTab = tab
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20))
                            .foregroundColor(
                                appState.selectedTab == tab ? .tossPrimary : .tossTextTertiary
                            )
                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(
                                appState.selectedTab == tab ? .tossPrimary : .tossTextTertiary
                            )
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 2)
        .padding(.horizontal, 4)
        .background(
            Color.tossCardBg
                .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: -4)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}
