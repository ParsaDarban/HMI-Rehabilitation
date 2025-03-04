// Define input pin
const int inputPin = A2; // Analog input pin

void setup() {
    Serial.begin(9600); // Start serial communication
}

void loop() {
    float sensorValue = 500*analogRead(inputPin); // Read analog input (0-1023)

    // Send the sensor data to MATLAB
    Serial.println(sensorValue);
   
    // No delay for faster data streaming
  delay(200);
}
