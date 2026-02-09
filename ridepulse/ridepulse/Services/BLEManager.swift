import Foundation
import CoreBluetooth
import Combine

// MARK: - Discovered Device
struct DiscoveredDevice: Identifiable, Equatable {
    let id: UUID
    let peripheral: CBPeripheral
    let name: String
    let rssi: Int
    var supportedSensors: [SensorType]
    var lastSeen: Date
    
    static func == (lhs: DiscoveredDevice, rhs: DiscoveredDevice) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Connection State
enum BLEConnectionState: String {
    case disconnected
    case connecting
    case connected
    case disconnecting
    
    var dotColor: String {
        switch self {
        case .connected: return "green"
        case .connecting: return "orange"
        case .disconnected, .disconnecting: return "red"
        }
    }
    
    var label: String {
        switch self {
        case .connected: return "연결됨"
        case .connecting: return "연결 중..."
        case .disconnected: return "연결 안됨"
        case .disconnecting: return "연결 해제 중..."
        }
    }
}

// MARK: - Live Sensor Data
struct LiveSensorData {
    var power: Double = 0
    var heartRate: Double = 0
    var cadence: Double = 0
    var speed: Double = 0
    var totalDistance: Double? = nil // meters, from FTMS Total Distance field
    var avgSpeed: Double = 0
    var avgCadence: Double = 0
    var avgPower: Double = 0
    var resistanceLevel: Double = 0
    var totalEnergy: Double = 0 // kcal
    var energyPerHour: Double = 0 // kcal/h
    var energyPerMinute: Double = 0 // kcal/min
    var ftmsElapsedTime: Double = 0 // seconds
    var timestamp: Date = Date()
}

// MARK: - Training Status
enum FTMSTrainingStatus: String {
    case idle = "대기"
    case warmingUp = "워밍업"
    case lowIntensity = "저강도"
    case highIntensity = "고강도"
    case recovery = "회복"
    case isometric = "등척성"
    case heartRateControl = "심박 제어"
    case fitnessTest = "체력 테스트"
    case quickStart = "빠른 시작"
    case manualMode = "수동"
    case coolDown = "쿨다운"
    case preWorkout = "준비"
    case postWorkout = "종료"
    case unknown = "알 수 없음"
}

// MARK: - Device Info
struct BLEDeviceInfo {
    var manufacturer: String?
    var modelNumber: String?
    var serialNumber: String?
    var hardwareRevision: String?
    var firmwareRevision: String?
    var softwareRevision: String?
}

// MARK: - Supported Ranges
struct FTMSSupportedRanges {
    var powerMin: Double?
    var powerMax: Double?
    var speedMin: Double?
    var speedMax: Double?
    var resistanceMin: Double?
    var resistanceMax: Double?
    var heartRateMin: Double?
    var heartRateMax: Double?
}

// MARK: - BLE Manager
class BLEManager: NSObject, ObservableObject {
    static let shared = BLEManager()
    
    // Published state
    @Published var isBluetoothReady = false
    @Published var isScanning = false
    @Published var discoveredDevices: [DiscoveredDevice] = []
    @Published var connectionState: BLEConnectionState = .disconnected
    @Published var connectedPeripherals: [CBPeripheral] = []
    @Published var liveData = LiveSensorData()
    @Published var verificationData: LiveSensorData?
    @Published var trainingStatus: FTMSTrainingStatus = .idle
    @Published var deviceInfo = BLEDeviceInfo()
    @Published var supportedRanges = FTMSSupportedRanges()
    
    // CoreBluetooth
    private var centralManager: CBCentralManager!
    private var pendingPeripheral: CBPeripheral?
    private var connectedPeripheralSet: Set<CBPeripheral> = []
    
    // Service UUIDs to scan for
    private let targetServiceUUIDs: [CBUUID] = [
        CBUUID(string: "1818"), // Cycling Power Service
        CBUUID(string: "180D"), // Heart Rate Service
        CBUUID(string: "1816"), // Cycling Speed and Cadence
        CBUUID(string: "1826"), // FTMS
    ]
    
    // Characteristic UUIDs — Notify
    private let powerMeasurementUUID = CBUUID(string: "2A63")
    private let heartRateMeasurementUUID = CBUUID(string: "2A37")
    private let cscMeasurementUUID = CBUUID(string: "2A5B")
    private let indoorBikeDataUUID = CBUUID(string: "2AD2")
    private let trainingStatusUUID = CBUUID(string: "2AD3")
    private let machineStatusUUID = CBUUID(string: "2ADA")
    
    // Characteristic UUIDs — Read-only (Device Info)
    private let manufacturerNameUUID = CBUUID(string: "2A29")
    private let modelNumberUUID = CBUUID(string: "2A24")
    private let serialNumberUUID = CBUUID(string: "2A25")
    private let hardwareRevisionUUID = CBUUID(string: "2A27")
    private let firmwareRevisionUUID = CBUUID(string: "2A26")
    private let softwareRevisionUUID = CBUUID(string: "2A28")
    
    // Characteristic UUIDs — Read-only (FTMS Ranges)
    private let supportedPowerRangeUUID = CBUUID(string: "2AD8")
    private let supportedSpeedRangeUUID = CBUUID(string: "2AD4")
    private let supportedResistanceRangeUUID = CBUUID(string: "2AD6")
    private let supportedHeartRateRangeUUID = CBUUID(string: "2AD7")
    
    // Known characteristic UUIDs to subscribe (notify)
    private var knownNotifyUUIDs: Set<CBUUID> {
        [powerMeasurementUUID, heartRateMeasurementUUID, cscMeasurementUUID, indoorBikeDataUUID, trainingStatusUUID, machineStatusUUID]
    }
    
    // Characteristics to read once
    private var readOnceUUIDs: Set<CBUUID> {
        [manufacturerNameUUID, modelNumberUUID, serialNumberUUID, hardwareRevisionUUID, firmwareRevisionUUID, softwareRevisionUUID, supportedPowerRangeUUID, supportedSpeedRangeUUID, supportedResistanceRangeUUID, supportedHeartRateRangeUUID]
    }
    
    // CSC state for cadence calculation
    private var lastCrankRevolutions: UInt16 = 0
    private var lastCrankEventTime: UInt16 = 0
    private var hasPreviousCrankData = false
    
    // Reconnection
    private var autoReconnect = true
    private var reconnectTimer: Timer?
    private var savedPeripheralUUIDs: [UUID] = []
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main, options: nil)
    }
    
    // MARK: - Public API
    
    func startScan() {
        guard isBluetoothReady else { return }
        discoveredDevices.removeAll()
        isScanning = true
        centralManager.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
        
        // Auto-stop scan after 30 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            self?.stopScan()
        }
    }
    
    func stopScan() {
        centralManager.stopScan()
        isScanning = false
    }
    
    func connect(to device: DiscoveredDevice) {
        stopScan()
        connectionState = .connecting
        pendingPeripheral = device.peripheral
        centralManager.connect(device.peripheral, options: nil)
    }
    
    func connectToSaved(uuid: UUID) {
        let peripherals = centralManager.retrievePeripherals(withIdentifiers: [uuid])
        if let peripheral = peripherals.first {
            connectionState = .connecting
            pendingPeripheral = peripheral
            centralManager.connect(peripheral, options: nil)
        }
    }
    
    func disconnect(peripheral: CBPeripheral) {
        connectionState = .disconnecting
        centralManager.cancelPeripheralConnection(peripheral)
    }
    
    func disconnectAll() {
        for peripheral in connectedPeripheralSet {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        connectedPeripheralSet.removeAll()
        connectedPeripherals.removeAll()
        connectionState = .disconnected
    }
    
    private func attemptReconnect(peripheral: CBPeripheral) {
        guard autoReconnect else { return }
        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            if self.connectionState == .disconnected {
                self.connectionState = .connecting
                self.centralManager.connect(peripheral, options: nil)
            } else {
                timer.invalidate()
            }
        }
    }
    
    // MARK: - Sensor Parsing
    
    private func parsePowerMeasurement(_ data: Data) {
        guard data.count >= 4 else { return }
        let flags = UInt16(data[0]) | (UInt16(data[1]) << 8)
        let power = Int16(data[2]) | (Int16(data[3]) << 8)
        DispatchQueue.main.async {
            self.liveData.power = Double(max(0, power))
            self.liveData.timestamp = Date()
        }
    }
    
    private func parseHeartRateMeasurement(_ data: Data) {
        guard data.count >= 2 else { return }
        let flags = data[0]
        let is16Bit = (flags & 0x01) != 0
        let hr: UInt16
        if is16Bit && data.count >= 3 {
            hr = UInt16(data[1]) | (UInt16(data[2]) << 8)
        } else {
            hr = UInt16(data[1])
        }
        DispatchQueue.main.async {
            self.liveData.heartRate = Double(hr)
            self.liveData.timestamp = Date()
        }
    }
    
    private func parseCSCMeasurement(_ data: Data) {
        guard data.count >= 1 else { return }
        let flags = data[0]
        var offset = 1
        
        // Bit 0: Wheel Revolution Data present (cumulative revolutions uint32 + last event time uint16 = 6 bytes)
        if (flags & 0x01) != 0 {
            offset += 6 // skip wheel data
        }
        
        // Bit 1: Crank Revolution Data present
        if (flags & 0x02) != 0 {
            if offset + 4 <= data.count {
                let crankRevolutions = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
                let crankEventTime = UInt16(data[offset + 2]) | (UInt16(data[offset + 3]) << 8)
                
                if hasPreviousCrankData {
                    let revDiff = crankRevolutions &- lastCrankRevolutions // wrapping subtraction
                    var timeDiff = crankEventTime &- lastCrankEventTime
                    
                    if timeDiff > 0 && revDiff > 0 && revDiff < 10 { // sanity check
                        // Time is in 1/1024 seconds
                        let timeSeconds = Double(timeDiff) / 1024.0
                        let cadence = (Double(revDiff) / timeSeconds) * 60.0
                        
                        if cadence > 0 && cadence < 250 { // reasonable cadence range
                            DispatchQueue.main.async {
                                self.liveData.cadence = cadence
                                self.liveData.timestamp = Date()
                            }
                        }
                    } else if revDiff == 0 {
                        // No pedaling
                        DispatchQueue.main.async {
                            self.liveData.cadence = 0
                        }
                    }
                }
                
                lastCrankRevolutions = crankRevolutions
                lastCrankEventTime = crankEventTime
                hasPreviousCrankData = true
            }
        }
    }
    
    private func parseIndoorBikeData(_ data: Data) {
        // FTMS Indoor Bike Data characteristic (0x2AD2)
        // Reference: FTMS spec, Section 4.9
        guard data.count >= 2 else { return }
        let flags = UInt16(data[0]) | (UInt16(data[1]) << 8)
        var offset = 2
        
        var newSpeed: Double?
        var newCadence: Double?
        var newPower: Double?
        var newHeartRate: Double?
        var newTotalDistance: Double?
        var newAvgSpeed: Double?
        var newAvgCadence: Double?
        var newAvgPower: Double?
        var newResistance: Double?
        var newTotalEnergy: Double?
        var newEnergyPerHour: Double?
        var newEnergyPerMinute: Double?
        var newElapsedTime: Double?
        
        // Bit 0: More Data - if 0, Instantaneous Speed is present (note: inverted logic!)
        if (flags & 0x0001) == 0 {
            if offset + 2 <= data.count {
                let rawSpeed = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
                newSpeed = Double(rawSpeed) * 0.01 // 0.01 km/h resolution
                offset += 2
            }
        }
        
        // Bit 1: Average Speed present
        if (flags & 0x0002) != 0 {
            if offset + 2 <= data.count {
                let raw = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
                newAvgSpeed = Double(raw) * 0.01
            }
            offset += 2
        }
        
        // Bit 2: Instantaneous Cadence present
        if (flags & 0x0004) != 0 {
            if offset + 2 <= data.count {
                let rawCadence = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
                newCadence = Double(rawCadence) * 0.5 // 0.5 rpm resolution
                offset += 2
            }
        }
        
        // Bit 3: Average Cadence present
        if (flags & 0x0008) != 0 {
            if offset + 2 <= data.count {
                let raw = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
                newAvgCadence = Double(raw) * 0.5
            }
            offset += 2
        }
        
        // Bit 4: Total Distance present (3 bytes, uint24, in meters)
        if (flags & 0x0010) != 0 {
            if offset + 3 <= data.count {
                let d = UInt32(data[offset]) | (UInt32(data[offset + 1]) << 8) | (UInt32(data[offset + 2]) << 16)
                newTotalDistance = Double(d) // meters
            }
            offset += 3
        }
        
        // Bit 5: Resistance Level present (sint16)
        if (flags & 0x0020) != 0 {
            if offset + 2 <= data.count {
                let raw = Int16(bitPattern: UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8))
                newResistance = Double(raw)
            }
            offset += 2
        }
        
        // Bit 6: Instantaneous Power present (sint16)
        if (flags & 0x0040) != 0 {
            if offset + 2 <= data.count {
                let rawPower = Int16(bitPattern: UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8))
                newPower = Double(max(0, rawPower))
                offset += 2
            }
        }
        
        // Bit 7: Average Power present (sint16)
        if (flags & 0x0080) != 0 {
            if offset + 2 <= data.count {
                let raw = Int16(bitPattern: UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8))
                newAvgPower = Double(max(0, raw))
            }
            offset += 2
        }
        
        // Bit 8: Expended Energy present (Total uint16 + Per Hour uint16 + Per Minute uint8 = 5 bytes)
        if (flags & 0x0100) != 0 {
            if offset + 5 <= data.count {
                let totalE = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
                let perHour = UInt16(data[offset + 2]) | (UInt16(data[offset + 3]) << 8)
                let perMin = data[offset + 4]
                if totalE != 0xFFFF { newTotalEnergy = Double(totalE) }
                if perHour != 0xFFFF { newEnergyPerHour = Double(perHour) }
                newEnergyPerMinute = Double(perMin)
            }
            offset += 5
        }
        
        // Bit 9: Heart Rate present (uint8)
        if (flags & 0x0200) != 0 {
            if offset + 1 <= data.count {
                let hr = data[offset]
                if hr > 0 && hr < 250 {
                    newHeartRate = Double(hr)
                }
                offset += 1
            }
        }
        
        // Bit 10: Metabolic Equivalent (uint8, 0.1 resolution)
        if (flags & 0x0400) != 0 {
            offset += 1
        }
        
        // Bit 11: Elapsed Time present (uint16, seconds)
        if (flags & 0x0800) != 0 {
            if offset + 2 <= data.count {
                let raw = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
                newElapsedTime = Double(raw)
            }
            offset += 2
        }
        
        // Bit 12: Remaining Time present (uint16, seconds)
        if (flags & 0x1000) != 0 {
            offset += 2
        }
        
        // Apply all values in a single UI update to avoid flickering
        DispatchQueue.main.async {
            if let speed = newSpeed { self.liveData.speed = speed }
            if let cadence = newCadence { self.liveData.cadence = cadence }
            if let power = newPower { self.liveData.power = power }
            if let heartRate = newHeartRate { self.liveData.heartRate = heartRate }
            if let totalDist = newTotalDistance { self.liveData.totalDistance = totalDist }
            if let v = newAvgSpeed { self.liveData.avgSpeed = v }
            if let v = newAvgCadence { self.liveData.avgCadence = v }
            if let v = newAvgPower { self.liveData.avgPower = v }
            if let v = newResistance { self.liveData.resistanceLevel = v }
            if let v = newTotalEnergy { self.liveData.totalEnergy = v }
            if let v = newEnergyPerHour { self.liveData.energyPerHour = v }
            if let v = newEnergyPerMinute { self.liveData.energyPerMinute = v }
            if let v = newElapsedTime { self.liveData.ftmsElapsedTime = v }
            self.liveData.timestamp = Date()
        }
    }
    
    // MARK: - Training Status Parsing
    
    private func parseTrainingStatus(_ data: Data) {
        guard data.count >= 2 else { return }
        let statusByte = data[1]
        let status: FTMSTrainingStatus
        switch statusByte {
        case 0x01: status = .idle
        case 0x02: status = .warmingUp
        case 0x03: status = .lowIntensity
        case 0x04: status = .highIntensity
        case 0x05: status = .recovery
        case 0x06: status = .isometric
        case 0x07: status = .heartRateControl
        case 0x08: status = .fitnessTest
        case 0x09: status = .quickStart
        case 0x0D: status = .manualMode
        case 0x0E: status = .coolDown
        case 0x0A: status = .preWorkout
        case 0x0B: status = .postWorkout
        default: status = .unknown
        }
        DispatchQueue.main.async {
            self.trainingStatus = status
        }
    }
    
    // MARK: - Device Info Parsing
    
    private func parseDeviceInfoString(_ data: Data, keyPath: WritableKeyPath<BLEDeviceInfo, String?>) {
        guard let str = String(data: data, encoding: .utf8) else { return }
        DispatchQueue.main.async {
            self.deviceInfo[keyPath: keyPath] = str.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    
    // MARK: - Supported Range Parsing
    
    private enum RangeType { case power, speed, resistance, heartRate }
    
    private func parseSupportedRange(_ data: Data, type: RangeType) {
        // Format: minimum (sint16/uint16) + maximum (sint16/uint16) + increment (uint16) = 6 bytes
        guard data.count >= 6 else { return }
        let minVal: Double
        let maxVal: Double
        
        switch type {
        case .power:
            // sint16 watts
            minVal = Double(Int16(bitPattern: UInt16(data[0]) | (UInt16(data[1]) << 8)))
            maxVal = Double(Int16(bitPattern: UInt16(data[2]) | (UInt16(data[3]) << 8)))
        case .speed:
            // uint16, 0.01 km/h resolution
            minVal = Double(UInt16(data[0]) | (UInt16(data[1]) << 8)) * 0.01
            maxVal = Double(UInt16(data[2]) | (UInt16(data[3]) << 8)) * 0.01
        case .resistance:
            // sint16, 0.1 resolution
            minVal = Double(Int16(bitPattern: UInt16(data[0]) | (UInt16(data[1]) << 8))) * 0.1
            maxVal = Double(Int16(bitPattern: UInt16(data[2]) | (UInt16(data[3]) << 8))) * 0.1
        case .heartRate:
            // uint8 bpm (only 1 byte each for HR range)
            guard data.count >= 3 else { return }
            minVal = Double(data[0])
            maxVal = Double(data[1])
            DispatchQueue.main.async {
                self.supportedRanges.heartRateMin = minVal
                self.supportedRanges.heartRateMax = maxVal
            }
            return
        }
        
        DispatchQueue.main.async {
            switch type {
            case .power:
                self.supportedRanges.powerMin = minVal
                self.supportedRanges.powerMax = maxVal
            case .speed:
                self.supportedRanges.speedMin = minVal
                self.supportedRanges.speedMax = maxVal
            case .resistance:
                self.supportedRanges.resistanceMin = minVal
                self.supportedRanges.resistanceMax = maxVal
            case .heartRate:
                break
            }
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension BLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        isBluetoothReady = central.state == .poweredOn
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let deviceName = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "Unknown Device"
        
        // Detect supported sensor types from advertisement
        var sensorTypes: [SensorType] = []
        if let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
            for uuid in serviceUUIDs {
                switch uuid.uuidString.uppercased() {
                case "1818": sensorTypes.append(.power)
                case "180D": sensorTypes.append(.heartRate)
                case "1816": sensorTypes.append(.cadence)
                case "1826": sensorTypes.append(.ftms)
                default: break
                }
            }
        }
        
        // Only show named devices or devices with known services
        guard deviceName != "Unknown Device" || !sensorTypes.isEmpty else { return }
        
        if let index = discoveredDevices.firstIndex(where: { $0.peripheral.identifier == peripheral.identifier }) {
            discoveredDevices[index] = DiscoveredDevice(
                id: peripheral.identifier,
                peripheral: peripheral,
                name: deviceName,
                rssi: RSSI.intValue,
                supportedSensors: sensorTypes.isEmpty ? discoveredDevices[index].supportedSensors : sensorTypes,
                lastSeen: Date()
            )
        } else {
            discoveredDevices.append(DiscoveredDevice(
                id: peripheral.identifier,
                peripheral: peripheral,
                name: deviceName,
                rssi: RSSI.intValue,
                supportedSensors: sensorTypes,
                lastSeen: Date()
            ))
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectionState = .connected
        peripheral.delegate = self
        connectedPeripheralSet.insert(peripheral)
        connectedPeripherals = Array(connectedPeripheralSet)
        reconnectTimer?.invalidate()
        peripheral.discoverServices(nil)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectedPeripheralSet.remove(peripheral)
        connectedPeripherals = Array(connectedPeripheralSet)
        
        if connectedPeripheralSet.isEmpty {
            connectionState = .disconnected
        }
        
        if error != nil {
            attemptReconnect(peripheral: peripheral)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectionState = .disconnected
        attemptReconnect(peripheral: peripheral)
    }
}

// MARK: - CBPeripheralDelegate
extension BLEManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for char in characteristics {
            // Subscribe to known notify characteristics
            if knownNotifyUUIDs.contains(char.uuid) {
                if char.properties.contains(.notify) {
                    peripheral.setNotifyValue(true, for: char)
                }
                if char.properties.contains(.read) {
                    peripheral.readValue(for: char)
                }
            }
            // Read-once characteristics (device info, supported ranges)
            else if readOnceUUIDs.contains(char.uuid) {
                if char.properties.contains(.read) {
                    peripheral.readValue(for: char)
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, let data = characteristic.value, !data.isEmpty else { return }
        
        switch characteristic.uuid {
        case powerMeasurementUUID:
            parsePowerMeasurement(data)
        case heartRateMeasurementUUID:
            parseHeartRateMeasurement(data)
        case cscMeasurementUUID:
            parseCSCMeasurement(data)
        case indoorBikeDataUUID:
            parseIndoorBikeData(data)
        case trainingStatusUUID:
            parseTrainingStatus(data)
        case manufacturerNameUUID:
            parseDeviceInfoString(data, keyPath: \.manufacturer)
        case modelNumberUUID:
            parseDeviceInfoString(data, keyPath: \.modelNumber)
        case serialNumberUUID:
            parseDeviceInfoString(data, keyPath: \.serialNumber)
        case hardwareRevisionUUID:
            parseDeviceInfoString(data, keyPath: \.hardwareRevision)
        case firmwareRevisionUUID:
            parseDeviceInfoString(data, keyPath: \.firmwareRevision)
        case softwareRevisionUUID:
            parseDeviceInfoString(data, keyPath: \.softwareRevision)
        case supportedPowerRangeUUID:
            parseSupportedRange(data, type: .power)
        case supportedSpeedRangeUUID:
            parseSupportedRange(data, type: .speed)
        case supportedResistanceRangeUUID:
            parseSupportedRange(data, type: .resistance)
        case supportedHeartRateRangeUUID:
            parseSupportedRange(data, type: .heartRate)
        default:
            break
        }
        
        // Update verification data
        DispatchQueue.main.async {
            self.verificationData = self.liveData
        }
    }
}
