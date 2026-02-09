import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentPage = 0
    @State private var showPermissions = false
    
    var body: some View {
        ZStack {
            Color.tossBg.ignoresSafeArea()
            
            if showPermissions {
                PermissionView(onComplete: {
                    withAnimation(.spring(response: 0.5)) {
                        appState.hasCompletedOnboarding = true
                    }
                })
                .transition(.move(edge: .trailing))
            } else {
                VStack(spacing: 0) {
                    Spacer()
                    
                    // Page content
                    TabView(selection: $currentPage) {
                        OnboardingPage(
                            icon: "applewatch.radiowaves.left.and.right",
                            title: "라이딩 중 화면 안 봐도 OK",
                            subtitle: "Dynamic Island에서\n파워 / 심박 / 케이던스 확인",
                            color: .tossPrimary
                        )
                        .tag(0)
                        
                        OnboardingPage(
                            icon: "doc.text.magnifyingglass",
                            title: "끝나면 3줄 리포트",
                            subtitle: "오늘의 결론 +\n다음 추천 라이딩 1개",
                            color: .tossGreen
                        )
                        .tag(1)
                        
                        OnboardingPage(
                            icon: "antenna.radiowaves.left.and.right",
                            title: "센서 자동 연결 / 수집",
                            subtitle: "끊기면 자동 재연결\n화면 꺼져도 계속 수집",
                            color: .tossOrange
                        )
                        .tag(2)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: 360)
                    
                    // Page indicator
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(currentPage == index ? Color.tossPrimary : Color.tossTextTertiary.opacity(0.3))
                                .frame(width: 8, height: 8)
                                .animation(.easeInOut(duration: 0.2), value: currentPage)
                        }
                    }
                    .padding(.top, 20)
                    
                    Spacer()
                    
                    // CTA Button
                    VStack(spacing: 12) {
                        Button(action: {
                            if currentPage < 2 {
                                withAnimation {
                                    currentPage += 1
                                }
                            } else {
                                withAnimation(.spring(response: 0.5)) {
                                    showPermissions = true
                                }
                            }
                        }) {
                            Text(currentPage == 2 ? "센서 등록하기" : "다음")
                        }
                        .buttonStyle(TossPrimaryButtonStyle())
                        
                        if currentPage < 2 {
                            Button("건너뛰기") {
                                withAnimation(.spring(response: 0.5)) {
                                    showPermissions = true
                                }
                            }
                            .font(.tossBody())
                            .foregroundColor(.tossTextSecondary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
    }
}

// MARK: - Onboarding Page
struct OnboardingPage: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: icon)
                    .font(.system(size: 48))
                    .foregroundColor(color)
            }
            
            VStack(spacing: 12) {
                Text(title)
                    .font(.tossTitle())
                    .foregroundColor(.tossTextPrimary)
                
                Text(subtitle)
                    .font(.tossBody())
                    .foregroundColor(.tossTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - Permission View
struct PermissionView: View {
    let onComplete: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 32) {
                Text("필요한 권한")
                    .font(.tossTitle())
                    .foregroundColor(.tossTextPrimary)
                
                VStack(spacing: 16) {
                    PermissionRow(
                        icon: "antenna.radiowaves.left.and.right",
                        title: "Bluetooth",
                        subtitle: "센서 데이터를 받기 위해 필요",
                        isRequired: true
                    )
                    
                    PermissionRow(
                        icon: "iphone.radiowaves.left.and.right",
                        title: "Live Activities",
                        subtitle: "잠금화면/다이나믹 아일랜드 표시",
                        isRequired: true
                    )
                    
                    PermissionRow(
                        icon: "heart.text.square.fill",
                        title: "건강",
                        subtitle: "라이딩 기록을 건강 앱에 저장",
                        isRequired: false
                    )
                    
                    PermissionRow(
                        icon: "bell.fill",
                        title: "알림 (선택)",
                        subtitle: "끊김/배터리 경고",
                        isRequired: false
                    )
                }
            }
            
            Spacer()
            
            Button(action: {
                Task {
                    await HealthKitManager.shared.requestAuthorization()
                    onComplete()
                }
            }) {
                Text("허용하고 계속")
            }
            .buttonStyle(TossPrimaryButtonStyle())
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let isRequired: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.tossPrimary.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.tossPrimary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.tossHeadline())
                        .foregroundColor(.tossTextPrimary)
                    if isRequired {
                        Text("필수")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.tossRed)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.tossRed.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                Text(subtitle)
                    .font(.tossCaption())
                    .foregroundColor(.tossTextSecondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}
