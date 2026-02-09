import Foundation
import HealthKit

// MARK: - HealthKit Cycling Workout (read from Health app)
struct HKCyclingWorkout: Identifiable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    let distance: Double       // meters
    let calories: Double       // kcal
    let avgHR: Double          // bpm
    let maxHR: Double          // bpm
    let avgPower: Double       // watts
    let avgCadence: Double     // rpm
    let avgSpeed: Double       // km/h
    let sourceName: String     // e.g. "Zwift", "Apple Watch", "RidePulse"
    let isFromRidePulse: Bool  // true if saved by this app
    let locationType: String   // "indoor" or "outdoor"
}

@MainActor
class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    
    private let healthStore = HKHealthStore()
    
    @Published var isAuthorized = false
    @Published var authorizationStatus: String = "확인 중..."
    @Published var hkCyclingWorkouts: [HKCyclingWorkout] = []
    @Published var hkWeeklySummary: (rideCount: Int, totalMinutes: Int, totalDistance: Double, totalCalories: Double) = (0, 0, 0, 0)
    
    private let bundleIdentifier = "simpletalk.ridepulse"
    
    // Types to write
    private let typesToWrite: Set<HKSampleType> = [
        HKObjectType.workoutType(),
        HKQuantityType(.heartRate),
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.distanceCycling),
        HKQuantityType(.cyclingCadence),
        HKQuantityType(.cyclingPower),
    ]
    
    // Types to read
    private let typesToRead: Set<HKObjectType> = [
        HKObjectType.workoutType(),
        HKQuantityType(.heartRate),
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.distanceCycling),
        HKQuantityType(.cyclingPower),
        HKQuantityType(.cyclingCadence),
    ]
    
    var isHealthKitAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }
    
    init() {
        checkAuthorizationStatus()
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async {
        guard isHealthKitAvailable else {
            authorizationStatus = "건강 앱 미지원"
            return
        }
        
        do {
            try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
            checkAuthorizationStatus()
        } catch {
            print("HealthKit authorization failed: \(error)")
            authorizationStatus = "권한 거부됨"
        }
    }
    
    func checkAuthorizationStatus() {
        guard isHealthKitAvailable else {
            authorizationStatus = "건강 앱 미지원"
            isAuthorized = false
            return
        }
        
        // Check workout type authorization as representative
        let status = healthStore.authorizationStatus(for: HKObjectType.workoutType())
        switch status {
        case .sharingAuthorized:
            isAuthorized = true
            authorizationStatus = "연동됨"
        case .sharingDenied:
            isAuthorized = false
            authorizationStatus = "거부됨"
        case .notDetermined:
            isAuthorized = false
            authorizationStatus = "설정 안됨"
        @unknown default:
            isAuthorized = false
            authorizationStatus = "알 수 없음"
        }
    }
    
    // MARK: - Save Workout
    
    func saveRide(
        startDate: Date,
        endDate: Date,
        duration: TimeInterval,
        distance: Double, // meters
        calories: Double,
        avgHR: Double,
        maxHR: Double,
        avgPower: Double,
        avgCadence: Double,
        timeSeries: [(timestamp: Date, hr: Double, power: Double, cadence: Double)]
    ) async {
        guard isAuthorized else { return }
        
        let workoutConfig = HKWorkoutConfiguration()
        workoutConfig.activityType = .cycling
        workoutConfig.locationType = .indoor
        
        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: workoutConfig, device: nil)
        
        do {
            try await builder.beginCollection(at: startDate)
            
            var samples: [HKSample] = []
            
            // Distance
            if distance > 0 {
                let distanceQuantity = HKQuantity(unit: .meter(), doubleValue: distance)
                let distanceSample = HKQuantitySample(
                    type: HKQuantityType(.distanceCycling),
                    quantity: distanceQuantity,
                    start: startDate,
                    end: endDate
                )
                samples.append(distanceSample)
            }
            
            // Calories
            if calories > 0 {
                let calorieQuantity = HKQuantity(unit: .kilocalorie(), doubleValue: calories)
                let calorieSample = HKQuantitySample(
                    type: HKQuantityType(.activeEnergyBurned),
                    quantity: calorieQuantity,
                    start: startDate,
                    end: endDate
                )
                samples.append(calorieSample)
            }
            
            // Heart rate samples (aggregate every 5 seconds to avoid too many samples)
            let hrSamples = buildHeartRateSamples(timeSeries: timeSeries)
            samples.append(contentsOf: hrSamples)
            
            // Power samples
            let powerSamples = buildPowerSamples(timeSeries: timeSeries)
            samples.append(contentsOf: powerSamples)
            
            // Cadence samples
            let cadenceSamples = buildCadenceSamples(timeSeries: timeSeries)
            samples.append(contentsOf: cadenceSamples)
            
            if !samples.isEmpty {
                try await builder.addSamples(samples)
            }
            
            try await builder.endCollection(at: endDate)
            
            if let workout = try await builder.finishWorkout() {
                print("HealthKit workout saved: \(workout)")
            }
            
        } catch {
            print("Failed to save workout to HealthKit: \(error)")
        }
    }
    
    // MARK: - Fetch Cycling Workouts from Health App
    
    func fetchCyclingWorkouts(limit: Int = 50) async {
        guard isAuthorized else { return }
        
        let workoutType = HKObjectType.workoutType()
        let cyclingPredicate = HKQuery.predicateForWorkouts(with: .cycling)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        let workouts: [HKWorkout] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: cyclingPredicate,
                limit: limit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    print("HealthKit fetch error: \(error)")
                    continuation.resume(returning: [])
                    return
                }
                let results = (samples as? [HKWorkout]) ?? []
                continuation.resume(returning: results)
            }
            healthStore.execute(query)
        }
        
        var cyclingList: [HKCyclingWorkout] = []
        
        for workout in workouts {
            let distance = workout.totalDistance?.doubleValue(for: .meter()) ?? 0
            let calories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0
            let duration = workout.duration
            
            // Source
            let sourceName = workout.sourceRevision.source.name
            let sourceBundleId = workout.sourceRevision.source.bundleIdentifier
            let isFromRidePulse = sourceBundleId == bundleIdentifier
            
            // Location type
            let locationType: String
            if let meta = workout.metadata,
               let indoor = meta[HKMetadataKeyIndoorWorkout] as? Bool {
                locationType = indoor ? "indoor" : "outdoor"
            } else {
                locationType = workout.workoutActivityType == .cycling ? "outdoor" : "indoor"
            }
            
            // Fetch statistics for this workout
            let avgHR = await fetchWorkoutStatistic(workout: workout, type: .heartRate, unit: HKUnit.count().unitDivided(by: .minute()), stat: .average)
            let maxHR = await fetchWorkoutStatistic(workout: workout, type: .heartRate, unit: HKUnit.count().unitDivided(by: .minute()), stat: .max)
            let avgPower = await fetchWorkoutStatistic(workout: workout, type: .cyclingPower, unit: .watt(), stat: .average)
            let avgCadence = await fetchWorkoutStatistic(workout: workout, type: .cyclingCadence, unit: HKUnit.count().unitDivided(by: .minute()), stat: .average)
            
            let avgSpeed = duration > 0 ? (distance / 1000) / (duration / 3600) : 0
            
            let entry = HKCyclingWorkout(
                id: workout.uuid,
                startDate: workout.startDate,
                endDate: workout.endDate,
                duration: duration,
                distance: distance,
                calories: calories,
                avgHR: avgHR,
                maxHR: maxHR,
                avgPower: avgPower,
                avgCadence: avgCadence,
                avgSpeed: avgSpeed,
                sourceName: sourceName,
                isFromRidePulse: isFromRidePulse,
                locationType: locationType
            )
            cyclingList.append(entry)
        }
        
        hkCyclingWorkouts = cyclingList
        computeWeeklySummary()
    }
    
    private enum StatType { case average, max }
    
    private func fetchWorkoutStatistic(workout: HKWorkout, type: HKQuantityTypeIdentifier, unit: HKUnit, stat: StatType) async -> Double {
        let quantityType = HKQuantityType(type)
        
        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: stat == .average ? .discreteAverage : .discreteMax
            ) { _, statistics, error in
                guard let statistics = statistics else {
                    continuation.resume(returning: 0)
                    return
                }
                let value: Double
                switch stat {
                case .average:
                    value = statistics.averageQuantity()?.doubleValue(for: unit) ?? 0
                case .max:
                    value = statistics.maximumQuantity()?.doubleValue(for: unit) ?? 0
                }
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }
    
    // MARK: - Weekly Summary (HealthKit only, excluding RidePulse to avoid double count)
    
    private func computeWeeklySummary() {
        let calendar = Calendar.current
        let now = Date()
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) else { return }
        
        let weekWorkouts = hkCyclingWorkouts.filter { $0.startDate >= weekStart && !$0.isFromRidePulse }
        
        let rideCount = weekWorkouts.count
        let totalMinutes = Int(weekWorkouts.reduce(0) { $0 + $1.duration } / 60)
        let totalDistance = weekWorkouts.reduce(0) { $0 + $1.distance } / 1000 // km
        let totalCalories = weekWorkouts.reduce(0) { $0 + $1.calories }
        
        hkWeeklySummary = (rideCount, totalMinutes, totalDistance, totalCalories)
    }
    
    // MARK: - Fetch Weekly Summary (quick, just cycling workouts this week)
    
    func fetchWeeklyCyclingSummary() async -> (rideCount: Int, totalMinutes: Int, totalDistanceKm: Double, totalCalories: Double) {
        guard isAuthorized else { return (0, 0, 0, 0) }
        
        let calendar = Calendar.current
        let now = Date()
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) else { return (0, 0, 0, 0) }
        
        let workoutType = HKObjectType.workoutType()
        let cyclingPredicate = HKQuery.predicateForWorkouts(with: .cycling)
        let datePredicate = HKQuery.predicateForSamples(withStart: weekStart, end: now, options: .strictStartDate)
        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [cyclingPredicate, datePredicate])
        
        let workouts: [HKWorkout] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: compoundPredicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                let results = (samples as? [HKWorkout]) ?? []
                continuation.resume(returning: results)
            }
            healthStore.execute(query)
        }
        
        // Exclude RidePulse workouts (already counted from SwiftData)
        let externalWorkouts = workouts.filter { $0.sourceRevision.source.bundleIdentifier != bundleIdentifier }
        
        let rideCount = externalWorkouts.count
        let totalMinutes = Int(externalWorkouts.reduce(0) { $0 + $1.duration } / 60)
        let totalDistanceKm = externalWorkouts.reduce(0) { $0 + ($1.totalDistance?.doubleValue(for: .meter()) ?? 0) } / 1000
        let totalCalories = externalWorkouts.reduce(0) { $0 + ($1.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0) }
        
        return (rideCount, totalMinutes, totalDistanceKm, totalCalories)
    }
    
    // MARK: - Build Samples
    
    private func buildHeartRateSamples(timeSeries: [(timestamp: Date, hr: Double, power: Double, cadence: Double)]) -> [HKQuantitySample] {
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        var samples: [HKQuantitySample] = []
        
        // Group into 5-second intervals
        let interval = 5
        var i = 0
        while i < timeSeries.count {
            let end = min(i + interval, timeSeries.count)
            let slice = timeSeries[i..<end]
            let avgHR = slice.map(\.hr).reduce(0, +) / Double(slice.count)
            
            if avgHR > 30 && avgHR < 250 {
                let quantity = HKQuantity(unit: bpmUnit, doubleValue: avgHR)
                let sample = HKQuantitySample(
                    type: HKQuantityType(.heartRate),
                    quantity: quantity,
                    start: slice.first!.timestamp,
                    end: slice.last!.timestamp.addingTimeInterval(1)
                )
                samples.append(sample)
            }
            i = end
        }
        
        return samples
    }
    
    private func buildPowerSamples(timeSeries: [(timestamp: Date, hr: Double, power: Double, cadence: Double)]) -> [HKQuantitySample] {
        let wattUnit = HKUnit.watt()
        var samples: [HKQuantitySample] = []
        
        let interval = 5
        var i = 0
        while i < timeSeries.count {
            let end = min(i + interval, timeSeries.count)
            let slice = timeSeries[i..<end]
            let avgPower = slice.map(\.power).reduce(0, +) / Double(slice.count)
            
            if avgPower > 0 {
                let quantity = HKQuantity(unit: wattUnit, doubleValue: avgPower)
                let sample = HKQuantitySample(
                    type: HKQuantityType(.cyclingPower),
                    quantity: quantity,
                    start: slice.first!.timestamp,
                    end: slice.last!.timestamp.addingTimeInterval(1)
                )
                samples.append(sample)
            }
            i = end
        }
        
        return samples
    }
    
    private func buildCadenceSamples(timeSeries: [(timestamp: Date, hr: Double, power: Double, cadence: Double)]) -> [HKQuantitySample] {
        let rpmUnit = HKUnit.count().unitDivided(by: .minute())
        var samples: [HKQuantitySample] = []
        
        let interval = 5
        var i = 0
        while i < timeSeries.count {
            let end = min(i + interval, timeSeries.count)
            let slice = timeSeries[i..<end]
            let avgCadence = slice.map(\.cadence).reduce(0, +) / Double(slice.count)
            
            if avgCadence > 0 {
                let quantity = HKQuantity(unit: rpmUnit, doubleValue: avgCadence)
                let sample = HKQuantitySample(
                    type: HKQuantityType(.cyclingCadence),
                    quantity: quantity,
                    start: slice.first!.timestamp,
                    end: slice.last!.timestamp.addingTimeInterval(1)
                )
                samples.append(sample)
            }
            i = end
        }
        
        return samples
    }
}
