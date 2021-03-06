#!/usr/bin/perl

$debug = 0;
$uncached = "";
$buffer = "";


##Get possible uncached request from client.
$ENV{'REQUEST_METHOD'} =~ tr/a-z/A-Z/; 
if ($ENV{'REQUEST_METHOD'} eq "GET") {   
	$buffer = $ENV{'QUERY_STRING'};
	if ($buffer eq 'uncached') {
		if ($debug) { print "uncached data\n"; }
		$uncached = "/uncached";
	}
}

#$owwrite = '/mnt/usb/owfs/bin/owwrite -s 4444';
#$owget = '/mnt/usb/owfs/bin/owget -F -s 4444';
$owget = '/mnt/usb/owfs/bin/owread -F -s 4444';
$hvacStatsFile = "hvacStats.txt"; # path to hvac stats file for web read



##trigger convert_t << for when network grows enough...
#$trash = `$owwrite /sw1/main/simultaneous/temperature 1`;
#$trash = `$owwrite /sw2/main/simultaneous/temperature 1`;
#$trash = `$owwrite /sw3/main/simultaneous/temperature 1`;

#@sw1 = ('Attic', 'Basement', 'MasterBed'); #dont read Basement temp, get it from BasementH
@sw1 = ('Attic', 'MasterBed');
@sw1a = ('Outside');
@sw2 = ('Kitchen', 'Garage');
@sw2a = ('FrontBath', 'FrontBed', 'MasterBath', 'MiddleBed');
@sw3 = ('Utility');
#@sw3a = ('Hallway');


##grab regular temps
if ($debug) { $st_time = time(); }
foreach (@sw1) {
	$data{$_} = `$owget $uncached/sw1/main/$_/temperature11`;
	$data{$_} =~ s/^\s+//;
}
foreach (@sw1a) {
	$data{$_} = `$owget $uncached/sw1/aux/$_/temperature11`;
	$data{$_} =~ s/^\s+//;
}
foreach (@sw2) {
	$data{$_} = `$owget $uncached/sw2/main/$_/temperature11`;
	$data{$_} =~ s/^\s+//;
}
foreach (@sw2a) {                                                              
    $data{$_} = `$owget $uncached/sw2/aux/$_/temperature11`;               
    $data{$_} =~ s/^\s+//;                                                 
}
foreach (@sw3) {                                                                
	$data{$_} = `$owget $uncached/sw3/main/$_/temperature11`;
	$data{$_} =~ s/^\s+//;
}
if ($debug) { $en_time = time(); $t_time = $en_time-$st_time;  print "temp time = $t_time\n"; }

##grab hvac
##these numbers are rather messed up because of a ~30v ground difference between the furnace and the 1wire network.
##the logic here needs to be reworked also, its currently not valid for when the furnace is not being monitored, screweing up the long-term stats.
##^^investigate!
if ($debug) { $st_time = time(); }
$hvac{status} = "standby";
$hvacValA = `$owget $uncached/sw3/main/HVAC/volt.A`;
if ($hvacValA > 2) { $hvac{status} = "heating"; }
$hvacValB = `$owget $uncached/sw3/main/HVAC/volt.B`;
if ($hvacValB > 2) { $hvac{status} = "cooling"; }
#else { $hvac{status} = "standby"; }
if ($debug) { $en_time = time(); $t_time = $en_time-$st_time;  print "hvac time = $t_time\n"; }
if ($debug) { print "hvA=$hvacValA hvB=$hvacValB"}
	
##grab humidity & temp from DS2438 ~1s faster than DS18S20 on board
if ($debug) { $st_time = time(); }
$data{BasementH} = `$owget $uncached/sw1/main/BasementH/HIH4000/humidity`;
$data{BasementH} =~ s/^\s+//;
if ($debug) { $en_time = time(); $t_time = $en_time-$st_time;  print "humi time = $t_time\n"; }
if ($debug) { $st_time = time(); }
$data{Basement} = `$owget $uncached/sw1/main/BasementH/temperature`;
$data{Basement} =~ s/^\s+//;
if ($debug) { $en_time = time(); $t_time = $en_time-$st_time;  print "humi t time = $t_time\n"; }

##grab humidity & temp from DS2438 in Hallway
if ($debug) { $st_time = time(); }
$data{ThermostatH} = `$owget $uncached/sw3/aux/Hallway/HIH4000/humidity`;
$data{ThermostatH} =~ s/^\s+//;
if ($debug) { $en_time = time(); $t_time = $en_time-$st_time;  print "humi time = $t_time\n"; }
if ($debug) { $st_time = time(); }
$data{Thermostat} = `$owget $uncached/sw3/aux/Hallway/temperature`;
$data{Thermostat} =~ s/^\s+//;
if ($debug) { $en_time = time(); $t_time = $en_time-$st_time;  print "humi t time = $t_time\n"; }

my $hvacInfo = `cat $hvacStatsFile`;


##Sanitize##
for my $key (keys %data) {
	if ($data{$key} == 0) {
		$data{$key} = 'NaN';
	}
}

##OUTPUT##
#print "Content-type: text/html\r\n\r\n";

##output variables
print "startvar";
for my $key (keys %data) {
	my $val = sprintf("%.2f", $data{$key});
	print "&$key=$val";
};
for my $key (keys %hvac) {
	print "&HVAC$key=$hvac{$key}";
};
print $hvacInfo;
print "\n";

