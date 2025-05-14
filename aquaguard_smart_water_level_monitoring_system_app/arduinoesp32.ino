#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// Pins
#define trigPin 4
#define echoPin 2
#define buzzer 5

// Tank settings
#define EMPTY_LEVEL 30  // cm
#define FULL_LEVEL 5    // cm

// BLE UUIDs
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID_NOTIFY "beb5483e-36e1-4688-b7f5-ea07361b26a8"
#define CHARACTERISTIC_UUID_WRITE "beb5483e-36e1-4688-b7f5-ea07361b26a9"

BLEServer* pServer = NULL;
BLECharacteristic* pNotifyCharacteristic = NULL;
BLECharacteristic* pWriteCharacteristic = NULL;

bool deviceConnected = false;
bool oldDeviceConnected = false;
bool buzzerActive = false;
long duration, distance;
int percentage = 0;
String status = "unknown";
bool newMeasurement = false;

// Connection callback
class MyServerCallbacks: public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
  }

  void onDisconnect(BLEServer* pServer) {
    deviceConnected = false;
  }
};

// Command receiver callback
class MyCallbacks: public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pChar) {
    String cmd = pChar->getValue();  // Use Arduino String
    
    if (cmd.length() > 0) {
      Serial.print("Command received: ");
      Serial.println(cmd);

      if (cmd == "BUZZER_OFF") {
        Serial.println("Turning buzzer off");
        digitalWrite(buzzer, LOW);
        buzzerActive = false;
        newMeasurement = true;
      }
    }
  }
};

void setup() {
  Serial.begin(115200);
  Serial.println("AquaGuard - Simplified Version");

  // Setup pins
  pinMode(trigPin, OUTPUT);
  pinMode(echoPin, INPUT);
  pinMode(buzzer, OUTPUT);

  // Setup BLE
  BLEDevice::init("AquaGuard");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService *pService = pServer->createService(SERVICE_UUID);

  // Setup characteristics
  pNotifyCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_UUID_NOTIFY,
    BLECharacteristic::PROPERTY_READ | 
    BLECharacteristic::PROPERTY_NOTIFY
  );
  pNotifyCharacteristic->addDescriptor(new BLE2902());

  pWriteCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_UUID_WRITE,
    BLECharacteristic::PROPERTY_WRITE
  );
  pWriteCharacteristic->setCallbacks(new MyCallbacks());

  pService->start();

  // Start advertising
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  pAdvertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();

  Serial.println("Ready for connections");
}

void loop() {
  // Measure water level
  digitalWrite(trigPin, LOW);
  delayMicroseconds(2);
  digitalWrite(trigPin, HIGH);
  delayMicroseconds(10);
  digitalWrite(trigPin, LOW);

  duration = pulseIn(echoPin, HIGH);
  distance = duration / 58.2;

  // Calculate percentage
  if (distance >= EMPTY_LEVEL) {
    percentage = 0;
  } else if (distance <= FULL_LEVEL) {
    percentage = 100;
  } else {
    percentage = 100 - ((distance - FULL_LEVEL) * 100) / (EMPTY_LEVEL - FULL_LEVEL);
  }

  // Set status
  if (percentage < 20) {
    status = "low";
  } else if (percentage < 70) {
    status = "medium";
  } else {
    status = "full";
  }

  // Check if buzzer should be active
  if (distance <= 7) {
    if (!buzzerActive) {
      digitalWrite(buzzer, HIGH);
      buzzerActive = true;
      newMeasurement = true;
    }
  } else if (!buzzerActive) {
    digitalWrite(buzzer, LOW);
  }

  // Print debug info
  Serial.print("Distance: ");
  Serial.print(distance);
  Serial.print("cm | Level: ");
  Serial.print(percentage);
  Serial.print("% | Status: ");
  Serial.print(status);
  Serial.print(" | Buzzer: ");
  Serial.println(buzzerActive ? "ON" : "OFF");

  // Send data if connected
  if (deviceConnected) {
    static unsigned long lastSend = 0;
    if (newMeasurement || millis() - lastSend > 2000) {
      String json = "{\"percentage\":" + String(percentage) +
                    ",\"status\":\"" + status +
                    "\",\"buzzer_active\":" + (buzzerActive ? "true" : "false") + "}";

      pNotifyCharacteristic->setValue(json.c_str());  // Use c_str()
      pNotifyCharacteristic->notify();

      lastSend = millis();
      newMeasurement = false;

      Serial.print("Sent: ");
      Serial.println(json);
    }
  }

  // Handle connection state changes
  if (!deviceConnected && oldDeviceConnected) {
    delay(500);
    pServer->startAdvertising();
    oldDeviceConnected = deviceConnected;
  }

  if (deviceConnected && !oldDeviceConnected) {
    oldDeviceConnected = deviceConnected;
  }

  delay(500);
}
