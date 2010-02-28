/*
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

    Copyright 2010 Guilherme Barros
*/

#include <stdlib.h>
#include <Ethernet2.h>
#include <OneWire.h>
#include <DallasTemperature.h>
#include <SoftwareSerial.h>
#include <SparkFunSerLCD.h>
#include <DS2450.h>

#define LCD_REFRESH 10000 // NO FASTER THAN 5s!!
#define REZ 9

#define PACHUBE_FEED_ID    5916
#define PACHUBE_API_KEY "1ed93c2b567f6ff8bd63e708e3c62b7fbd122ed6ee3db2fd8ef1c8cfca8518bb"


// Setup oneWire networkA
OneWire oneWireA(4);
DallasTemperature sensorsA(&oneWireA);

// Setup oneWire networkB
OneWire oneWireB(6);
DallasTemperature sensorsB(&oneWireB);

// Setup 2450
//ds2450 hvacMon(&oneWireA);

// Setup LCD
SparkFunSerLCD lcd(5,4,20);


DeviceAddress T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, HVAC;
//DeviceAddress HVAC = { 0x20, 0x6F, 0xCD, 0x13, 0x0, 0x0, 0x0, 0x76 };
float T1temp, T2temp, T3temp, T4temp, T5temp, T6temp, T7temp, T8temp, T9temp, T10temp;
char T1tempS[6], T2tempS[6], T3tempS[6], T4tempS[6], T5tempS[6], T6tempS[6], T7tempS[6], T8tempS[6], T9tempS[6], T10tempS[6];
int hvacVal = 0;

byte mac[] = { 0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xED };
byte ip[] = { 192, 168, 1, 80 };
byte pachubeServer[] = { 209, 40, 205, 190 };

unsigned long lastMillis = 0;
char buffer[32];
int foundDevices = 0;
char pachube_data[70];

Server server(80);
Client pachubeClient(pachubeServer, 80);


void setup()
{
  Ethernet.begin(mac, ip);
  server.begin();
  sensorsA.begin();
  sensorsB.begin();
  lcd.setup();
  lcd.bright(75);
  
  Serial.begin(9600);
  
  //0x10 == DS18S20  //0x28 == DS18B20
  //0x20 == DS2450   //0x1f == DS2409
  T1 = { 0x28, 0x38, 0x8C, 0x87, 0x02, 0x00, 0x0, 0xA8 }; //Attic
  T2 = { 0x28, 0x22, 0x8E, 0x87, 0x02, 0x00, 0x0, 0xBF }; //basement
  T3 = { 0x28, 0xED, 0x89, 0x87, 0x02, 0x00, 0x0, 0x55 }; //Master Bed
  T4 = { 0x10, 0x65, 0x37, 0xFA, 0x01, 0x08, 0x0, 0xB1 };
  T5 = { 0x28, 0xF5, 0x05, 0x06, 0x02, 0x00, 0x0, 0x13 }; //arduino local - netA
  T6 = { 0x28, 0xEB, 0xC9, 0x0E, 0x02, 0x00, 0x0, 0x44 }; //thermostat - netA
  T7 = { 0x28, 0xB2, 0x8E, 0x87, 0x02, 0x00, 0x0, 0x0E }; //outside
  T8 = { 0x28, 0x6E, 0xCC, 0x89, 0x00, 0x00, 0x0, 0x87 }; //kitchen - netA
  T9 = { 0x28, 0xC3, 0xAD, 0x87, 0x02, 0x00, 0x0, 0x17 }; //garage - netA
  T10 = { 0x28, 0x04, 0xB1, 0x87, 0x02, 0x0, 0x0, 0x50 }; 
  HVAC = { 0x20, 0x6F, 0xCD, 0x13, 0x0, 0x0, 0x0, 0x76 };
  
  //setup 2450 - HVAC, 2.56v, 8bit, parasite, vdiv
//  hvacMon.init(HVAC, 0, 8, 1, 0.9);
  
  //seed LCD
  runNetworkA();
  runNetworkB();
  lcd4TempUpdate();
}


void loop()
{
  serviceWebClient();
  
  if (cycleCheck(&lastMillis, LCD_REFRESH)) {
    Serial.println("in update cycle");
    //update lcd every LCD_REFRESH seconds
    runNetworkA();
    runNetworkB();
 //   hvacData();
    lcd4TempUpdate();
    makeStrings();
    pachube_out();
  }
}


boolean cycleCheck(unsigned long *lastMillis, unsigned int cycle)
{
  unsigned long currentMillis = millis();
  if (currentMillis - *lastMillis >= cycle) {
    *lastMillis = currentMillis;
    return true;
  }
  else
    return false;
}


void serviceWebClient(void)
{
  //Serial.print(".");
  Client client = server.available();
  if (client) {
    Serial.println("servicing web client");
    // an http request ends with a blank line
    boolean current_line_is_blank = true;
    while (client.connected()) {
      if (client.available()) {
        char c = client.read();
        if (c == '\n' && current_line_is_blank) {
          // send a standard http response header
          client.println("HTTP/1.1 200 OK");
          client.println("Content-Type: text/html");
          client.println();
          
          runNetworkA();
          runNetworkB();
 //         hvacData();
               
          WebOutputTemps(client);
          WebOutputDebug(client);
          
          //got the data, might as well use it...
          lcd4TempUpdate();
     
          break;
        }
        if (c == '\n') {
          // we're starting a new line
          current_line_is_blank = true;
        } else if (c != '\r') {
          // we've gotten a character on the current line
          current_line_is_blank = false;
        }
      }
    }
    // give the web browser time to receive the data
    delay(1);
    client.stop();
  }
}


//scan, convert_t on networkA
//we know netA has only the local and lcd DS18B20's in powered mode
void runNetworkA()
{
   //dtostrf(T6temp, 4, 1, buffer)
  Serial.println("in runNetworkA");
//  sensorsA.requestTemperatures();
  //do local
  sensorsA.setResolution(T5, REZ);
  sensorsA.requestTemperaturesByAddress(T5);
  T5temp = sensorsA.getTempF(T5);
  
  //do thermostat
  sensorsA.setResolution(T6, REZ);
  sensorsA.requestTemperaturesByAddress(T6);
  T6temp = sensorsA.getTempF(T6);
  
  //do kitchen
//  delay(200);
  sensorsA.setResolution(T8, REZ);
  sensorsA.requestTemperaturesByAddress(T8);
  T8temp = sensorsA.getTempF(T8);
  
  //do garage
  sensorsA.setResolution(T9, REZ);
  sensorsA.requestTemperaturesByAddress(T9);
  T9temp = sensorsA.getTempF(T9);
  
//  delay(200);
  //do basement
//  sensorsA.setResolution(T10, REZ);
//  sensorsA.requestTemperaturesByAddress(T10);
//  T10temp = sensorsA.getTempF(T10);
}


//scan, convet_t, etc on networkB
//go through remaining DS18's...
void runNetworkB()
{
  Serial.println("in runNetworkB");
  sensorsB.setResolution(T1, REZ);
  sensorsB.requestTemperaturesByAddress(T1);
  T1temp = sensorsB.getTempF(T1);
  
  sensorsB.setResolution(T2, REZ);
  sensorsB.requestTemperaturesByAddress(T2);
  T2temp = sensorsB.getTempF(T2);
  
  sensorsB.setResolution(T3, REZ);
  sensorsB.requestTemperaturesByAddress(T3);
  T3temp = sensorsB.getTempF(T3);
  
//  sensorsB.setResolution(T10, REZ);
//  sensorsB.requestTemperaturesByAddress(T10);
//  T10temp = sensorsB.getTempF(T10);
  
  sensorsB.setResolution(T7, REZ);
  sensorsB.requestTemperaturesByAddress(T7);
  T7temp = sensorsB.getTempF(T7);
}
  
  
void WebOutputDebug(Client client)
{
  DeviceAddress deviceAddress;
  
  client.println("------- <br />");
  client.print("Devices on netA (at boot): ");
  client.print(sensorsA.getDeviceCount(), DEC);
  client.println("<br />");
  client.print("Devices on netB (at boot): ");
  client.print(sensorsB.getDeviceCount(), DEC);
  client.println("<br />");

  // Loop through netA, print out address
  client.println("--netA--<br />");
  for(int i=0;i<5; i++) {
    // Search the wire for address
    if(sensorsA.getAddress(deviceAddress, i)) {
      client.print("Found device ");
      client.print(i, DEC);
      client.print(" -- ");
      printAddress(deviceAddress, client);

      client.print(" -- temp: ");
      client.print(dtostrf(sensorsA.getTempF(deviceAddress), 5, 2, buffer));
      client.print("F, ");
      client.print(dtostrf(sensorsA.getTempC(deviceAddress), 5, 2, buffer));
      client.println("C <br />");
    }
  } 
  // Loop through netB, print out address
  client.println("--netB--<br />");
  for(int i=0;i<10; i++) {
    // Search the wire for address
    if(sensorsB.getAddress(deviceAddress, i)) {
      client.print("Found device ");
      client.print(i, DEC);
      client.print(" -- ");
      printAddress(deviceAddress, client);
      
      delay(100);

      client.print(" -- temp: ");
      client.print(dtostrf(sensorsB.getTempF(deviceAddress), 5, 2, buffer));
      client.print("F, ");
      client.print(dtostrf(sensorsB.getTempC(deviceAddress), 5, 2, buffer));
      client.println("C <br />");
      delay(100);
    }
  } 
  client.print("last pachube_data: ");
  client.println(pachube_data);
  client.print("\nuptime: ");
  client.println(millis());
}
/*
void hvacData()
{
  Serial.println("in hvacData");
  //if heating, set +10, if cooling -10
  hvacMon.reading();
  if(hvacMon.voltChD() >= 20)
    hvacVal = 10;
  else if (hvacMon.voltChC() >= 20)
    hvacVal = -10;
}*/

void makeStrings()
{ //dtostrf(T6temp, 4, 1, buffer)
  T1tempS = dtostrf(T1temp, 4, 1, buffer);
  T2tempS = dtostrf(T2temp, 4, 1, buffer);
  T3tempS = dtostrf(T3temp, 4, 1, buffer);
  T4tempS = dtostrf(T4temp, 4, 1, buffer);
  T5tempS = dtostrf(T5temp, 4, 1, buffer);
  T6tempS = dtostrf(T6temp, 4, 1, buffer);
  T7tempS = dtostrf(T7temp, 4, 1, buffer);
  T8tempS = dtostrf(T8temp, 4, 1, buffer);
  T9tempS = dtostrf(T9temp, 4, 1, buffer);
  T10tempS = dtostrf(T10temp, 4, 1, buffer);
}

// print a device address to serial
void printAddress(DeviceAddress deviceAddress, Client client)
{
  for (uint8_t i = 0; i < 8; i++) {
    if (deviceAddress[i] < 16) client.print("0");
    client.print(deviceAddress[i], HEX);
    client.print(".");
  }
}

