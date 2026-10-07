
const int GAS_PIN = A0;
const int VOLT_PIN = A1;
const int BUZZER_PIN = 8;
const int MOTOR_PIN = 9;
const int LED_PIN = 13;

const int VOLTAGE_THRESHOLD = 8.0;  
const int GAS_THRESHOLD = 300;        // EQUALS TO 1.45V

bool manualTrigger = false;

void setup() {
  Serial.begin(9600);
  pinMode(BUZZER_PIN, OUTPUT);
  pinMode(MOTOR_PIN, OUTPUT);

  digitalWrite(BUZZER_PIN, LOW);
  digitalWrite(MOTOR_PIN, LOW);
}

void loop() {
  int rawGas = analogRead(GAS_PIN);
  int rawVolt = analogRead(VOLT_PIN);

  // Convert TO THE  0-12V system 
  float actualVoltage = (rawVolt * (5.0 / 1023.0)) * 2.5;

  // Read serial commands from MATLAB GUI or Virtual Terminal
  if (Serial.available() > 0) {
    char cmd = Serial.read();
    if (cmd == '1') manualTrigger = true;
    if (cmd == '0') manualTrigger = false;
  }

  // Telemetry Stream: "Voltage,Gas"
  Serial.print(actualVoltage, 2);
  Serial.print(",");
  Serial.println(rawGas);

  // CHECK THRESHOLDS
  bool isGasAlarm = (rawGas >= GAS_THRESHOLD);
  bool isVoltAlarm = (actualVoltage >= VOLTAGE_THRESHOLD);

  // Trigger outputs
  if (isGasAlarm || isVoltAlarm || manualTrigger) {
    digitalWrite(BUZZER_PIN, HIGH);
    digitalWrite(MOTOR_PIN, HIGH);
  } else {
    digitalWrite(BUZZER_PIN, LOW);
    digitalWrite(MOTOR_PIN, LOW);
    digitalWrite(LED_PIN, LOW);
  }

  delay(100);
}