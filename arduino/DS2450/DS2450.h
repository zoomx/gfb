#ifndef DS2450_h
#define DS2450_h

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
*/



#include <OneWire.h>

#define DS2450MODEL 0x20

#define CONVERT     0x3c
#define ALLCHANNELS 0x0f
#define PRESETZERO  0xaa
#define READMEM     0xaa
#define WRITEMEM    0x55
#define SKIPROM     0xcc

typedef uint8_t DeviceAddress[8];

class ds2450
{
  public:
    ds2450(OneWire*);
    void init(uint8_t*, int8_t, int8_t, bool, float);
    void reading(void);
    float voltChA(void);
    float voltChB(void);
    float voltChC(void);
    float voltChD(void);

  private:
    bool _parasite;
    OneWire* _wire;
    uint8_t* _deviceAddress;
    int _ChA, _ChB, _ChC, _ChD;
    int8_t _vrange, _rez, _vdiv;
    float _calculateVoltage(int);
};
#endif
