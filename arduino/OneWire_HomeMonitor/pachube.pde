char pachube_data[70];

void pachube_out()
{
  Serial.println("Connecting...");
  if (pachubeClient.connect()) {
    sprintf(pachube_data, "%f,%f,%f,%f,%f,%f,%f,%f,%f,%f", T1temp,T2temp,T3temp,T4temp,T5temp,T6temp,T7temp,T8temp,T9temp,T10temp);

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
    Serial.println("disconnecting...");
    pachubeClient.stop();
  } 
  else {
    Serial.print("connection failed!");
    //pachube_out();
  }
}

