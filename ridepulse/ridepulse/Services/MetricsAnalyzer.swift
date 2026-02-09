import Foundation

struct RideReport {
    var line1: String
    var line2: String
    var line3: String
    var recommendation: String
    var highlight: String
}

// MARK: - Metrics Analyzer
class MetricsAnalyzer {
    
    static func generateReport(for session: RideSession, timeSeries: [TimeSeriesPoint], previousSessions: [RideSession] = []) -> RideReport {
        let avgPower = session.avgPower
        let avgHR = session.avgHR
        let avgCadence = session.avgCadence
        let duration = session.duration
        
        // Line 1: Power comparison
        var line1 = "평균 파워 \(Int(avgPower))W로 라이딩했어요"
        if let lastSession = previousSessions.last {
            let diff = Int(avgPower - lastSession.avgPower)
            if diff > 0 {
                line1 = "평균 파워가 지난번보다 +\(diff)W 높아요"
            } else if diff < 0 {
                line1 = "평균 파워가 지난번보다 \(diff)W 낮아요"
            } else {
                line1 = "평균 파워가 지난번과 동일해요"
            }
        }
        
        // Line 2: HR drift analysis
        let line2 = analyzeHRDrift(timeSeries: timeSeries, avgHR: avgHR)
        
        // Line 3: Cadence pattern
        let line3 = analyzeCadencePattern(timeSeries: timeSeries, avgCadence: avgCadence)
        
        // Recommendation
        let recommendation = generateRecommendation(
            avgPower: avgPower, avgHR: avgHR, duration: duration
        )
        
        // Highlight
        let highlight = generateHighlight(session: session, timeSeries: timeSeries)
        
        return RideReport(
            line1: line1, line2: line2, line3: line3,
            recommendation: recommendation, highlight: highlight
        )
    }
    
    // MARK: - HR Drift Analysis
    
    private static func analyzeHRDrift(timeSeries: [TimeSeriesPoint], avgHR: Double) -> String {
        // If no HR data was recorded, don't show misleading analysis
        guard avgHR > 0 else {
            return "심박 센서 데이터가 없어요"
        }
        
        guard timeSeries.count > 10 else {
            return "심박 데이터가 충분하지 않아요"
        }
        
        // Check if HR values actually exist in time series
        let hrValues = timeSeries.filter { $0.heartRate > 0 }
        guard hrValues.count > 10 else {
            return "심박 센서 데이터가 없어요"
        }
        
        let mid = hrValues.count / 2
        let firstHalf = hrValues[..<mid]
        let secondHalf = hrValues[mid...]
        
        let firstAvgHR = firstHalf.map(\.heartRate).reduce(0, +) / Double(firstHalf.count)
        let secondAvgHR = secondHalf.map(\.heartRate).reduce(0, +) / Double(secondHalf.count)
        
        let drift = secondAvgHR - firstAvgHR
        
        if drift < 5 {
            return "심박 드리프트가 낮아 지구력이 좋아요"
        } else if drift < 10 {
            return "후반에 심박이 소폭 올라갔어요 (정상 범위)"
        } else {
            return "심박 드리프트가 높아요 (피로 가능성)"
        }
    }
    
    // MARK: - Cadence Pattern
    
    private static func analyzeCadencePattern(timeSeries: [TimeSeriesPoint], avgCadence: Double) -> String {
        guard timeSeries.count > 10 else {
            return "케이던스 \(Int(avgCadence))rpm으로 유지했어요"
        }
        
        let lastQuarter = timeSeries.suffix(timeSeries.count / 4)
        let lastAvgCadence = lastQuarter.map(\.cadence).reduce(0, +) / Double(lastQuarter.count)
        
        let drop = avgCadence - lastAvgCadence
        
        if drop > 5 {
            return "후반 케이던스가 떨어져 근피로 가능성이 있어요"
        } else if drop < -5 {
            return "후반에 케이던스가 올라갔어요 (스프린트)"
        } else {
            return "케이던스가 일정하게 유지됐어요"
        }
    }
    
    // MARK: - Recommendation
    
    private static func generateRecommendation(avgPower: Double, avgHR: Double, duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        
        // If no HR data, give power/duration-based recommendations only
        guard avgHR > 0 else {
            if minutes > 45 {
                return "좋은 볼륨이에요. 다음은 회복 라이딩 40분이 좋아요"
            } else if minutes < 20 {
                return "짧게 타셨네요. 다음은 45분 이상 추천해요"
            }
            return "다음은 기본 라이딩 45분을 추천해요"
        }
        
        // High intensity + long -> recovery
        if avgHR > 160 && minutes > 30 {
            return "오늘은 강하게 탔어요. 다음은 회복 Z2 30분 추천"
        }
        
        // Low intensity -> push harder
        if avgHR < 130 && minutes < 30 {
            return "가볍게 타셨네요. 다음은 Z3 인터벌 40분 추천"
        }
        
        // Moderate
        if minutes > 45 {
            return "좋은 볼륨이에요. 다음은 회복 Z2 40분이 좋아요"
        }
        
        return "다음은 Z2 기본 라이딩 45분을 추천해요"
    }
    
    // MARK: - Highlight
    
    private static func generateHighlight(session: RideSession, timeSeries: [TimeSeriesPoint]) -> String {
        // Find best 30-second power
        if timeSeries.count >= 30 {
            var best30s: Double = 0
            for i in 0...(timeSeries.count - 30) {
                let window = timeSeries[i..<(i+30)]
                let avg = window.map(\.power).reduce(0, +) / 30.0
                best30s = max(best30s, avg)
            }
            if best30s > 0 {
                return "최고 30초 파워 \(Int(best30s))W"
            }
        }
        
        if session.maxPower > 0 {
            return "최대 파워 \(Int(session.maxPower))W"
        }
        
        let minutes = Int(session.duration / 60)
        return "\(minutes)분 라이딩 완료"
    }
    
    // MARK: - Condition Assessment
    
    static func assessCondition(recentSessions: [RideSession]) -> (level: ConditionLevel, message: String) {
        guard let last = recentSessions.last else {
            return (.normal, "아직 데이터가 없어요")
        }
        
        // If no HR data available, base assessment on ride frequency only
        let sessionsWithHR = recentSessions.suffix(3).filter { $0.avgHR > 0 }
        guard sessionsWithHR.count >= 2, last.avgHR > 0 else {
            // No HR data — give generic advice
            return (.normal, "심박 데이터 없이 컨디션을 판단하기 어려워요")
        }
        
        // Simple fatigue estimation based on recent HR and power
        let recentAvgHR = sessionsWithHR.map(\.avgHR).reduce(0, +) / Double(sessionsWithHR.count)
        
        if last.avgHR > recentAvgHR * 1.1 {
            return (.tired, "최근 심박이 높아요. 회복이 필요해요")
        } else if last.avgHR < recentAvgHR * 0.95 {
            return (.good, "컨디션이 좋아요! 오늘 강도를 올려보세요")
        }
        
        return (.normal, "보통 상태예요. 계획대로 라이딩하세요")
    }
    
    // MARK: - Weekly Summary
    
    static func weeklySummary(sessions: [RideSession]) -> (rideCount: Int, totalMinutes: Int, totalDistance: Double, totalCalories: Double) {
        let calendar = Calendar.current
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
        
        let thisWeek = sessions.filter { $0.startTime >= weekStart }
        let rideCount = thisWeek.count
        let totalMinutes = Int(thisWeek.map(\.duration).reduce(0, +) / 60)
        let totalDistance = thisWeek.map(\.distance).reduce(0, +) / 1000 // km
        let totalCalories = thisWeek.map(\.calories).reduce(0, +)
        
        return (rideCount, totalMinutes, totalDistance, totalCalories)
    }
    
    // MARK: - Anomaly Detection
    
    static func detectAnomalies(current: LiveSensorData, recentSessions: [RideSession]) -> [String] {
        var anomalies: [String] = []
        
        guard let last = recentSessions.last else { return anomalies }
        
        // HR anomaly
        if current.heartRate > last.avgHR * 1.15 && current.heartRate > 0 {
            let diff = Int(current.heartRate - last.avgHR)
            anomalies.append("평소 대비 심박이 \(diff)bpm 높아요 (피로 가능)")
        }
        
        // Power-cadence mismatch
        if current.power > last.avgPower * 0.9 && current.cadence < last.avgCadence * 0.8 && current.cadence > 0 {
            anomalies.append("파워는 유지되는데 케이던스가 떨어졌어요 (근피로)")
        }
        
        return anomalies
    }
}
