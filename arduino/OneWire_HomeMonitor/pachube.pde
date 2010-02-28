

void pachube_out()
{
  Serial.print("Connecting to pachube... ");
  if (pachubeClient.connect()) {
    Serial.println("connected");
 
 //dtostrf(T6temp, 4, 1, buffer)
    sprintf(pachube_data, "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s", 
    dtostrf(T1temp, 4, 1, buffer), dtostrf(T2temp, 4, 1, buffer), dtostrf(T3temp, 4, 1, buffer),
    dtostrf(T4temp, 4, 1, buffer), dtostrf(T5temp, 4, 1, buffer), dtostrf(T6temp, 4, 1, buffer),
    dtostrf(T7temp, 4, 1, buffer), dtostrf(T8temp, 4, 1, buffer), dtostrf(T9temp, 4, 1, buffer),    dtostrf(T10temp, 4, 1, buffer)
//    T1temp,T2temp,T3temp,T4temp,T5temp,T6temp,T7temp,T8temp,T9temp,T10temp
    ); // ohboy is this ugly... though the other option is using ram instead...
    Serial.println(T1temp);

    Serial.print("sending: ");
    Serial.println(pachube_data);

    pachubeClient.print("PUT /api/");
    pachubeClient.print(PACHUBE_FEED_ID);
    pachubeClient.print(".csv HTTP/1.1\nHost: pachube.com\nX-PachubeApiKey: ");
    pachubeClient.print(PACHUBE_API_KEY);
    pachubeClient.print("\nUser-Agent: Arduino");
    pachubeClient.print("\nContent-Type: text/csv\nContent-Length: ");
    pachubeClient.print(strlen(pachube_data));
    pachubeClient.print("\nConnection: close\n\n");
    pachubeClient.print(pachube_data);
    pachubeClient.print("\n");

    //disconnecting
    delay(10); // play with this...
    Serial.println("disconnecting...\n");
    pachubeClient.stop();
  } 
  else {
    Serial.println("connection failed!\n");
    //pachube_out(); // retry?
  }
}

