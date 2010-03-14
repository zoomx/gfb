#include <OneWire.h>
#include <DS2423.h>

DeviceAddress counter = { 0x1D, 0xF4, 0xCB, 0x0F, 0x0, 0x0, 0x0, 0xA5 };

OneWire ow(4);
ds2423 myCounter(&ow, counter);


void setup(void)
{
  Serial.begin(9600);
}

void loop(void)
{ 
  Serial.print("Counter A: ");
  Serial.println(myCounter.readCounter(1));
  Serial.print("Counter B: ");
  Serial.println(myCounter.readCounter(2));
  
  Serial.println();
}
