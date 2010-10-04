#include <Servo.h> 
 
Servo servo1, servo2, servo3, servo4;
const int buttonPin = 2;

int pos = 0;          // variable to store the servo position 
int buttonState = 0;  // variable for reading the pushbutton status

void setup() 
{ 
  // attaches the servo on the digital pin to the servo object 
  servo1.attach(8); 
  servo2.attach(9); 
  servo3.attach(10); 
  servo4.attach(11); 
  
  pinMode(buttonPin, INPUT);
} 
 
 
void loop() 
{ 
  //read the state of the button
  buttonState = digitalRead(buttonPin); 
  
  //start the sweep if button is pressed
  if (buttonState == HIGH) {
    sweepServos();
  }

} 

void sweepServos()
{
  for(pos = 0; pos < 180; pos += 1) { // goes from 0 degrees to 180 degrees 
    servo1.write(pos);                // tell servo to go to position in variable 'pos' 
    servo2.write(pos);
    servo3.write(pos);
    servo4.write(pos);
    delay(15);                        // waits 15ms for the servo to reach the position 
  } 
  for(pos = 180; pos>=1; pos-=1) {    // goes from 180 degrees to 0 degrees 
    servo1.write(pos);                // tell servo to go to position in variable 'pos' 
    servo2.write(pos);
    servo3.write(pos);
    servo4.write(pos);
    delay(15);                        // waits 15ms for the servo to reach the position 
  }
}
