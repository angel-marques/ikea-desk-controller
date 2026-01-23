import Foundation
@preconcurrency import CoreBluetooth
import Combine

// LINAK BLE UUIDs for IKEA IDÅSEN desk
enum DeskUUIDs {
    // Services
    nonisolated(unsafe) static let controlService = CBUUID(string: "99fa0001-338a-1024-8a49-009c0215f78a")
    nonisolated(unsafe) static let dpgService = CBUUID(string: "99fa0010-338a-1024-8a49-009c0215f78a")
    nonisolated(unsafe) static let heightService = CBUUID(string: "99fa0020-338a-1024-8a49-009c0215f78a")
    nonisolated(unsafe) static let referenceInputService = CBUUID(string: "99fa0030-338a-1024-8a49-009c0215f78a")

    // Characteristics
    nonisolated(unsafe) static let command = CBUUID(string: "99fa0002-338a-1024-8a49-009c0215f78a")
    nonisolated(unsafe) static let dpg = CBUUID(string: "99fa0011-338a-1024-8a49-009c0215f78a")
    nonisolated(unsafe) static let height = CBUUID(string: "99fa0021-338a-1024-8a49-009c0215f78a")
    nonisolated(unsafe) static let referenceInput = CBUUID(string: "99fa0031-338a-1024-8a49-009c0215f78a")
}

enum DeskCommand {
    static let up: [UInt8] = [0x47, 0x00]
    static let down: [UInt8] = [0x46, 0x00]
    static let stop: [UInt8] = [0xFF, 0x00]
    static let wakeup: [UInt8] = [0xFE, 0x00]
}

enum ConnectionState: Equatable {
    case disconnected
    case scanning
    case connecting
    case connected
    case error(String)

    var description: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .scanning: return "Scanning..."
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .error(let message): return message
        }
    }

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}

struct DiscoveredDevice: Identifiable {
    let id: UUID
    let peripheral: CBPeripheral
    let name: String
    let rssi: Int

    init(peripheral: CBPeripheral, rssi: Int) {
        self.id = peripheral.identifier
        self.peripheral = peripheral
        self.name = peripheral.name ?? "Unknown Device"
        self.rssi = rssi
    }
}

@MainActor
class BluetoothManager: NSObject, ObservableObject {
    @Published var connectionState: ConnectionState = .disconnected
    @Published var currentHeight: Double = 72.4  // cm
    @Published var isMoving: Bool = false
    @Published var discoveredDevices: [DiscoveredDevice] = []
    @Published var connectedDeviceName: String?
    @Published var savedDeviceIdentifier: String?

    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var heightCharacteristic: CBCharacteristic?
    private var commandCharacteristic: CBCharacteristic?
    private var referenceInputCharacteristic: CBCharacteristic?

    private var targetHeight: Double?
    private var moveTimer: Timer?
    private var heightPollingTimer: Timer?
    private var previousHeight: Double = 0
    private var stallCount: Int = 0
    private var servicesDiscovered: Int = 0

    // Height limits (in cm)
    static let minHeight: Double = 62.0
    static let maxHeight: Double = 127.0

    override init() {
        super.init()
        loadSavedDevice()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: - Public Methods

    func startScanning() {
        guard centralManager.state == .poweredOn else {
            connectionState = .error("Bluetooth is not available")
            return
        }
        discoveredDevices.removeAll()
        connectionState = .scanning
        centralManager.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )

        // Stop scanning after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.stopScanning()
        }
    }

    func stopScanning() {
        centralManager.stopScan()
        if case .scanning = connectionState {
            connectionState = .disconnected
        }
    }

    func connect(to device: DiscoveredDevice) {
        stopScanning()
        connectionState = .connecting
        connectedDeviceName = device.name
        centralManager.connect(device.peripheral, options: nil)
    }

    func connectToSavedDevice() {
        guard centralManager.state == .poweredOn,
              let identifier = savedDeviceIdentifier,
              let uuid = UUID(uuidString: identifier) else { return }

        connectionState = .connecting

        // Try to retrieve the peripheral from cache
        let peripherals = centralManager.retrievePeripherals(withIdentifiers: [uuid])
        if let peripheral = peripherals.first {
            connectedPeripheral = peripheral
            peripheral.delegate = self
            centralManager.connect(peripheral, options: nil)
            return
        }

        // Try to get already connected peripherals (e.g., connected by another app)
        let connectedPeripherals = centralManager.retrieveConnectedPeripherals(withServices: [
            DeskUUIDs.controlService,
            DeskUUIDs.heightService
        ])
        if let peripheral = connectedPeripherals.first(where: { $0.identifier.uuidString == identifier }) {
            connectedPeripheral = peripheral
            peripheral.delegate = self
            centralManager.connect(peripheral, options: nil)
            return
        }

        // Device not in cache, need to scan for it
        print("Device not in cache, scanning...")
        startScanningForSavedDevice()
    }

    private func startScanningForSavedDevice() {
        centralManager.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )

        // Stop scanning after 15 seconds if not found
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            guard let self = self else { return }
            if case .connecting = self.connectionState {
                self.centralManager.stopScan()
                self.connectionState = .error("Device not found")
            }
        }
    }

    func disconnect() {
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        resetConnection()
    }

    func forgetDevice() {
        disconnect()
        savedDeviceIdentifier = nil
        connectedDeviceName = nil
        UserDefaults.standard.removeObject(forKey: "savedDeskIdentifier")
        UserDefaults.standard.removeObject(forKey: "savedDeskName")
    }

    func moveUp() {
        guard connectionState.isConnected else { return }
        sendCommand(DeskCommand.wakeup)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.sendCommand(DeskCommand.up)
        }
    }

    func moveDown() {
        guard connectionState.isConnected else { return }
        sendCommand(DeskCommand.wakeup)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.sendCommand(DeskCommand.down)
        }
    }

    func stopMovement() {
        moveTimer?.invalidate()
        moveTimer = nil
        targetHeight = nil
        isMoving = false
        sendCommand(DeskCommand.stop)
    }

    func moveTo(height: Double) {
        guard connectionState.isConnected,
              referenceInputCharacteristic != nil else {
            print("Cannot move: not connected or reference input not available")
            return
        }

        let clampedHeight = max(Self.minHeight, min(Self.maxHeight, height))

        if abs(currentHeight - clampedHeight) < 0.5 {
            return  // Already at target
        }

        targetHeight = clampedHeight
        isMoving = true
        previousHeight = currentHeight
        stallCount = 0

        // Initialize: wakeup and stop to prepare reference input system (like Python)
        sendCommand(DeskCommand.wakeup)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.sendCommand(DeskCommand.stop)
        }

        // Start movement loop after initialization
        moveTimer?.invalidate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.moveTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.updateMovement()
                }
            }
        }
    }

    func startHeightPolling() {
        heightPollingTimer?.invalidate()
        heightPollingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollHeight()
            }
        }
        // Poll immediately
        pollHeight()
    }

    func stopHeightPolling() {
        heightPollingTimer?.invalidate()
        heightPollingTimer = nil
    }

    private func pollHeight() {
        guard connectionState.isConnected,
              let peripheral = connectedPeripheral,
              let characteristic = heightCharacteristic else { return }
        peripheral.readValue(for: characteristic)
    }

    // MARK: - Private Methods

    private func loadSavedDevice() {
        savedDeviceIdentifier = UserDefaults.standard.string(forKey: "savedDeskIdentifier")
        connectedDeviceName = UserDefaults.standard.string(forKey: "savedDeskName")
    }

    private func saveDevice(identifier: String, name: String) {
        savedDeviceIdentifier = identifier
        connectedDeviceName = name
        UserDefaults.standard.set(identifier, forKey: "savedDeskIdentifier")
        UserDefaults.standard.set(name, forKey: "savedDeskName")
    }

    private func resetConnection() {
        connectionState = .disconnected
        connectedPeripheral = nil
        heightCharacteristic = nil
        commandCharacteristic = nil
        referenceInputCharacteristic = nil
        isMoving = false
        targetHeight = nil
        servicesDiscovered = 0
        moveTimer?.invalidate()
        moveTimer = nil
        heightPollingTimer?.invalidate()
        heightPollingTimer = nil
    }

    private func sendCommand(_ command: [UInt8]) {
        guard let peripheral = connectedPeripheral,
              let characteristic = commandCharacteristic else { return }
        let data = Data(command)
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
    }

    private func sendTargetHeight(_ height: Double) {
        guard let peripheral = connectedPeripheral,
              let characteristic = referenceInputCharacteristic else { return }

        // Convert cm to raw value
        let rawValue = UInt16((height - 62.0) * 100)
        var data = Data()
        data.append(UInt8(rawValue & 0xFF))
        data.append(UInt8((rawValue >> 8) & 0xFF))

        peripheral.writeValue(data, for: characteristic, type: .withResponse)
    }

    private func updateMovement() {
        guard let target = targetHeight else {
            stopMovement()
            return
        }

        // Check if reached target
        if abs(currentHeight - target) < 1.0 {
            stopMovement()
            return
        }

        // Detect stall
        if abs(currentHeight - previousHeight) < 0.1 {
            stallCount += 1
            if stallCount > 20 {
                stopMovement()
                return
            }
        } else {
            stallCount = 0
        }
        previousHeight = currentHeight

        // Send target position
        sendTargetHeight(target)
    }

    private func parseHeight(from data: Data) -> Double {
        guard data.count >= 2 else { return currentHeight }
        let rawHeight = UInt16(data[0]) | (UInt16(data[1]) << 8)
        return (Double(rawHeight) / 100.0) + 62.0
    }

    private func checkConnectionReady() {
        // We need height, command, and reference input characteristics for full functionality
        if heightCharacteristic != nil && commandCharacteristic != nil && referenceInputCharacteristic != nil {
            connectionState = .connected
            print("All characteristics found - connected!")
            // Wake up the desk
            sendCommand(DeskCommand.wakeup)
            // Start polling height
            startHeightPolling()
        } else {
            // Debug: print what we have so far
            print("Characteristics: height=\(heightCharacteristic != nil), command=\(commandCharacteristic != nil), refInput=\(referenceInputCharacteristic != nil)")
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            switch central.state {
            case .poweredOn:
                // Auto-reconnect to saved device
                if savedDeviceIdentifier != nil {
                    connectToSavedDevice()
                }
            case .poweredOff:
                connectionState = .error("Bluetooth is turned off")
            case .unauthorized:
                connectionState = .error("Bluetooth access not authorized")
            case .unsupported:
                connectionState = .error("Bluetooth not supported")
            default:
                break
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        Task { @MainActor in
            let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? ""

            // Check if this is our saved device (auto-reconnect during scan)
            if let savedId = savedDeviceIdentifier,
               peripheral.identifier.uuidString == savedId,
               case .connecting = connectionState {
                centralManager.stopScan()
                connectedPeripheral = peripheral
                peripheral.delegate = self
                connectedDeviceName = name.isEmpty ? connectedDeviceName : name
                centralManager.connect(peripheral, options: nil)
                return
            }

            // Filter for desk-related devices or any named device
            let lowercaseName = name.lowercased()
            guard lowercaseName.contains("desk") ||
                  lowercaseName.contains("idasen") ||
                  lowercaseName.contains("linak") ||
                  !name.isEmpty else { return }

            let device = DiscoveredDevice(peripheral: peripheral, rssi: RSSI.intValue)

            if !discoveredDevices.contains(where: { $0.id == device.id }) {
                discoveredDevices.append(device)
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            connectedPeripheral = peripheral
            peripheral.delegate = self
            servicesDiscovered = 0

            // Discover ALL services - the desk has multiple services
            peripheral.discoverServices(nil)

            // Save device info
            let name = peripheral.name ?? connectedDeviceName ?? "IKEA Desk"
            saveDevice(identifier: peripheral.identifier.uuidString, name: name)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            connectionState = .error(error?.localizedDescription ?? "Connection failed")
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            let wasConnected = connectionState.isConnected
            resetConnection()

            // Auto-reconnect if we were connected before
            if wasConnected && savedDeviceIdentifier != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                    self?.connectToSavedDevice()
                }
            }
        }
    }
}

// MARK: - CBPeripheralDelegate
extension BluetoothManager: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        Task { @MainActor in
            guard error == nil else {
                connectionState = .error(error!.localizedDescription)
                return
            }

            // Discover characteristics for all services
            for service in peripheral.services ?? [] {
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        Task { @MainActor in
            guard error == nil else { return }

            for characteristic in service.characteristics ?? [] {
                switch characteristic.uuid {
                case DeskUUIDs.height:
                    heightCharacteristic = characteristic
                    peripheral.setNotifyValue(true, for: characteristic)
                    peripheral.readValue(for: characteristic)
                case DeskUUIDs.command:
                    commandCharacteristic = characteristic
                case DeskUUIDs.referenceInput:
                    referenceInputCharacteristic = characteristic
                default:
                    break
                }
            }

            // Check if we have enough to be considered connected
            checkConnectionReady()
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        Task { @MainActor in
            guard error == nil, let data = characteristic.value else { return }

            if characteristic.uuid == DeskUUIDs.height {
                currentHeight = parseHeight(from: data)
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        // Handle write confirmation if needed
    }
}
