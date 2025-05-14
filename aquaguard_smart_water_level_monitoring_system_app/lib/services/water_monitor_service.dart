import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/water_level.dart';

class WaterMonitorService {
  // BLE UUIDs matching those in Arduino sketch
  static const String _serviceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const String _notifyCharacteristicUuid =
      "beb5483e-36e1-4688-b7f5-ea07361b26a8";
  static const String _writeCharacteristicUuid =
      "beb5483e-36e1-4688-b7f5-ea07361b26a9";

  // Instance variables
  BluetoothDevice? _device;
  BluetoothCharacteristic? _notifyCharacteristic;
  BluetoothCharacteristic? _writeCharacteristic;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _deviceStateSubscription;
  StreamSubscription? _connectionSubscription;

  // Stream controllers
  final _waterLevelController = StreamController<WaterLevel>.broadcast();
  final _connectionStatusController = StreamController<bool>.broadcast();

  // Stream getters
  Stream<WaterLevel> get waterLevelStream => _waterLevelController.stream;
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;

  // Singleton pattern
  static final WaterMonitorService _instance = WaterMonitorService._internal();

  factory WaterMonitorService() {
    return _instance;
  }

  WaterMonitorService._internal() {
    _init();
  }

  Future<void> _init() async {
    // Initialize FlutterBluePlus
    try {
      // First check if Bluetooth is on
      if (await FlutterBluePlus.isAvailable == false) {
        debugPrint("Bluetooth not available");
        return;
      }

      if (await FlutterBluePlus.isOn == false) {
        debugPrint("Bluetooth is off");
        return;
      }

      // Listen for already connected devices
      final connectedDevices = FlutterBluePlus.connectedDevices;
      for (var device in connectedDevices) {
        if (device.platformName == "AquaGuard") {
          debugPrint("Found already connected AquaGuard device");
          _device = device;
          _connectionStatusController.add(true);
          await _discoverServices();
        }
      }

      // Listen for adapter state changes (Bluetooth on/off)
      _connectionSubscription = FlutterBluePlus.adapterState.listen((state) {
        debugPrint("Bluetooth adapter state: $state");
        if (state == BluetoothAdapterState.off) {
          _connectionStatusController.add(false);
          _device = null;
          _notifyCharacteristic = null;
          _writeCharacteristic = null;
        }
      });
    } catch (e) {
      debugPrint("Error initializing FlutterBluePlus: $e");
    }
  }

  // Start scanning for devices
  Future<void> startScan() async {
    try {
      if (await FlutterBluePlus.isAvailable == false) {
        debugPrint("Bluetooth not available");
        return;
      }

      if (await FlutterBluePlus.isOn == false) {
        debugPrint("Bluetooth is off");
        return;
      }

      // Stop any existing scan
      await FlutterBluePlus.stopScan();

      debugPrint("Starting scan for AquaGuard device");

      // For web platform, we need to use a different approach
      if (kIsWeb) {
        _scanForDevicesWeb();
        return;
      }

      // Set up scan subscription for native platforms
      _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          debugPrint("Found device: ${result.device.platformName}");
          if (result.device.platformName == "AquaGuard") {
            debugPrint("Found AquaGuard device, connecting...");
            // Stop scanning once we find our device
            FlutterBluePlus.stopScan();
            _connect(result.device);
          }
        }
      }, onError: (e) => debugPrint("Scan error: $e"));

      // Start a new scan
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        androidScanMode: AndroidScanMode.lowLatency,
      );

      debugPrint("Started scanning for BLE devices");
    } catch (e) {
      debugPrint("Error scanning for devices: $e");
    }
  }

  // Special scanning method for web platforms that requires user interaction
  Future<void> _scanForDevicesWeb() async {
    try {
      debugPrint("Using web-specific BLE scanning approach");

      // On web, we need to directly request the device from the user
      // This will trigger the browser's Bluetooth permission dialog
      // which requires user interaction
      await FlutterBluePlus.startScan(
        withServices: [Guid(_serviceUuid)],
        timeout: const Duration(seconds: 10),
      );

      // Wait for scan to complete and collect results
      await Future.delayed(const Duration(seconds: 10));
      final List<ScanResult> results = await FlutterBluePlus.scanResults.first;
      final List<BluetoothDevice> devices =
          results.map((result) => result.device).toList();

      // Process discovered devices
      for (BluetoothDevice device in devices) {
        debugPrint("Found device: ${device.platformName}");
        if (device.platformName == "AquaGuard") {
          debugPrint("Found AquaGuard device, connecting...");
          _connect(device);
          break;
        }
      }

      // If we didn't find our device, stop scanning
      FlutterBluePlus.stopScan();
    } catch (e) {
      debugPrint("Error in web BLE scanning: $e");
    }
  }

  // Connect to AquaGuard device
  Future<void> _connect(BluetoothDevice device) async {
    try {
      // Cancel any existing connections
      if (_device != null && _device != device) {
        await _device!.disconnect();
      }

      // Connect to the device
      await device.connect(
          timeout: const Duration(seconds: 15), autoConnect: false);

      _device = device;
      _connectionStatusController.add(true);
      debugPrint("Connected to ${device.platformName}");

      // Discover services after connecting
      await _discoverServices();
    } catch (e) {
      debugPrint("Error connecting to device: $e");
      _connectionStatusController.add(false);
    }
  }

  // Discover services and set up notifications
  Future<void> _discoverServices() async {
    if (_device == null) return;

    try {
      debugPrint("Discovering services...");
      List<BluetoothService> services = await _device!.discoverServices();
      debugPrint("Found ${services.length} services");

      for (BluetoothService service in services) {
        if (service.uuid
            .toString()
            .toLowerCase()
            .contains(_serviceUuid.toLowerCase())) {
          debugPrint("Found AquaGuard service with UUID: ${service.uuid}");

          for (BluetoothCharacteristic characteristic
              in service.characteristics) {
            final charUuid = characteristic.uuid.toString().toLowerCase();
            debugPrint("Found characteristic: $charUuid");

            if (charUuid.contains(_notifyCharacteristicUuid.toLowerCase())) {
              debugPrint("Setting up notify characteristic");
              _notifyCharacteristic = characteristic;
              await _setupNotifications();
            } else if (charUuid
                .contains(_writeCharacteristicUuid.toLowerCase())) {
              debugPrint("Setting up write characteristic");
              _writeCharacteristic = characteristic;
            }
          }
        }
      }

      if (_notifyCharacteristic == null || _writeCharacteristic == null) {
        debugPrint("Failed to find required characteristics");
      }
    } catch (e) {
      debugPrint("Error discovering services: $e");
    }
  }

  // Set up notifications from device
  Future<void> _setupNotifications() async {
    if (_notifyCharacteristic == null) {
      debugPrint("Notify characteristic is null");
      return;
    }

    try {
      debugPrint("Setting up notifications");

      // Cancel any existing subscription
      _deviceStateSubscription?.cancel();

      // Enable notifications
      await _notifyCharacteristic!.setNotifyValue(true);
      debugPrint("Notification enabled");

      // Subscribe to value changes
      _deviceStateSubscription =
          _notifyCharacteristic!.lastValueStream.listen((data) {
        if (data.isNotEmpty) {
          try {
            String jsonString = String.fromCharCodes(data);
            debugPrint("Received data: $jsonString");

            Map<String, dynamic> json = jsonDecode(jsonString);
            WaterLevel waterLevel = WaterLevel.fromJson(json);
            _waterLevelController.add(waterLevel);
          } catch (e) {
            debugPrint("Error parsing notification data: $e");
          }
        }
      }, onError: (e) => debugPrint("Notification error: $e"));

      // Trigger initial read
      await _notifyCharacteristic!.read();
      debugPrint("Notifications set up successfully");
    } catch (e) {
      debugPrint("Error setting up notifications: $e");
    }
  }

  // Turn off buzzer
  Future<void> turnOffBuzzer() async {
    if (_writeCharacteristic == null) {
      debugPrint("Write characteristic not available");
      return;
    }

    try {
      debugPrint("Sending BUZZER_OFF command");
      await _writeCharacteristic!.write(utf8.encode("BUZZER_OFF"));
      debugPrint("Sent BUZZER_OFF command");
    } catch (e) {
      debugPrint("Error sending BUZZER_OFF command: $e");
    }
  }

  // Disconnect from device
  Future<void> disconnect() async {
    if (_device != null) {
      try {
        await _device!.disconnect();
        _device = null;
        _notifyCharacteristic = null;
        _writeCharacteristic = null;
        _connectionStatusController.add(false);
        debugPrint("Disconnected from device");
      } catch (e) {
        debugPrint("Error disconnecting: $e");
      }
    }
  }

  // Check if connected
  bool get isConnected => _device != null;

  // Dispose resources
  Future<void> dispose() async {
    _scanSubscription?.cancel();
    _deviceStateSubscription?.cancel();
    _connectionSubscription?.cancel();

    // Make sure we properly disconnect before closing streams
    await disconnect();

    _waterLevelController.close();
    _connectionStatusController.close();
  }
}
