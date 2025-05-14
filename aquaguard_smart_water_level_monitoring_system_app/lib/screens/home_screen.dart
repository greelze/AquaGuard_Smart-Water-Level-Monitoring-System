import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/water_level.dart';
import '../services/water_monitor_service.dart';
import '../widgets/water_level_panel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final WaterMonitorService _waterMonitorService = WaterMonitorService();
  bool _isConnected = false;
  bool _isScanning = false;
  WaterLevel _waterLevel = WaterLevel.initial();
  StreamSubscription<WaterLevel>? _waterLevelSubscription;
  StreamSubscription<bool>? _connectionSubscription;

  @override
  void initState() {
    super.initState();
    _setupSubscriptions();
    // Don't automatically start scanning on web platforms
    if (!kIsWeb) {
      _startScan();
    }
  }

  void _setupSubscriptions() {
    // Listen for water level updates
    _waterLevelSubscription =
        _waterMonitorService.waterLevelStream.listen((waterLevel) {
      setState(() {
        _waterLevel = waterLevel;
      });
    });

    // Listen for connection status updates
    _connectionSubscription =
        _waterMonitorService.connectionStatusStream.listen((connected) {
      setState(() {
        _isConnected = connected;
      });
    });
  }

  Future<void> _startScan() async {
    if (!mounted) return;

    setState(() {
      _isScanning = true;
    });

    await _waterMonitorService.startScan();

    // Give some time for the scan to complete
    Future.delayed(const Duration(seconds: 10), () {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
      });
    });
  }

  void _turnOffBuzzer() {
    _waterMonitorService.turnOffBuzzer();
  }

  @override
  void dispose() {
    _waterLevelSubscription?.cancel();
    _connectionSubscription?.cancel();
    _waterMonitorService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Panel Control',
          style: TextStyle(
            color: Colors.blue,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.settings, color: Colors.blue),
          onPressed: () {
            // Add settings navigation logic here
          },
        ),
        actions: [
          _buildConnectionIcon(),
        ],
      ),
      body: _isConnected
          ? WaterLevelPanel(
              waterLevel: _waterLevel,
              onBuzzerOff: _turnOffBuzzer,
            )
          : _buildConnectionStatus(),
    );
  }

  Widget _buildConnectionIcon() {
    if (_isScanning) {
      return Container(
        width: 24,
        height: 24,
        margin: const EdgeInsets.only(right: 16),
        child: const CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
        ),
      );
    }

    return IconButton(
      icon: Icon(
        _isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
        color: _isConnected ? Colors.blue : Colors.red,
      ),
      onPressed: _isScanning ? null : _startScan,
    );
  }

  Widget _buildConnectionStatus() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bluetooth_searching,
            size: 80,
            color: Colors.blue.withAlpha(150),
          ),
          const SizedBox(height: 20),
          Text(
            _isScanning
                ? 'Searching for AquaGuard...'
                : 'Not connected to AquaGuard',
            style: const TextStyle(
              fontSize: 18,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 30),
          if (!_isScanning)
            ElevatedButton.icon(
              onPressed: _startScan,
              icon: const Icon(Icons.refresh),
              label: Text(kIsWeb ? 'Connect to AquaGuard' : 'Scan Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          if (_isScanning)
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          // Add web-specific message
          if (kIsWeb && !_isScanning)
            Container(
              margin: const EdgeInsets.only(top: 20),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: const Column(
                children: [
                  Text(
                    'Web Bluetooth Notice',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Click the "Connect to AquaGuard" button to grant Bluetooth permissions.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
