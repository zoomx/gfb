#include <OneWire.h>
#include <DallasTemperature.h>

#define VDIV 0.09   // voltage divider modifier
#define VRANGE 0x00 // measured voltage range: 0x00 = 2.56v, 0x01 = 5.12v
#define REZ 0x08    // resolution: 1-16bit in hex

OneWire  ds(4);     // on pin 10

DeviceAddress addr1, HVAC;
int16_t ChA, ChB, ChC, ChD;
bool parasite;


void setup(void) 
{
  Serial.begin(9600);
  
  HVAC = { 0x20, 0x6F, 0xCD, 0x13, 0x0, 0x0, 0x0, 0x76 };
  parasite = 1;
    
  Configure_2450(HVAC, VRANGE, REZ);
}

void loop(void) 
{  
  printAddress(HVAC);
  Serial.println();
  
  ReadDS2450(HVAC);
  Serial.print("ChA = ");
  Serial.println(val2volt(ChA, VRANGE));
  
  Serial.print("ChB = ");
  Serial.println(val2volt(ChB, VRANGE));
  
  Serial.print("ChC = ");
  Serial.println(val2volt(ChC, VRANGE));
    
  Serial.print("ChD = ");
  Serial.println(val2volt(ChD, VRANGE));


  Serial.println();
  delay(500);
}


//convert measured value to volts
float val2volt(int val, int vrange)
{
  //if voltage range = 2.56v
  if(vrange == 0x00){
    return val / VDIV * 0.000039;
  }
  // if voltage range = 5.12v
  else if (vrange == 1) {
    return val / VDIV * 0.000078;
  }
}


// print a device address
void printAddress(DeviceAddress deviceAddress)
{
  for (uint8_t i = 0; i < 8; i++) {
    if (deviceAddress[i] < 16) Serial.print("0");
    Serial.print(deviceAddress[i], HEX);
    Serial.print(".");
  }
}

// convert and read all channels in order. remember that this can be more 
// efficient if you only want to read a couple of channels. As we go until 
// we hit the end of the 8byte memory area, if you have only one channel to 
// read, make it D, for two, C, etc.
void ReadDS2450(DeviceAddress deviceAddress)
{
  int HighByte, LowByte;
  
  ds.reset();
  ds.select(deviceAddress);   // select ds2450
  ds.write(0x3c, 0);          // convert
  ds.write(0x0f, 0);          // all channels
  ds.write(0xaa, parasite);   // preset to all zeros, parasite power on the end

  ds.read();                  //Read back 16 bit CRC
  ds.read();                  // which we're not interested in in this code!
  
  if (parasite) delay(10);    //delay for convert pull-up if parasite

  while(1)                    // check that conversion is complete
  {
    if(ds.read() == 0xff)
      break;
  }
 
  delay(1);
  ds.reset();
  ds.select(deviceAddress); // select ds2450
  ds.write(0xaa, 0);        // read memory
  ds.write(0x00, 0);        // start at channel A
  ds.write(0x00, 0);        // locations 0000 and 0001

  //Channel A
  LowByte = ds.read();      //Get the low byte (0 if running at 8 bit resolution)
  HighByte = ds.read();     //Get the high byte (the 8 bit value of the input)
  ChA = (((int16_t)HighByte <<8) | LowByte);

  //Channel B
  LowByte = ds.read();      //Get the low byte (0 if running at 8 bit resolution)
  HighByte = ds.read();     //Get the high byte (the 8 bit value of the input)
  ChB = (((int16_t)HighByte <<8) | LowByte);

  //Channel C
  LowByte = ds.read();      //Get the low byte (0 if running at 8 bit resolution)
  HighByte = ds.read();     //Get the high byte (the 8 bit value of the input)
  ChC = (((int16_t)HighByte <<8) | LowByte);

  //Channel D
  LowByte = ds.read();      //Get the low byte (0 if running at 8 bit resolution)
  HighByte = ds.read();     //Get the high byte (the 8 bit value of the input)
  ChD = (((int16_t)HighByte <<8) | LowByte);
}


// 8 bits @ 2.56v = 10mV per bit, 
// vrange is 0x01 for 5.12v or 0x00 for 2.56v
// rez is 0x01 to 0x0f for 1 to 15bits, 0x00 is 16bits
void Configure_2450(DeviceAddress deviceAddress, int vrange, int rez)
{  
  // Not needed if using parasite power
  if(!parasite) {
    ds.reset();
    ds.write(0xcc, 0);        // skip ROM, no parasite power on at the end
    ds.write(0x55, 0);        // Write memory
    ds.write(0x1c, 0);        // write to 001c
    ds.write(0x00, 0);        // Vcc operation
    ds.write(0x40, 0);        // "
    ds.read();                //Read back 16 bit CRC
    ds.read();                //"
    ds.read();                //Read back verification bits
  }
  
  
  ds.reset();
  ds.select(deviceAddress); // skip ROM, no parasite power on at the end
  ds.write(0x55,0);         // Write memory
  ds.write(0x08,0);         // write beginning at 0008 (Channel A Control/Status)
  ds.write(0x00,0);         // "


  ds.write(rez,0);          // 0008 (Channel A Control/Status) - 8 bits
  ds.read();                //Read back 16 bit CRC
  ds.read();                //"
  ds.read();                //Read back verification bits
  
  ds.write(vrange,0);       // 0009 (Channel A Control/Status) - VDC range
  ds.read();                //Read back 16 bit CRC
  ds.read();                //"
  ds.read();                //Read back verification bits
    
  ds.write(rez,0);          // 000A (Channel B Control/Status) - 8 bits
  ds.read();                //Read back 16 bit CRC
  ds.read();                //"
  ds.read();                //Read back verification bits
  
  ds.write(vrange,0);       // 000B (Channel B Control/Status) - VDC range
  ds.read();                //Read back 16 bit CRC
  ds.read();                //"
  ds.read();                //Read back verification bits
  
  ds.write(rez,0);          // 000C (Channel C Control/Status) - 8 bits
  ds.read();                //Read back 16 bit CRC
  ds.read();                //"
  ds.read();                //Read back verification bits
  
  ds.write(vrange,0);       // 000D (Channel C Control/Status) - VDC range
  ds.read();                //Read back 16 bit CRC
  ds.read();                //"
  ds.read();                //Read back verification bits
  
  ds.write(rez,0);          // 000E (Channel D Control/Status) - 8 bits
  ds.read();                //Read back 16 bit CRC
  ds.read();                //"
  ds.read();                //Read back verification bits
  
  ds.write(vrange,0);       // 000F (Channel D Control/Status) - VDC range
  ds.read();                //Read back 16 bit CRC
  ds.read();                //"
  ds.read();                //Read back verification bits
}
