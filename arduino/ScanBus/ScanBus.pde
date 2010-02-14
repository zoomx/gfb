#include <OneWire.h>
#include <DallasTemperature.h>

OneWire oneWire(4);
DallasTemperature sensors(&oneWire);

void setup(void)
{
  Serial.begin(9600);
  sensors.begin();
  
  Serial.print("Parasite power is: "); 
  if (sensors.isParasitePowerMode()) Serial.println("ON");
  else Serial.println("OFF");
}

void loop(void)
{ 
  Serial.print("Requesting temperatures...");
  sensors.requestTemperatures(); // Send the command to get temperatures
  Serial.println("DONE");
  
  DeviceAddress deviceAddress;
  for (int id = 0; id<10; id++)
  {
    //find address and check if there is a device at that index
    if (!sensors.getAddress(deviceAddress, id))
      break;
    printAddress(deviceAddress);
    Serial.print(" ");
    Serial.println(sensors.getTempFByIndex(id));

  }
  Serial.println();
  Serial.println();
}
  
// function to print a device address
void printAddress(DeviceAddress deviceAddress)
{
  for (uint8_t i = 0; i < 8; i++)
  {
    if (deviceAddress[i] < 16) Serial.print("0");
    Serial.print(deviceAddress[i], HEX);
    Serial.print(".");
  }
}

