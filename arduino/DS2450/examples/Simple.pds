#include <OneWire.h>
#include <DS2450.h>

DeviceAddress HVAC;

OneWire oneWire(4);
ds2450 my2450(&oneWire);

void setup(void) {
  Serial.begin(9600);
  
  HVAC = { 0x20, 0x6F, 0xCD, 0x13, 0x0, 0x0, 0x0, 0x76 };
  int vrange = 0;        // 0 = 2.56v, 1 = 5.12v
  int rez = 8;           // rez = 0-f bits where 0 = 16
  bool parasite = 1;
  float vdiv = 0.9;      // voltage divider circuit value?
  
  my2450.init(HVAC, vrange, rez, parasite, vdiv);
}

void loop(void) {
  my2450.reading();
  Serial.print("chA = ");
  Serial.println((int)my2450.voltChA());
  
}
