#!/psp/usr/bin/perl

## original rrd created with:
#rrdtool create ow.rrd \
#--step '60' \
#'DS:T1:GAUGE:240:-50:150' \
#'DS:T2:GAUGE:240:-50:150' \
#'DS:T3:GAUGE:240:-50:150' \
#'DS:T4:GAUGE:240:-50:150' \
#'DS:T5:GAUGE:240:-50:150' \
#'DS:T6:GAUGE:240:-50:150' \
#'DS:T7:GAUGE:240:-50:150' \
#'DS:T8:GAUGE:240:-50:150' \
#'DS:T9:GAUGE:240:-50:150' \
#'DS:T10:GAUGE:240:-50:150' \
#'DS:HVAC:GAUGE:240:-10:10' \
#'RRA:AVERAGE:0.5:1:1051200' \
#'RRA:LAST:0.5:1:1051200' \
##
#
# 10 therms checked every 1 min, -50min, 150max
# 1 hvac checked every 1 min, -10min (cool), 10max (heat) (0 is off)
#
# 1min interval saved for 2 years
#
## new rrd created with:
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

#  T1 =  Attic
#  T2 =  Basement
#  T3 =  Master Bed
#  T4 =  //dead
#  T5 =  Utility room
#  T6 =  thermostat
#  T7 =  arduino local // dead
#  T8 =  kitchen
#  T9 =  garage
#  T10 = outside
#  HVAC = hvac status


$base_path = "/mnt/usb/oneWire_rrd";      # main app path
our $rrdtool = "/mnt/usb/rrdtool/bin/rrdtool";    # rrdtool binary
our $db = "$base_path/ow.rrd";        # path to rrd file                          
our $rawdb = "$base_path/ow.raw";     # path to raw file
our $htdocs = "$base_path/www";       # directory where the graphs will end up
our $remoteWeb = 'http://127.0.0.1/cgi-bin/getTemps.pl';  # URL to get the data from

our $height = 200;
our $width = 800;

#use strict;
use RRDp;
use RRD::Simple;
use LWP::Simple;
use POSIX qw(strftime); # Used for strftime in graph() method


our @TData; #where we store data (for now)
our %temps; #key=name_of_temp, value=temp_or_hum
our %hvac; #store hvac info like status, times, etc

my $rrd = RRD::Simple->new(
    file => $db,
    on_missing_ds => "die" );

if ( defined $ARGV[0] ) {
  if ( $ARGV[0] eq "graph" ) {
      GraphChumby();
      GraphWeb();
  }

  elsif ( $ARGV[0] eq "chumby" ) {
      GraphChumby();
  }
  
  elsif ( $ARGV[0] eq "webgraph" ) {
      GraphWeb();
  }
  
  elsif ( $ARGV[0] eq "update" ) {
      my $nowtime = localtime();
      print "$nowtime -> updating $db...";
      getData();
      print "got data...";
      updateRRD();
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
      print "HVAC Time over past 24hrs: " . hvacTime('end-1day', 'now') . "\n";
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
    print "   hvac     - HVAC runtime over last 24hrs\n";
}


sub getData {
    my $content = get $remoteWeb;
    die "Couldn't get $remoteWeb" unless defined $content;

    if( $content =~ m{startvar&([\S]+)} ) {
        @TData = split(/&/, $1);
        
        foreach my $pair (@TData) {
            (my $key, my $value) = split(/=/, $pair);
            
            #pull out non-temp values! (HVACstatus value is text)
            if ($key ne 'HVACstatus') { $temps{$key} = $value; }
            else { $hvac{status} = $value; }
        }
        #trim to to 2 decimal places - worth looking into rounding later
        #FUTUREFEATURE                                       
        foreach my $key (keys %temps) {                  
            $temps{$key} = sprintf("%.2f", $temps{$key});               
        } 
    }
}


sub updateRRD {
    $rrd->update(
        T1=>$temps{Attic},
        T2=>$temps{Basement},
        T3=>$temps{MasterBed},
        T4=>'NaN',
        T5=>$temps{Utility},
        T6=>$temps{Thermostat},
#        T6=>'NaN',
#        T7=>$TData[6],
        T7=>'NaN',
        T8=>$temps{Kitchen},
        T9=>$temps{Garage},
        T10=>$temps{Outside},
#        HVAC=>$hvac{status}
    );
}

sub updateRAW {                                                     
    my @tmpData = @TData;                                       
    unshift(@tmpData, time());                  
    my $output = join(',', @tmpData);
#   print $output;                  
    my $ret = `echo $output >> $rawdb`;
}

sub GraphChumby {
    my %rtn = $rrd->graph(
        destination => $htdocs,
        basename => "cby",
        timestamp => "both",
        periods => [qw(hour 6hour 12hour day week month annual)],
        sources => [qw(T1 T2 T3 T5 T6 T8 T9 T10)],
	source_labels => {
	    T1 => "Attic",
	    T2 => "Basement",
	    T3 => "Master Bed",
#	    T4 => "",
	    T5 => "Utility Room",
	    T6 => "Thermostat",
#	    T7 => "",
	    T8 => "Kitchen",
	    T9 => "Garage",
	    T10 => "Outside",
#	    HVAC => "HVAC Status"
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
	width => "673",
	height => "145",
#	full-size-mode => 1,
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
    print "done generating graphs\n";
}

sub GraphRRD {
  my ( $starttime, $endtime, $ofname, $title ) = @_;

  my $hvacPeriodTime = hvacTime($starttime, $endtime);
  my ( $htime, $hvacAvgTime );

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
  my $rtime = sprintf('RRD last updated: %s\r', strftime($timefmt,localtime($$lastupdate)));
  $rtime =~ s/:/\\:/g; 

  my $gtime = sprintf('Graph last updated: %s\r', strftime($timefmt,localtime(time)));
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


sub getRRDinfo() {
    my $lastUpdated = $rrd->last;
    print "ow.rrd was last updated at " .
          scalar(localtime($lastUpdated)) . "\n";

    # Get list of data source names from an RRD file
    my @dsnames = $rrd->sources;
    print "Available data sources: " . join(", ", @dsnames) . "\n";

    # Return information about an RRD file
    my $info = $rrd->info;
    require Data::Dumper;
    print Data::Dumper::Dumper($info);
}

sub hvacTime {
  my ( $starttime, $endtime ) = @_;
  my $hvacOn = 0;

  RRDp::start $rrdtool;
  RRDp::cmd("fetch $db AVERAGE --start $starttime --end $endtime");
  my $answer = RRDp::read;
  my @lines = split(/\n/, $$answer);
  RRDp::end;

  foreach my $line (@lines) {
    if ( $line =~ /1\.0000000000e\+01$/ ) {
      $hvacOn++;
    }
  }

  return $hvacOn;
}
