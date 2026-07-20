#include <ModbusMaster.h>

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// =====================================================
// RS485 / MAX485 CONNECTIONS
// =====================================================
//
// MAX485 RO    -> voltage divider -> ESP32 GPIO17
// MAX485 DI    -> ESP32 GPIO16
// MAX485 DE+RE -> ESP32 GPIO4
// MAX485 VCC   -> ESP32 5V
// MAX485 GND   -> common GND
//
// Sensor red    -> +19V
// Sensor black  -> common GND
// Sensor yellow -> MAX485 A
// Sensor green  -> MAX485 B
// =====================================================

constexpr int RS485_RX_PIN = 17;
constexpr int RS485_TX_PIN = 16;
constexpr int RS485_DE_RE_PIN = 4;

// Settings discovered from your sensor
constexpr uint8_t SENSOR_ADDRESS = 2;
constexpr uint32_t SENSOR_BAUD_RATE = 9600;

// Register mapping discovered from your sensor
constexpr uint16_t START_REGISTER = 0x0002;
constexpr uint8_t REGISTER_COUNT = 6;

// Reading interval
constexpr uint32_t READING_INTERVAL_MS = 1000;
constexpr uint8_t SAMPLES_PER_TEST = 5;

// Change this only if the sensor manual specifies an EC multiplier
constexpr float EC_SCALE = 1.0f;

// =====================================================
// BLUETOOTH SETTINGS
// =====================================================

constexpr char BLE_DEVICE_NAME[] = "SoilSense-ESP32";

// BLE UART service
constexpr char BLE_SERVICE_UUID[] =
    "6E400001-B5A3-F393-E0A9-E50E24DCCA9E";

// Mobile app writes to this characteristic
constexpr char BLE_RX_UUID[] =
    "6E400002-B5A3-F393-E0A9-E50E24DCCA9E";

// ESP32 sends readings through this characteristic
constexpr char BLE_TX_UUID[] =
    "6E400003-B5A3-F393-E0A9-E50E24DCCA9E";

// =====================================================
// GLOBAL OBJECTS
// =====================================================

HardwareSerial RS485Serial(2);
ModbusMaster soilSensor;

BLEServer *bleServer = nullptr;
BLECharacteristic *bleTxCharacteristic = nullptr;

volatile bool bleConnected = false;
bool previousBleConnection = false;
volatile bool testRequested = false;
uint8_t samplesRemaining = 0;

uint32_t lastReadingTime = 0;

// =====================================================
// SOIL READING STRUCTURE
// =====================================================

struct SoilReading {
  bool success = false;

  float ecUsCm = 0.0f;
  float pH = 0.0f;

  uint16_t nitrogenMgKg = 0;
  uint16_t phosphorusMgKg = 0;
  uint16_t potassiumMgKg = 0;

  uint8_t modbusError = 0;
};

// =====================================================
// MAX485 DIRECTION CONTROL
// =====================================================

void preTransmission() {
  // HIGH enables MAX485 transmission
  digitalWrite(RS485_DE_RE_PIN, HIGH);
  delayMicroseconds(200);
}

void postTransmission() {
  // Allow the final transmitted byte to leave
  delayMicroseconds(200);

  // LOW disables transmission and enables reception
  digitalWrite(RS485_DE_RE_PIN, LOW);
}

// =====================================================
// BLE CONNECTION CALLBACKS
// =====================================================

class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer *server) override {
    bleConnected = true;
    Serial.println("Bluetooth app connected");
  }

  void onDisconnect(BLEServer *server) override {
    bleConnected = false;
    Serial.println("Bluetooth app disconnected");
  }
};

class CommandCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *characteristic) override {
    std::string command = characteristic->getValue();
    if (command.find("START") != std::string::npos) {
      testRequested = true;
      Serial.println("Soil test requested by mobile app");
    }
  }
};

// =====================================================
// INITIALIZE BLUETOOTH
// =====================================================

void initializeBluetooth() {
  BLEDevice::init(BLE_DEVICE_NAME);

  bleServer = BLEDevice::createServer();
  bleServer->setCallbacks(new ServerCallbacks());

  BLEService *service =
      bleServer->createService(BLE_SERVICE_UUID);

  // Notification characteristic: ESP32 -> mobile app
  bleTxCharacteristic =
      service->createCharacteristic(
          BLE_TX_UUID,
          BLECharacteristic::PROPERTY_NOTIFY
      );

  bleTxCharacteristic->addDescriptor(new BLE2902());

  // Write characteristic: mobile app -> ESP32
  // Receives START from the mobile app.
  BLECharacteristic *rxCharacteristic = service->createCharacteristic(
      BLE_RX_UUID,
      BLECharacteristic::PROPERTY_WRITE
  );
  rxCharacteristic->setCallbacks(new CommandCallbacks());

  service->start();

  BLEAdvertising *advertising =
      BLEDevice::getAdvertising();

  advertising->addServiceUUID(BLE_SERVICE_UUID);
  advertising->setScanResponse(true);
  advertising->start();

  Serial.print("Bluetooth device name: ");
  Serial.println(BLE_DEVICE_NAME);
}

// =====================================================
// READ SENSOR
// =====================================================

SoilReading readSoilSensor() {
  SoilReading reading;

  soilSensor.clearResponseBuffer();

  /*
   * Read registers 0x0002 through 0x0007:
   *
   * Buffer 0 -> 0x0002: EC
   * Buffer 1 -> 0x0003: unused
   * Buffer 2 -> 0x0004: Nitrogen
   * Buffer 3 -> 0x0005: Phosphorus
   * Buffer 4 -> 0x0006: Potassium
   * Buffer 5 -> 0x0007: pH × 10
   */

  uint8_t result = soilSensor.readHoldingRegisters(
      START_REGISTER,
      REGISTER_COUNT
  );

  if (result != ModbusMaster::ku8MBSuccess) {
    reading.success = false;
    reading.modbusError = result;
    return reading;
  }

  uint16_t rawEC =
      soilSensor.getResponseBuffer(0);

  uint16_t rawNitrogen =
      soilSensor.getResponseBuffer(2);

  uint16_t rawPhosphorus =
      soilSensor.getResponseBuffer(3);

  uint16_t rawPotassium =
      soilSensor.getResponseBuffer(4);

  uint16_t rawPH =
      soilSensor.getResponseBuffer(5);

  reading.ecUsCm =
      static_cast<float>(rawEC) * EC_SCALE;

  reading.pH =
      static_cast<float>(rawPH) / 10.0f;

  reading.nitrogenMgKg = rawNitrogen;
  reading.phosphorusMgKg = rawPhosphorus;
  reading.potassiumMgKg = rawPotassium;

  reading.success = true;

  return reading;
}

// =====================================================
// CREATE JSON FOR MOBILE APP
// =====================================================

String createJson(const SoilReading &reading) {
  char json[200];

  if (!reading.success) {
    snprintf(
        json,
        sizeof(json),
        "{\"ok\":false,\"modbus_error\":%u}\n",
        static_cast<unsigned int>(
            reading.modbusError
        )
    );

    return String(json);
  }

  snprintf(
      json,
      sizeof(json),
      "{"
      "\"ok\":true,"
      "\"ec_us_cm\":%.0f,"
      "\"ph\":%.1f,"
      "\"nitrogen_mg_kg\":%u,"
      "\"phosphorus_mg_kg\":%u,"
      "\"potassium_mg_kg\":%u"
      "}\n",
      static_cast<double>(reading.ecUsCm),
      static_cast<double>(reading.pH),
      static_cast<unsigned int>(
          reading.nitrogenMgKg
      ),
      static_cast<unsigned int>(
          reading.phosphorusMgKg
      ),
      static_cast<unsigned int>(
          reading.potassiumMgKg
      )
  );

  return String(json);
}

// =====================================================
// SEND JSON TO MOBILE APP
// =====================================================

void sendBluetoothMessage(const String &message) {
  if (!bleConnected || bleTxCharacteristic == nullptr) {
    return;
  }

  /*
   * Send in 20-byte chunks so that it works with the
   * default BLE packet size.
   *
   * The mobile app should combine the chunks until it
   * receives the newline character '\n'.
   */

  constexpr size_t CHUNK_SIZE = 20;

  size_t offset = 0;
  size_t messageLength = message.length();

  while (offset < messageLength) {
    size_t remaining = messageLength - offset;

    size_t currentChunkLength =
        remaining > CHUNK_SIZE
            ? CHUNK_SIZE
            : remaining;

    String chunk = message.substring(
        offset,
        offset + currentChunkLength
    );

    bleTxCharacteristic->setValue(
        reinterpret_cast<uint8_t *>(
            const_cast<char *>(chunk.c_str())
        ),
        chunk.length()
    );

    bleTxCharacteristic->notify();

    offset += currentChunkLength;

    delay(30);
  }
}

// =====================================================
// PRINT CLEAN SERIAL OUTPUT
// =====================================================

void printReading(const SoilReading &reading) {
  Serial.println();
  Serial.println("========================");

  if (!reading.success) {
    Serial.print("Sensor communication error: 0x");

    if (reading.modbusError < 0x10) {
      Serial.print("0");
    }

    Serial.println(reading.modbusError, HEX);
    Serial.println("========================");
    return;
  }

  Serial.print("EC: ");
  Serial.print(reading.ecUsCm, 0);
  Serial.println(" uS/cm");

  Serial.print("pH: ");
  Serial.println(reading.pH, 1);

  Serial.print("Nitrogen: ");
  Serial.print(reading.nitrogenMgKg);
  Serial.println(" mg/kg");

  Serial.print("Phosphorus: ");
  Serial.print(reading.phosphorusMgKg);
  Serial.println(" mg/kg");

  Serial.print("Potassium: ");
  Serial.print(reading.potassiumMgKg);
  Serial.println(" mg/kg");

  Serial.println("========================");
}

// =====================================================
// SETUP
// =====================================================

void setup() {
  Serial.begin(115200);
  delay(1500);

  pinMode(RS485_DE_RE_PIN, OUTPUT);

  // Start MAX485 in receive mode
  digitalWrite(RS485_DE_RE_PIN, LOW);

  RS485Serial.begin(
      SENSOR_BAUD_RATE,
      SERIAL_8N1,
      RS485_RX_PIN,
      RS485_TX_PIN
  );

  soilSensor.begin(
      SENSOR_ADDRESS,
      RS485Serial
  );

  soilSensor.preTransmission(preTransmission);
  soilSensor.postTransmission(postTransmission);

  initializeBluetooth();

  Serial.println();
  Serial.println("5-in-1 soil sensor started");
  Serial.println("Sensor address: 2");
  Serial.println("Sensor baud rate: 9600");
  Serial.println("Waiting for readings...");
}

// =====================================================
// LOOP
// =====================================================

void loop() {
  // Restart Bluetooth advertising after disconnection
  if (!bleConnected && previousBleConnection) {
    delay(500);

    bleServer->startAdvertising();

    previousBleConnection = false;

    Serial.println(
        "Bluetooth advertising restarted"
    );
  }

  if (bleConnected && !previousBleConnection) {
    previousBleConnection = true;
  }

  uint32_t currentTime = millis();

  if (testRequested) {
    testRequested = false;
    samplesRemaining = SAMPLES_PER_TEST;
    lastReadingTime = 0;
  }

  if (bleConnected && samplesRemaining > 0 &&
      currentTime - lastReadingTime >= READING_INTERVAL_MS) {
    lastReadingTime = currentTime;

    SoilReading reading = readSoilSensor();

    printReading(reading);

    String json = createJson(reading);

    sendBluetoothMessage(json);
    samplesRemaining--;
  }

  delay(10);
}
