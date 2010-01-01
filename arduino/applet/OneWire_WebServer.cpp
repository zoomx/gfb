#include <Ethernet2.h>
#include <OneWire.h>
#include <DallasTemperature.h>
#include <SoftwareSerial.h>
#include <SparkFunSerLCD.h>

#define LCD_REFRESH 10000

// Setup a oneWire instance
#include "WProgram.h"
void setup();
void loop();
boolean cycleCheck(unsigned long *lastMillis, unsigned int cycle);
void serviceWebClient(void);
void WebOutputTemps(Client client);
void lcdTempUpdate();
OneWire oneWire(4);
DallasTemperature sensors(&oneWire);

// Setup LCD
SparkFunSerLCD lcd(3,2,16);


DeviceAddress T1, T2, T3, T4, HVAC;
byte mac[] = { 0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xED };
byte ip[] = { 192, 168, 10, 177 };
unsigned long lastMillis = 0;

Server server(80);

void setup()
{
  Ethernet.begin(mac, ip);
  server.begin();
  sensors.begin();
  lcd.setup();
  
  T1 = { 0x10, 0x9F, 0x18, 0xFA, 0x01, 0x08, 0x0, 0x9B };
  T2 = { 0x10, 0xB4, 0x22, 0xFA, 0x01, 0x08, 0x0, 0xEC };
  T3 = { 0x10, 0x38, 0x27, 0xFA, 0x01, 0x08, 0x0, 0xA9 };
  T4 = { 0x10, 0x65, 0x37, 0xFA, 0x01, 0x08, 0x0, 0xB1 };
  HVAC = {};
  
  //seed LCD
  sensors.requestTemperatures();
  lcdTempUpdate();
}

void loop()
{
  serviceWebClient();
  
  if (cycleCheck(&lastMillis, LCD_REFRESH))
  {
    sensors.requestTemperatures();
    lcdTempUpdate();
  }
}



boolean cycleCheck(unsigned long *lastMillis, unsigned int cycle)
{
  unsigned long currentMillis = millis();
  if (currentMillis - *lastMillis >= cycle)
  {
    *lastMillis = currentMillis;
    return true;
  }
  else
    return false;
}


void serviceWebClient(void)
{
  Client client = server.available();
  if (client) {
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
               
          WebOutputTemps(client);
     
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

void WebOutputTemps(Client client)
{
  //Ask therms for temp readings
  sensors.requestTemperatures();
          
  //Update LCD as we have the data anyways...
  lcdTempUpdate();
          
  client.print("T1:");
  client.print(sensors.getTempF(T1));
  client.println("<br />");
  client.print("T2:");
  client.print(sensors.getTempF(T2));
  client.println("<br />");
  client.print("T3:");
  client.print(sensors.getTempF(T3));
  client.println("<br />");
  client.print("T4:");
  client.print(sensors.getTempF(T4));
  client.println("<br />");   
  client.print("HVAC:");
  client.print(sensors.getTempF(HVAC));
  client.println("<br />");  
}

void lcdTempUpdate()
{
  lcd.empty();
  
  //output T1
  lcd.at(1,1,"T1: ");
  if (sensors.isConnected(T1))
  {
    lcd.at(1,5,(int)sensors.getTempF(T1));
  }
  else
    lcd.at(1,5,"---");
    
  //output T2  
  lcd.at(1,9,"T2: ");
  if (sensors.isConnected(T2))
  {
    lcd.at(1,13,(int)sensors.getTempF(T2));
  }
  else
    lcd.at(1,13,"---");

  //putput T3
  lcd.at(2,1,"T3: ");
  if (sensors.isConnected(T3))
  {
    lcd.at(2,5,(int)sensors.getTempF(T3));
  }
  else
    lcd.at(2,5,"---");
  
  //output T4
  lcd.at(2,9,"T4: ");
    if (sensors.isConnected(T4))
  {
    lcd.at(2,13,(int)sensors.getTempF(T4));
  }
  else
    lcd.at(2,13,"---");

}

int main(void)
{
	init();

	setup();
    
	for (;;)
		loop();
        
	return 0;
}

