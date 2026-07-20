#include <ModbusMaster.h>

// =====================================================
// ESP32 DEV MODULE TO MAX485
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

#define RS485_RX_PIN       17
#define RS485_TX_PIN       16
#define RS485_DE_RE_PIN     4

// Sensor settings discovered during scanning
#define SENSOR_ADDRESS      2
#define SENSOR_BAUD_RATE  9600

// Register mapping discovered from your sensor
#define START_REGISTER  0x0002
#define REGISTER_COUNT       6

// Delay between readings
#define READING_INTERVAL_MS 3000

HardwareSerial RS485Serial(2);
ModbusMaster soilSensor;

// Switch MAX485 into transmit mode
void preTransmission() {
  digitalWrite(RS485_DE_RE_PIN, HIGH);
  delayMicroseconds(200);
}

// Switch MAX485 into receive mode
void postTransmission() {
  delayMicroseconds(200);
  digitalWrite(RS485_DE_RE_PIN, LOW);
}

void printModbusError(uint8_t errorCode) {
  Serial.print("Sensor communication error: 0x");

  if (errorCode < 0x10) {
    Serial.print("0");
  }

  Serial.println(errorCode, HEX);
}

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

  Serial.println();
  Serial.println("==============================");
  Serial.println("5-in-1 Soil Sensor Started");
  Serial.println("Sensor address: 2");
  Serial.println("Sensor baud rate: 9600");
  Serial.println("==============================");
}

void loop() {
  soilSensor.clearResponseBuffer();

  /*
   * Registers read:
   *
   * 0x0002 = EC
   * 0x0003 = unused
   * 0x0004 = Nitrogen
   * 0x0005 = Phosphorus
   * 0x0006 = Potassium
   * 0x0007 = pH × 10
   */

  uint8_t result = soilSensor.readHoldingRegisters(
    START_REGISTER,
    REGISTER_COUNT
  );

  if (result == ModbusMaster::ku8MBSuccess) {
    uint16_t ec =
      soilSensor.getResponseBuffer(0);

    uint16_t nitrogen =
      soilSensor.getResponseBuffer(2);

    uint16_t phosphorus =
      soilSensor.getResponseBuffer(3);

    uint16_t potassium =
      soilSensor.getResponseBuffer(4);

    uint16_t rawPH =
      soilSensor.getResponseBuffer(5);

    float pH = rawPH / 10.0f;

    Serial.println();
    Serial.println("========================");

    Serial.print("EC: ");
    Serial.print(ec);
    Serial.println(" uS/cm");

    Serial.print("pH: ");
    Serial.println(pH, 1);

    Serial.print("Nitrogen: ");
    Serial.print(nitrogen);
    Serial.println(" mg/kg");

    Serial.print("Phosphorus: ");
    Serial.print(phosphorus);
    Serial.println(" mg/kg");

    Serial.print("Potassium: ");
    Serial.print(potassium);
    Serial.println(" mg/kg");

    Serial.println("========================");
  } else {
    Serial.println();
    printModbusError(result);
  }

  delay(READING_INTERVAL_MS);
}