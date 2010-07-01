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
#include <DS2409.h>

#define LCD_REFRESH 10000 // NO FASTER THAN 5s!!
#define REZ 9

#define BRIGHT 75

#define PACHUBE_FEED_ID    5916
#define PACHUBE_API_KEY "1ed93c2b567f6ff8bd63e708e3c62b7fbd122ed6ee3db2fd8ef1c8cfca8518bb"


DeviceAddress T1, T2, T3, T4, T5, T6, T7, T8, T9, T10;
float T1temp, T2temp, T3temp, T4temp, T5temp, T6temp, T7temp, T8temp, T9temp, T10temp;
char T1tempS[8], T2tempS[8], T3tempS[8], T4tempS[8], T5tempS[8], T6tempS[8], T7tempS[8], T8tempS[8], T9tempS[8], T10tempS[8];
int hvacVal = 0;
DeviceAddress sw1 = { 0x1f, 0x70, 0x66, 0x05, 0x00, 0x00, 0x00, 0x2d };
DeviceAddress sw2 = { 0x1f, 0x9d, 0x67, 0x05, 0x00, 0x00, 0x00, 0x83 };
DeviceAddress sw3 = { 0x1f, 0x4b, 0x67, 0x05, 0x00, 0x00, 0x00, 0xf5 };
DeviceAddress HVAC = { 0x20, 0x6F, 0xCD, 0x13, 0x0, 0x00, 0x00, 0x76 };

// Setup oneWire networkA
OneWire oneWireA(4);
DallasTemperature sensorsA(&oneWireA);

// Setup oneWire networkB - switched network
OneWire oneWireB(6);
DallasTemperature sensorsB(&oneWireB);

// Setup 2409 Switch
ds2409 owSwitch(&oneWireB, sw1, sw2, sw3);

//Setup 2450 HVAC Monitor
ds2450 hvacMon(&oneWireB, HVAC, 0, 8, 1, 0.09);

// Setup LCD
SparkFunSerLCD lcd(5,4,20);




byte mac[] = { 0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xED };
byte ip[] = { 192, 168, 1, 80 };
//byte pachubeServer[] = { 209, 40, 205, 190 }; // changed June 30th 2010
byte pachubeServer[] = { 173, 203, 98, 29 };
byte webCheckServer[] = { 192, 168, 1, 7 };

unsigned long lastMillis = 0;
unsigned long lastBlinkMillis = 0;
bool blinker = true;
char buffer[32];
int foundDevices = 0;
char csv_data[70];

Server webServer(80);
Client pachubeClient(pachubeServer, 80);
Client webCheckClient(webCheckServer, 80);



void setup()
{
  Ethernet.begin(mac, ip);
  webServer.begin();
  sensorsA.begin();
  sensorsB.begin();
  lcd.setup();
  lcd.bright(BRIGHT);
  hvacMon.begin();
  
  Serial.begin(9600);
  
  //0x10 == DS18S20  //0x28 == DS18B20
  //0x20 == DS2450   //0x1f == DS2409
  T1 = { 0x28, 0x38, 0x8C, 0x87, 0x02, 0x00, 0x0, 0xA8 }; //Attic
  T2 = { 0x28, 0x22, 0x8E, 0x87, 0x02, 0x00, 0x0, 0xBF }; //basement
  T3 = { 0x28, 0xED, 0x89, 0x87, 0x02, 0x00, 0x0, 0x55 }; //Master Bed
  T4 = { 0x10, 0x65, 0x37, 0xFA, 0x01, 0x08, 0x0, 0xB1 };
  T5 = { 0x28, 0xF5, 0x05, 0x06, 0x02, 0x00, 0x0, 0x13 }; //arduino local - netA
  T6 = { 0x28, 0xEB, 0xC9, 0x0E, 0x02, 0x00, 0x0, 0x44 }; //thermostat - netA
  T7 = { 0x28, 0xB2, 0x8E, 0x87, 0x02, 0x00, 0x0, 0x0E }; //decomissioned
  T8 = { 0x28, 0x6E, 0xCC, 0x89, 0x00, 0x00, 0x0, 0x87 }; //kitchen - netA
  T9 = { 0x28, 0xC3, 0xAD, 0x87, 0x02, 0x00, 0x0, 0x17 }; //garage - netA
  T10 = { 0x28, 0x04, 0xB1, 0x87, 0x02, 0x0, 0x0, 0x50 }; //outside

  
  T4temp = DEVICE_DISCONNECTED;
  T7temp = DEVICE_DISCONNECTED;
  T10temp = DEVICE_DISCONNECTED;
  
  //seed LCD
  runNetworkA();
  runNetworkB();
  massageVars();
  lcd4TempUpdate();
}


void loop()
{
  serviceWebClient();
  
  
  //check that the rrd site is up and blink the backlight if not
  //make sure to leave the backlight on if the site checks out.
  if (blinkCheck(&lastBlinkMillis, 1000)) {
    if ( !webCheck() ) {
      if (blinker) {
        lcd.bright(0);
        blinker = false;
      }
      else {
        lcd.bright(BRIGHT);
        blinker = true;
      }
    }
    else {
      lcd.bright(BRIGHT);
    }
  }
    
  
  if (cycleCheck(&lastMillis, LCD_REFRESH)) {
    Serial.println("in update cycle");
    //update lcd every LCD_REFRESH seconds
    runNetworkA();
    runNetworkB();
    massageVars();
    lcd4TempUpdate();
    pachube_out();      
  }
}

boolean blinkCheck(unsigned long *lastBlinkMillis, unsigned int cycle)
{
  unsigned long currentMillis = millis();
  if (currentMillis - *lastBlinkMillis >= cycle) {
    *lastBlinkMillis = currentMillis;
    return true;
  }
  else
    return false;
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
  Client client = webServer.available();
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
          
//get data only every 15s
//          runNetworkA();
//          runNetworkB();
               
          WebOutputTemps(client);
//          WebOutputDebug(client);
     
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
  sensorsA.setResolution(T8, REZ);
  sensorsA.requestTemperaturesByAddress(T8);
  T8temp = sensorsA.getTempF(T8);
  
  //do garage
  sensorsA.setResolution(T9, REZ);
  sensorsA.requestTemperaturesByAddress(T9);
  T9temp = sensorsA.getTempF(T9);
}


//scan, convet_t, etc on networkB
//go through remaining DS18's...
void runNetworkB()
{
  Serial.println("in runNetworkB");
  owSwitch.port(0); // Chan1-Main
  Serial.println("port 0");
  sensorsB.setResolution(T1, REZ);
  sensorsB.requestTemperaturesByAddress(T1);
  T1temp = sensorsB.getTempF(T1);
  
  sensorsB.setResolution(T2, REZ);
  sensorsB.requestTemperaturesByAddress(T2);
  T2temp = sensorsB.getTempF(T2);
  
  sensorsB.setResolution(T3, REZ);
  sensorsB.requestTemperaturesByAddress(T3);
  T3temp = sensorsB.getTempF(T3);
  
  
  owSwitch.port(2); // Chan2-Main
  Serial.println("port 2");
  sensorsB.setResolution(T10, REZ);
  sensorsB.requestTemperaturesByAddress(T10);
  T10temp = sensorsB.getTempF(T10);
  
  
  owSwitch.port(4); // Chan3-Main
  Serial.println("port 4");
  hvacData();
}
  


void hvacData()
{
  Serial.println("in hvacData");
  //if heating, set +10, if cooling -10
  hvacMon.measure();
  if(hvacMon.voltChB() >= 2.0)
    hvacVal = -10;
  else if (hvacMon.voltChA() >= 2.0)
    hvacVal = 10;
  else
    hvacVal = 0;
/*    
  Serial.print("hvacVal = ");
  Serial.println(hvacVal);
  Serial.print("ChA = ");
  Serial.println(hvacMon.voltChA());
  Serial.print("ChB = ");
  Serial.println(hvacMon.voltChB());
*/
}

void massageVars()
{
  strcpy(T1tempS, dtostrf(T1temp, 4, 1, buffer));
  strcpy(T2tempS, dtostrf(T2temp, 4, 1, buffer));
  strcpy(T3tempS, dtostrf(T3temp, 4, 1, buffer));
  strcpy(T4tempS, dtostrf(T4temp, 4, 1, buffer));
  strcpy(T5tempS, dtostrf(T5temp, 4, 1, buffer));
  strcpy(T6tempS, dtostrf(T6temp, 4, 1, buffer));
  strcpy(T7tempS, dtostrf(T7temp, 4, 1, buffer));
  strcpy(T8tempS, dtostrf(T8temp, 4, 1, buffer));
  strcpy(T9tempS, dtostrf(T9temp, 4, 1, buffer));
  strcpy(T10tempS, dtostrf(T10temp, 4, 1, buffer));
  
  sprintf(csv_data, "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%d", 
  T1tempS,T2tempS,T3tempS,T4tempS,T5tempS,T6tempS,T7tempS,T8tempS,T9tempS,T10tempS,hvacVal
  );
}


bool webCheck()
{
  Serial.print("Checking RRD site... ");
  if (webCheckClient.connect()) {
    Serial.println("connected");
    webCheckClient.stop();
    return true;
  }
  else {
    Serial.println("rrd site unavailable!");
    webCheckClient.stop();
    return false;
  }
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
