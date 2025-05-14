import 'package:flutter/material.dart';
import '../models/water_level.dart';

class WaterLevelPanel extends StatelessWidget {
  final WaterLevel waterLevel;
  final Function() onBuzzerOff;

  const WaterLevelPanel({
    Key? key,
    required this.waterLevel,
    required this.onBuzzerOff,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Water percentage availability',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue.withAlpha(51),
                ),
              ),
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue.withAlpha(102),
                ),
              ),
              Text(
                '${waterLevel.percentage}%',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _getStatusColor(waterLevel.status),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.water_drop,
                  color: _getStatusTextColor(waterLevel.status)),
              const SizedBox(width: 10),
              Text(
                _getStatusText(waterLevel.status),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _getStatusTextColor(waterLevel.status),
                ),
              ),
            ],
          ),
        ),
        if (waterLevel.buzzerActive) ...[
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onBuzzerOff,
            icon: const Icon(Icons.volume_off),
            label: const Text('Turn Off Buzzer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ],
    );
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'low':
        return 'Tank low';
      case 'medium':
        return 'Tank half full';
      case 'full':
        return 'Tank full';
      default:
        return 'Unknown status';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'low':
        return Colors.red.withAlpha(50);
      case 'medium':
        return Colors.orange.withAlpha(50);
      case 'full':
        return Colors.blue.withAlpha(50);
      default:
        return Colors.grey.withAlpha(50);
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'low':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'full':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
