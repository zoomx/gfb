#!/usr/bin/perl

# 10 therms checked every 1 min, -50min, 150max
# 1 hvac checked every 1 min, -10min (cool), 10max (heat) (0 is off)
#
# 1min interval saved for 2 years
#
## rrd created with:
#rrdtool create filename.rrd \
#--step '60' \
#--start '1230768000' \
#'DS:T1:GAUGE:600:-50:150' \
#'DS:T2:GAUGE:600:-50:150' \
#'DS:T3:GAUGE:600:-50:150' \
#'DS:T4:GAUGE:600:-50:150' \
#'DS:T5:GAUGE:600:-50:150' \
#'DS:T6:GAUGE:600:-50:150' \
#'DS:T7:GAUGE:600:-50:150' \
#'DS:T8:GAUGE:600:-50:150' \
#'DS:T9:GAUGE:600:-50:150' \
#'DS:T10:GAUGE:600:-50:150' \
#'DS:HVAC:GAUGE:120:-10:10' \
#'RRA:AVERAGE:0.5:1:20160' \
#'RRA:AVERAGE:0.5:30:1488' \
#'RRA:MIN:0.5:30:1488' \
#'RRA:MAX:0.5:30:1488' \
#'RRA:AVERAGE:0.5:60:26280' \
#'RRA:MIN:0.5:60:26280' \
#'RRA:MAX:0.5:60:26280'
#
## hvac stats rrd:
#rrdtool create filename.rrd \
#--step '60' \
#--start '1230768000' \
#'DS:HVAC:GAUGE:120:-10:10' \
#'RRA:LAST:0.5:1:525600'
#
## workshop rrd:
#rrdtool create filename.rrd \
#--step '60' \
#'DS:T1:GAUGE:600:-50:150' \
#'DS:H1:GAUGE:600:-50:150' \
#'RRA:AVERAGE:0.5:1:20160' \
#'RRA:AVERAGE:0.5:30:1488' \
#'RRA:MIN:0.5:30:1488' \
#'RRA:MAX:0.5:30:1488' \
#'RRA:AVERAGE:0.5:60:52560' \
#'RRA:MIN:0.5:60:52560' \
#'RRA:MAX:0.5:60:52560'


#  T1 =  Attic
#  T2 =  Basement
#  T3 =  Master Bed
#  T4 =  Front Bath
#  T5 =  Utility room
#  T6 =  thermostat
#  T7 =  arduino local // dead
#  T8 =  kitchen
#  T9 =  garage
#  T10 = outside
#  HVAC = hvac status
#  T11 = Front Bed
#  T12 = Master Bath
#  T13 = Middle Bed


our $base_path = "/data/oneWire_rrd";		# base app path
our $rrdtool = "rrdtool";			# rrdtool binary
our $db = "$base_path/ow.rrd";			# path to rrd file                          
our $workshopdb = "$base_path/workshop.rrd";	# path to rrd file                          
our $hvacdb = "$base_path/hvacStats.rrd";	# path to rrd file with hvac historical data
our $rawdb = "$base_path/ow.raw";		# path to raw file
our $hvacStatsFile = "/var/www/lighttpd/ow/hvacStats.txt";	# path to hvac stats file for web read
our $htdocs = "$base_path/www";			# path to place graphs
our $remoteWeb = 'http://127.0.0.1/ow/getTemps.pl';	# data URL
our $workshop_url = 'https://developer-api.nest.com/devices/thermostats/BkLno3E-0sJA6aUJHyKc5IfYnYOYVFLh?auth=c.SFpILsAFPk1428wZLdmDC057rRFBxbiVsQowuxyESlDPLpYtpe0Y08hfDJfYg0RQHAEbOMXnXSwAhXIbpOvRlPibEJW3b5YlChZG8P5EEf619PVJmLyJkQFIH7RIohia9rjAvTgkNWFnUhZd';


our $height = 200;
our $width = 800;

#use strict;
use RRDp ();
use RRD::Simple ();
use LWP::Simple;
use POSIX (); # Used for strftime in graph() method

#use Devel::Size qw(size total_size);

our @TData; #where we store data (for now)
our %temps; #key=name_of_temp, value=temp_or_hum
our %hvac; #store hvac info like status, times, etc
our @HVACdata;
our $HVAClastEntry;
our $HVACfirstEntry;
our %workshopData;

# open hvac rrd for function use
our $hvacrrd = RRD::Simple->new(
    file => $hvacdb,
    on_missing_ds => "die"
);

# open main rrd for function use
our $mainrrd = RRD::Simple->new(
    file => $db,
    on_missing_ds => "die" 
#    on_missing_ds => "add"   
);

# open workshop rrd for function use
our $workshoprrd = RRD::Simple->new(
    file => $workshopdb,
    on_missing_ds => "die"
);

if ( defined $ARGV[0] ) {
  if ( $ARGV[0] eq "graph" ) {
      GraphChumby();
      GraphWeb();
  }
  elsif ( $ARGV[0] eq "chumby" ) {
      GraphChumby();
  }
  elsif ( $ARGV[0] eq "webgraph" ) {
  	  grabHVACdata();
      GraphWeb();
  }
  elsif ( $ARGV[0] eq "update" ) {
      my $nowtime = localtime();
      print "$nowtime -> updating $db...";
      getData();
      print "got data...";
      getWorkshop();
      print "got workshop...";
      updateRRD();
      updateWorkshop();
#      updateHVAC();
      updateRAW();
      print "updated!\n";
  }
  elsif ( $ARGV[0] eq "webdump" ) {
      getData();
      print "Got: @TData\n";
  }
  elsif ($ARGV[0] eq "info") {
      getRRDinfo();
  }
  elsif ($ARGV[0] eq "hvac") {
  	  grabHVACdata();
 	  getHVACstats();
      #print "HVAC Time over past 24hrs: " . parseHVACdata('end-1day', 'now', 'both') . "\n";
  }
  elsif ($ARGV[0] eq "test") {
  	  grabHVACdata();
  	  parseHVACdata('end-1month', 'now', 'heating');
  }
  elsif ($ARGV[0] eq "workshop") {
        getWorkshop();
        updateWorkshop();
  }
  else {
      usage(); 
  }
}
else {
    usage();
}

sub usage {
    print "Usage: oneWire_rrd.pl graph|update|webdump|info\n";
    print "   graph    - Builds all graphs\n";
    print "   chumby   - Builds chumby graphs only\n";
    print "   webgraph - Builds web graphs only\n";
    print "   update   - Reads data, inserts into rrd file\n";
    print "   webdump  - Reads data, dumps to console\n";
    print "   info     - Dumps rrd info to console\n";
    print "   hvac     - HVAC runtime stats\n";
}

sub getData {
# grab data from website and push into hash
# web data sample: startvar&Utility=60.58&Kitchen=56.08&Attic=31.10&MasterBed=62.83&Basement=52.31&Garage=45.95&BasementH=41.60&HVACstatus=standby
    my $content = LWP::Simple::get $remoteWeb;
    die "Couldn't get $remoteWeb" unless defined $content;

    if( $content =~ m{startvar&([\S]+)} ) {
        @TData = split(/&/, $1);
        
        foreach my $pair (@TData) {
            (my $key, my $value) = split(/=/, $pair);
            
            #pull out non-temp values! (HVACstatus value is text)
            if ($key ne 'HVACstatus') { $temps{$key} = $value; }
            else { 
            	if ($value eq "heating") { $hvac{status} = 10; }
            	elsif ($value eq "cooling") { $hvac{status} = -10; }
            }
        }
        #trim to to 2 decimal places - worth looking into rounding later
        #FUTUREFEATURE                                       
        foreach my $key (keys %temps) {                  
            $temps{$key} = sprintf("%.2f", $temps{$key});          
        } 
    }
    else { die "BAD DATA PULL FROM WEB!"; }
}

sub getWorkshop {
    my $workshop_data = get $workshop_url;
    #die "Couldn't get $workshop_url" unless defined $workshop_data;
    print "Couldn't get $workshop_url" unless defined $workshop_data;

    $workshop_data =~ s/[\"\{\}]//g;
    my @list1 = split(/,/, $workshop_data);

    foreach my $item(@list1) {
        my ($i,$j)= split(/:/, $item);
        $workshopData{$i} = $j;
    }
}

sub updateRRD {
# update main rrd with current data.
    $mainrrd->update(
        T1=>$temps{Attic},
        T2=>$temps{Basement},
        T3=>$temps{MasterBed},
        T4=>$temps{FrontBath},
        T5=>$temps{Utility},
        T6=>$temps{Thermostat},
#        T7=>$TData[6],
        T7=>'NaN',
        T8=>$temps{Kitchen},
        T9=>$temps{Garage},
        T10=>$temps{Outside},
        HVAC=>$hvac{status},
        T11=>$temps{FrontBed},
        T12=>$temps{MasterBath},
        T13=>$temps{MiddleBed}
    );
}

sub updateHVAC {
# update hvas rrd file with hvac running status for stats.
# using this rrd is sortof expensive as there is one entry per sec for the whole year, use sparingly
    $hvacrrd->update(
    	HVAC=>$hvac{status},
    );
}

sub updateRAW {
# update raw data file for future use
	my @tmpData = @TData;                                       
    unshift(@tmpData, time());                  
    my $output = join(',', @tmpData);
    my $ret = `echo $output >> $rawdb`;
}

sub updateWorkshop {
# update workshow rrd file with current data
    $workshoprrd->update(
        T1=>$workshopData{ambient_temperature_f},
        H1=>$workshopData{humidity}
    );
}

sub GraphChumby {
# create smaller chumby graphs with less text and the correct size

#graphs with hvac info on them
    $mainrrd->graph(
        destination => $htdocs,
        basename => "cby",
        timestamp => "both",
        periods => [qw(hour 6hour 12hour day week)],
        sources => [qw(T1 T2 T3 T4 T5 T6 T8 T9 T10 T11 T12 T13)],
	source_labels => {
	    T1 => "Attic",
	    T2 => "Basement",
	    T3 => "Master Bed",
	    T4 => "Front Bath",
	    T5 => "Utility Room",
	    T6 => "Thermostat",
#	    T7 => "",
	    T8 => "Kitchen",
	    T9 => "Garage",
	    T10 => "Outside",
#	    HVAC => "HVAC Status"
		T11 => "Front Bed",
		T12 => "Master Bath",
		T13 => "Mary's Office"
	},
	source_colors => {
	    T1 => "ff8000",
	    T2 => "c0b000",
	    T3 => "804099",
#	    T4 => "000000",
	    T5 => "008000",
	    T6 => "000090",
#	    T7 => "000000",
	    T8 => "a02020",
	    T9 => "000000",
	    T10 => "4575d7",
#	    HVAC => "000000"
	},
	line_thickness => 2,
	width => "745",
	height => "250",
	"full-size-mode" => "",
	"CDEF:heat=HVAC,10,EQ,T3,NaN,IF" => "",
    "CDEF:cool=HVAC,-10,EQ,T3,NaN,IF" => "",
    "AREA:heat#FFCCCC" => "",
    "AREA:cool#CCCCFF" => "",
    );

# graphs without hvac info
    $mainrrd->graph(
        destination => $htdocs,
        basename => "cby",
        timestamp => "both",
        periods => [qw(month annual 3years)],
        sources => [qw(T1 T2 T3 T4 T5 T6 T8 T9 T10 T11 T12 T13)],
	source_labels => {
	    T1 => "Attic",
	    T2 => "Basement",
	    T3 => "Master Bed",
	    T4 => "Front Bath",
	    T5 => "Utility Room",
	    T6 => "Thermostat",
#	    T7 => "",
	    T8 => "Kitchen",
	    T9 => "Garage",
	    T10 => "Outside",
#	    HVAC => "HVAC Status"
		T11 => "Front Bed",
		T12 => "Master Bath",
		T13 => "Mary's Office"
	},
	source_colors => {
	    T1 => "ff8000",
	    T2 => "c0b000",
	    T3 => "804099",
#	    T4 => "000000",
	    T5 => "008000",
	    T6 => "000090",
#	    T7 => "000000",
	    T8 => "a02020",
	    T9 => "000000",
	    T10 => "4575d7",
#	    HVAC => "000000"
	},
	line_thickness => 2,
	width => "745",
	height => "250",
	"full-size-mode" => "",
    );

# graph workshop info
    $workshoprrd->graph(
        destination => $htdocs,
        basename => "wsp",
        timestamp => "both",
        periods => [qw(hour 6hour 12hour day week month annual 3years)],
        sources => [qw(T1 H1)],
        source_labels => {
            T1 => "Temperature",
            H1 => "Humidity",
        },
        source_colors => {
            T1 => "ff8000",
            H1 => "4575d7",
        },
        line_thickness => 2,
        width => "745",
        height => "250",
        "full-size-mode" => "",
    );
}

sub GraphWeb {
    print "generating graphs...";
    print "1h...";
    GraphRRD('end-1hour', 'now', "$htdocs/ow-1hourly.png", 'Temperature - Last Hour');
    print "6h...";
    GraphRRD('end-6hour', 'now', "$htdocs/ow-6hourly.png", 'Temperature - Last 6 Hours');
    print "12h...";
    GraphRRD('end-12hour', 'now', "$htdocs/ow-12hourly.png", 'Temperature - Last 12 Hours');
    print "day...";
    GraphRRD('end-1day', 'now', "$htdocs/ow-daily.png", 'Temperature - Last 24 Hours');
    print "week...";
    GraphRRD('end-1week', 'now', "$htdocs/ow-weekly.png", 'Temperature - Last 7 Days');
    print "month...";
    GraphRRD('end-1month', 'now', "$htdocs/ow-monthly.png", 'Temperature - Last 30 Days');
    print "year...";
    GraphRRD('end-1year', 'now', "$htdocs/ow-yearly.png", 'Temperature - Past Year');
    print "done\n";
}

sub GraphRRD {
  my ( $starttime, $endtime, $ofname, $title ) = @_;
  my ( $htime, $hvacAvgTime );

  my $hvacPeriodTime = parseHVACdata($starttime, $endtime, "both");

  if ($starttime eq "end-1week") {
    $hvacAvgTime = $hvacPeriodTime / 7;
    $htime = sprintf('HVAC Run-Time: %dm  Avg: %dm/day\r', $hvacPeriodTime, $hvacAvgTime);
  }
  elsif ($starttime eq "end-1month") {
    #this is nasty as month time changes btw 28 & 31 days
    $hvacAvgTime = $hvacPeriodTime / 30;
    $htime = sprintf('HVAC Run-Time: %dm  Avg: %dm/day\r', $hvacPeriodTime, $hvacAvgTime);
  }
  elsif ($starttime eq "end-1year") {
    $hvacAvgTime = $hvacPeriodTime / 365;
    $htime = sprintf('HVAC Run-Time: %dm  Avg: %dm/day\r', $hvacPeriodTime, $hvacAvgTime);
  }
  else {
    $htime = sprintf('HVAC Run-Time: %dm\r', $hvacPeriodTime);
  }

  $htime =~ s/:/\\:/g; 

  RRDp::start $rrdtool;
  RRDp::cmd ("last $db");
  my $lastupdate = RRDp::read;

  my $timefmt = '%a %d/%b/%Y %T %Z';
  my $rtime = sprintf('RRD last updated: %s\r', POSIX::strftime($timefmt,localtime($$lastupdate)));
  $rtime =~ s/:/\\:/g; 

  my $gtime = sprintf('Graph last updated: %s\r', POSIX::strftime($timefmt,localtime(time)));
  $gtime =~ s/:/\\:/g;

  RRDp::cmd(
    "graph $ofname --imgformat PNG
    --start $starttime --end $endtime
    --width $width --height $height
    --slope-mode
    --title '$title'
    --vertical-label 'Degrees (F)'
    DEF:T1=$db:T1:AVERAGE
    DEF:T2=$db:T2:AVERAGE
    DEF:T3=$db:T3:AVERAGE
    DEF:T4=$db:T4:AVERAGE
    DEF:T5=$db:T5:AVERAGE
    DEF:T6=$db:T6:AVERAGE
    DEF:T7=$db:T7:AVERAGE
    DEF:T8=$db:T8:AVERAGE
    DEF:T9=$db:T9:AVERAGE
    DEF:T10=$db:T10:AVERAGE
    DEF:HVAC=$db:HVAC:AVERAGE
    CDEF:heat=HVAC,10,EQ,T6,NaN,IF
    CDEF:cool=HVAC,-10,EQ,T6,NaN,IF",
#line6
    "AREA:heat#FFCCCC
    AREA:cool#CCCCFF",
#line1
    "COMMENT:'       '
    COMMENT:'             Min       Max      Avg      Last'
    COMMENT:'            '
    COMMENT:'             Min       Max      Avg      Last\\n'",
#line2
    "COMMENT:'     '
    LINE2:T1#FF8000:'Attic     '
    GPRINT:T1:MIN:'%5.2lf F'
    GPRINT:T1:MAX:'%5.2lf F'
    GPRINT:T1:AVERAGE:'%5.2lf F'
    GPRINT:T1:LAST:'%5.2lf F'
    COMMENT:'      '
    LINE2:T5#008000:'Utility Room'
    GPRINT:T5:MIN:'%5.2lf F'
    GPRINT:T5:MAX:'%5.2lf F'
    GPRINT:T5:AVERAGE:'%5.2lf F'
    GPRINT:T5:LAST:'%5.2lf F\\n'",
#line3
    "COMMENT:'     '
    LINE2:T3#804099:'Master Bed'
    GPRINT:T3:MIN:'%5.2lf F'
    GPRINT:T3:MAX:'%5.2lf F'
    GPRINT:T3:AVERAGE:'%5.2lf F'
    GPRINT:T3:LAST:'%5.2lf F'
    COMMENT:'      '
    LINE2:T2#c0b000:'Basement    '
    GPRINT:T2:MIN:'%5.2lf F'
    GPRINT:T2:MAX:'%5.2lf F'
    GPRINT:T2:AVERAGE:'%5.2lf F'
    GPRINT:T2:LAST:'%5.2lf F\\n'",
#line4
    "COMMENT:'     '
    LINE2:T6#000090:'Thermostat'
    GPRINT:T6:MIN:'%5.2lf F'
    GPRINT:T6:MAX:'%5.2lf F'
    GPRINT:T6:AVERAGE:'%5.2lf F'
    GPRINT:T6:LAST:'%5.2lf F'
    COMMENT:'      '
    LINE2:T9#000000:'Garage      '
    GPRINT:T9:MIN:'%5.2lf F'
    GPRINT:T9:MAX:'%5.2lf F'
    GPRINT:T9:AVERAGE:'%5.2lf F'
    GPRINT:T9:LAST:'%5.2lf F\\n'",
#line5
    "COMMENT:'     '
    LINE2:T8#a02020:'Kitchen   '
    GPRINT:T8:MIN:'%5.2lf F'
    GPRINT:T8:MAX:'%5.2lf F'
    GPRINT:T8:AVERAGE:'%5.2lf F'
    GPRINT:T8:LAST:'%5.2lf F'
    COMMENT:'      '
    LINE2:T10#4575d7:'Outside     '
    GPRINT:T10:MIN:'%5.2lf F'
    GPRINT:T10:MAX:'%5.2lf F'
    GPRINT:T10:AVERAGE:'%5.2lf F'
    GPRINT:T10:LAST:'%5.2lf F\\n'
    COMMENT:'\\s'",
#line6
    "COMMENT:'     '
    LINE1:heat#FFCCCC:'Heating   '
    LINE1:cool#CCCCFF:'Cooling\\n'",
#line7
    "COMMENT:'$gtime'
    COMMENT:'$rtime'",
#line8
    "COMMENT:'$htime'"
);

  my $answer=RRDp::read;
  RRDp::end;
}

sub getRRDinfo {
	print "======== Main RRD ========\n";
    my $lastUpdated = $mainrrd->last;
    print "$hvacdb was last updated at " . scalar(localtime($lastUpdated)) . "\n";

    # Get list of data source names from an RRD file
    my @dsnames = $mainrrd->sources;
    print "Available data sources: " . join(", ", @dsnames) . "\n";

    # Return information about an RRD file
    my $info = $mainrrd->info;
    require Data::Dumper;
    print Data::Dumper::Dumper($info);
    
  	print "\n\n======== HVAC RRD ========\n";
    $lastUpdated = $hvacrrd->last;
    print "$db was last updated at " . scalar(localtime($lastUpdated)) . "\n";

    # Get list of data source names from an RRD file
    @dsnames = $hvacrrd->sources;
    print "Available data sources: " . join(", ", @dsnames) . "\n";

    # Return information about an RRD file
    $info = $hvacrrd->info;
    require Data::Dumper;
    print Data::Dumper::Dumper($info);   
}

sub grabHVACdata {
	my $starttime = 'end-2month';
	my $endtime = 'now';
	
	#grab data from rrd but only populate on times as we dont care about the rest.
	#this saves significant amounts of memory 5mb > 250k !!
	#and significantly speeds up processing the stats to half the time
	RRDp::start $rrdtool;
	RRDp::cmd("fetch $hvacdb LAST --start $starttime --end $endtime");
	my $answer = RRDp::read;
	foreach my $line (split(/\n/, $$answer)) {
		my @subline = split(/\s+/, $line);
		if ($subline[1] =~ /1\.0000000000e\+01$/) {
			push(@HVACdata, $line);
		}
	}
#	@HVACdata = split(/\n/, $$answer);
	RRDp::end;
	
#	print "answer size = " . size($answer) . "\n";
#	print "answer total size = " . total_size($answer) . "\n";
	
#	print "hvacdata size = " . size(\@HVACdata) . "\n";
#	print "hvacdata total size = " . total_size(\@HVACdata) . "\n";
	
	$HVAClastEntry = $hvacrrd->last;
	RRDp::start $rrdtool;
	RRDp::cmd("first $hvacdb");
	$answer = RRDp::read;
	$HVACfirstEntry = $$answer;
	RRDp::end;	
	
#	print "answer size = " . size($answer) . "\n";
#	print "answer total size = " . total_size($answer) . "\n";
		
	undef $answer;
#	print "answer size = " . size($answer) . "\n";
#	print "answer total size = " . total_size($answer) . "\n";
		
	
	
#	print "last = $HVAClastEntry\nfirst = $HVACfirstEntry\n"
}

sub parseHVACdata {
	my ( $starttime, $endtime, $hvactype ) = @_;
	my $cooling = 0;
	my $heating = 0;
	my @subline;
	
	if ($endtime eq 'now-1month') { $endtime = $HVAClastEntry - 2592000; }
	else { $endtime = $HVAClastEntry; } # default to now
	
	if ($starttime eq 'end-1week') { $starttime = $endtime - 604800; }
	elsif ($starttime eq 'end-1month') { $starttime = $endtime - 2592000; }
	elsif ($starttime eq 'end-2month') { $starttime = $endtime - 5184000; }
	else { $starttime = $endtime - 86400; } #default to end-1day
	
#	print "start = $starttime\nend = $endtime\n";
	
	foreach my $line (@HVACdata) {
		@subline = split(/:/, $line);
		#print "$subline[0]\n";
		if (($subline[0] < $endtime) && ($subline[0] > $starttime)) {
#			print "$subline[0] $subline[1]\n";
			if($subline[1] =~ /\-1\.0000000000e\+01$/) { $cooling++; }
			elsif($subline[1] =~ /1\.0000000000e\+01$/) { $heating++; }
		}
	}
	
#	print "heat = $heating\ncool = $cooling\n";
	
	if ($hvactype eq 'cooling') { return $cooling; }
	elsif($hvactype eq 'heating') { return $heating; }
	else { return ($heating + $cooling) }
}

sub getHVACstats {
	my ($lastDayH, $lastDayC, $lastWeekH, $lastWeekC, $lastMoAvgH, $lastMoAvgC, $prevMoAvgH, $prevMoAvgC);
#	my ($lastYrAvgH, $lastYrAvgC);
	
	##data is straight from the rrd. This is fine for day, week, but gets expensive for month & year.
	$lastDayH = parseHVACdata('end-1day', 'now', 'heating');
	$lastDayC = parseHVACdata('end-1day', 'now', 'cooling');
	$lastWeekH = parseHVACdata('end-1week', 'now', 'heating');
	$lastWeekC = parseHVACdata('end-1week', 'now', 'cooling');

	##past 30 days & previous 30 days
	$lastMoAvgH = sprintf("%d",(parseHVACdata('end-1month', 'now', 'heating') / 30));
	$lastMoAvgC = sprintf("%d",(parseHVACdata('end-1month', 'now', 'cooling') / 30));
	$prevMoAvgH = sprintf("%d",(parseHVACdata('end-2month', 'now-1month', 'heating') / 30));
	$prevMoAvgC = sprintf("%d",(parseHVACdata('end-2month', 'now-1month', 'cooling') / 30));
	
	##avoid doing year at all costs, uses more memory that available on chumby
	#$lastYrAvgH = parseHVACdata('end-1year', 'now', 'heating');
	#$lastYrAvgC = parseHVACdata('end-1year', 'now', 'cooling');
	
	$hvacString = "&HVAClastDayH=$lastDayH&HVAClastDayC=$lastDayC&HVAClastWeekH=$lastWeekH&HVAClastWeekC=$lastWeekC&HVAClastMoAvgH=$lastMoAvgH&HVAClastMoAvgC=$lastMoAvgC&HVACprevMoAvgH=$prevMoAvgH&HVACprevMoAvgC=$prevMoAvgC"; 
	
	my $ret = `echo '$hvacString' > $hvacStatsFile`;
	print "$hvacString\n"; 
}
