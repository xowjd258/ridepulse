# RidePulse

BLE 사이클링 센서(FTMS 스마트 트레이너, 파워미터, 심박계, 케이던스)와 연결해 실시간 데이터를 수집하고, 토스 스타일 카드 UI로 보여주는 iOS 실내 사이클링 앱.

## 주요 기능

### 실시간 센서 연결
- FTMS Indoor Bike Data 전체 파싱 (파워, 심박, 케이던스, 속도, 거리, 칼로리, 저항 등 13개 필드)
- Training Status, Device Information, Supported Ranges 읽기
- 백그라운드 BLE 수집 유지

### Dynamic Island / 잠금화면
- Live Activity로 라이딩 중 핵심 지표 표시
- 사용자가 선택한 지표 최대 3개 (Power / HR / Cadence / Speed / Time)
- 목표 거리 진행률 바

### 라이딩 세션
- 목표 거리 설정 후 실시간 진행률 추적
- 1초 단위 시계열 데이터 기록
- 랩(구간) 분리, 일시정지/재개
- FTMS Total Distance / Total Energy 직접 사용 (정확한 거리/칼로리)

### 3줄 AI 리포트
- 라이딩 종료 시 자동 생성
- 심박 드리프트, 케이던스 패턴, 컨디션 분석
- 다음 라이딩 추천

### 건강 앱(HealthKit) 연동
- 라이딩 종료 시 사이클링 운동으로 자동 저장 (거리, 칼로리, 심박, 파워, 케이던스)
- 건강 앱의 외부 사이클링 기록 읽어오기 (Zwift, Apple Watch 등)
- 주간 요약에 외부 기록 합산 표시 (중복 방지)

### 토스 스타일 UI
- 카드형 홈 피드 (오늘의 라이딩, 주간 누적, 컨디션, 추천, 센서 상태)
- 강제 라이트 모드
- 한국어 인터페이스

## 기술 스택

| 항목 | 기술 |
|------|------|
| 언어 | Swift 5 |
| UI | SwiftUI |
| 데이터 | SwiftData |
| BLE | CoreBluetooth |
| Live Activity | ActivityKit + WidgetKit |
| 건강 | HealthKit |
| 최소 지원 | iOS 17.0 |
| 외부 의존성 | 없음 |

## 프로젝트 구조

```
ridepulse/
├── ridepulse.xcodeproj
├── ridepulse/                     # 메인 앱
│   ├── ridepulseApp.swift         # @main 엔트리
│   ├── ContentView.swift          # 커스텀 탭 바
│   ├── DesignSystem/
│   │   └── TossDesignSystem.swift # 색상, 폰트, 카드, 버튼 스타일
│   ├── Models/
│   │   └── RideModels.swift       # SwiftData 모델
│   ├── Services/
│   │   ├── BLEManager.swift       # BLE 스캔/연결/파싱
│   │   ├── RideSessionManager.swift # 세션 상태 머신
│   │   ├── HealthKitManager.swift # HealthKit 읽기/쓰기
│   │   ├── LiveActivityManager.swift # Live Activity 관리
│   │   ├── MetricsAnalyzer.swift  # 리포트/분석
│   │   └── AppState.swift         # 전역 상태
│   └── Views/
│       ├── Home/HomeView.swift
│       ├── Riding/RidingView.swift
│       ├── Report/ReportView.swift
│       ├── Settings/SettingsView.swift
│       ├── Onboarding/OnboardingView.swift
│       ├── SensorPairing/SensorPairingView.swift
│       └── Components/TossCardView.swift
├── RidePulseWidgets/              # Widget Extension
│   ├── RidePulseLiveActivity.swift
│   ├── RideActivityAttributes.swift
│   └── RidePulseWidgetsBundle.swift
└── RidePulseWidgetsInfo.plist
```

## 빌드 & 실행

```bash
# Xcode 16.2+, iOS 17.0+ 실제 기기 필요 (BLE 시뮬레이터 미지원)
xcodebuild -project ridepulse/ridepulse.xcodeproj \
  -scheme ridepulse \
  -destination 'generic/platform=iOS' \
  -configuration Debug build
```

## 지원 센서

- **FTMS (0x1826)** - 스마트 트레이너 (Indoor Bike Data, Training Status, Machine Status)
- **Cycling Power (0x1818)** - 파워미터
- **Cycling Speed and Cadence (0x1816)** - 속도/케이던스 센서
- **Heart Rate (0x180D)** - 심박계
- **Device Information (0x180A)** - 제조사, 모델, 시리얼, HW/FW/SW 버전

## 라이선스

Private repository.
