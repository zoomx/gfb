#include <stdlib.h>
#include <Ethernet2.h>
#include <OneWire.h>
#include <DallasTemperature.h>
#include <SoftwareSerial.h>
#include <SparkFunSerLCD.h>

#define LCD_REFRESH 10000

// Setup a oneWire instance
OneWire oneWire(4);
DallasTemperature sensors(&oneWire);

// Setup LCD
//SparkFunSerLCD lcd(5,2,16);
SparkFunSerLCD lcd(5,4,20);


DeviceAddress T1, T2, T3, T4, T5, T6, T7, HVAC;
byte mac[] = { 0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xED };
byte ip[] = { 192, 168, 1, 80 };
//byte gateway[] = { 192, 168, 1, 1 };
//byte subnet[] = { 255, 255, 255, 0 };
unsigned long lastMillis = 0;
char buffer[32];
int foundDevices = 0;

Server server(80);

void setup()
{
  Ethernet.begin(mac, ip);
  server.begin();
  sensors.begin();
  lcd.setup();
//  lcd.bright(75);
  
  //0x10 == DS18S20
  //0x28 == DS18B20
  T1 = { 0x28, 0x38, 0x8C, 0x87, 0x02, 0x00, 0x0, 0xA8 };
  T2 = { 0x10, 0xB4, 0x22, 0xFA, 0x01, 0x08, 0x0, 0xEC }; //Attic?
  T3 = { 0x28, 0xED, 0x89, 0x87, 0x02, 0x00, 0x0, 0x55 }; //Master Bed
  T4 = { 0x10, 0x65, 0x37, 0xFA, 0x01, 0x08, 0x0, 0xB1 };
  T5 = { 0x28, 0xF5, 0x05, 0x06, 0x02, 0x00, 0x0, 0x13 }; //arduino local
  T6 = { 0x28, 0xEB, 0xC9, 0x0E, 0x02, 0x00, 0x0, 0x44 }; //thermostat
  T7 = { 0x28, 0xB2, 0x8E, 0x87, 0x02, 0x00, 0x0, 0x0E }; //outside
  HVAC = {};
  
  //seed LCD
//  sensors.requestTemperatures();
  ReqTempSeq();
  lcd4TempUpdate();
}

void loop()
{
  serviceWebClient();
  
  if (cycleCheck(&lastMillis, LCD_REFRESH))
  {
    //update lcd every LCD_REFRESH seconds
    //sensors.requestTemperatures();
    ReqTempSeq();
    lcd4TempUpdate();
  }
}


//sequentially sets resolution to 10bits and requests temps
//for first 10 therms and really finds number of devices on network
void ReqTempSeq()
{
  DeviceAddress deviceAddress;
  foundDevices = 0;
  for (int id = 0; id<10; id++)
  {
    //find address and check if there is a device at that index
    if (!sensors.getAddress(deviceAddress, id))
      break;
    sensors.setResolution(deviceAddress, 9);
    sensors.requestTemperaturesByAddress(deviceAddress);
    foundDevices++;
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
          
//          sensors.requestTemperatures();
          ReqTempSeq();
               
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

void WebOutputDebug(Client client)
{
  float tempF;
  DeviceAddress DeviceAddress;
  
  client.println("------- <br />");
  client.print("Devices at boot: ");
  client.print(sensors.getDeviceCount(), DEC);
  client.println("<br />");
  client.print("Devices at last convert_t: ");
  client.print(foundDevices);
  client.println("<br />");

    // Loop through first ten, print out address
  for(int i=0;i<10; i++)
  {
    // Search the wire for address
    if(sensors.getAddress(DeviceAddress, i))
    {
      client.print("Found device ");
      client.print(i, DEC);
      client.print(" -- ");
      printAddress(DeviceAddress, client);

      client.print(" -- temp: ");
      tempF = sensors.getTempF(DeviceAddress);
      client.print(dtostrf(tempF, 5, 2, buffer));
      client.println("<br />");
    }
  } 
  client.print("uptime: ");
  client.println(millis());
}

void WebOutputTemps(Client client)
{
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
  client.print("T5:");
  client.print(sensors.getTempF(T5));
  client.println("<br />");
  client.print("T6:");
  client.print(sensors.getTempF(T6));
  client.println("<br />"); 
  client.print("T7:");
  client.print(sensors.getTempF(T7));
  client.println("<br />");
  client.print("HVAC:");
  client.print(sensors.getTempF(HVAC));
  client.println("<br />");  
}

void lcd2TempUpdate()
{
  lcd.empty();
  
  //output T5
  lcd.at(1,1,"T5: ");
  if (sensors.isConnected(T5))
    lcd.at(1,5,(int)sensors.getTempF(T5));
  else
    lcd.at(1,5,"---");
    
  //output T6
  lcd.at(1,9,"T6: ");
  if (sensors.isConnected(T6))
    lcd.at(1,13,(int)sensors.getTempF(T6));
  else
    lcd.at(1,13,"---");

  //putput T7
  lcd.at(2,1,"T7: ");
  if (sensors.isConnected(T7))
    lcd.at(2,5,(int)sensors.getTempF(T7));
  else
    lcd.at(2,5,"---");
  
  //output T3
  lcd.at(2,9,"T3: ");
  if (sensors.isConnected(T3))
    lcd.at(2,13,(int)sensors.getTempF(T3));
  else
    lcd.at(2,13,"---");
}


void lcd4TempUpdate()
{
//  lcd.empty();
  
  //line 1
  lcd.at(1,1, "Here:");
  if (sensors.isConnected(T6))
    lcd.at(1,6, dtostrf(sensors.getTempF(T6), 4, 1, buffer));
  else
    lcd.at(1,6, "----");
 
  lcd.at(1,11, "Util:");
  if (sensors.isConnected(T5))
    lcd.at(1,16, dtostrf(sensors.getTempF(T5), 4, 1, buffer));
  else
    lcd.at(1,16, "----");
    
  //line 2
  lcd.at(2,1, "MBed:");
  if (sensors.isConnected(T3))
    lcd.at(2,6, dtostrf(sensors.getTempF(T3), 4, 1, buffer));
  else
    lcd.at(2,6, "----");
 
  lcd.at(2,11, "Grge:");
  if (sensors.isConnected(T1))
    lcd.at(2,16, dtostrf(sensors.getTempF(T1), 4, 1, buffer));
  else
    lcd.at(2,16, "----");
    
  //line 3
  lcd.at(3,1, "Kitc:");
  if (sensors.isConnected(T1))
    lcd.at(3,6, dtostrf(sensors.getTempF(T1), 4, 1, buffer));
  else
    lcd.at(3,6, "----");
 
  lcd.at(3,11, "Bsmt:");
  if (sensors.isConnected(T1))
    lcd.at(3,16, dtostrf(sensors.getTempF(T1), 4, 1, buffer));
  else
    lcd.at(3,16, "----");
        
  //line 4
  lcd.at(4,1, "Attc:");
  if (sensors.isConnected(T2))
    lcd.at(4,6, dtostrf(sensors.getTempF(T2), 4, 1, buffer));
  else
    lcd.at(4,6, "----");
    
  lcd.at(4,11, "Out:");
  if (sensors.isConnected(T7))
    lcd.at(4,16, dtostrf(sensors.getTempF(T7), 4, 1, buffer));
  else
    lcd.at(4,16, "----");
}


// print a device address to serial
void printAddress(DeviceAddress deviceAddress, Client client)
{
  for (uint8_t i = 0; i < 8; i++)
  {
    if (deviceAddress[i] < 16) client.print("0");
    client.print(deviceAddress[i], HEX);
    client.print(".");
  }
}
