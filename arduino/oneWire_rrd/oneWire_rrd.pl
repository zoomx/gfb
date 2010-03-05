#!/usr/bin/perl

## rrd created with:
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
# AVERAGE for temp, LAST for hvac
# MIN MAX?


$base_path = "/opt/oneWire_rrd";      # main app path
our $rrdtool = "/usr/bin/rrdtool";    # rrdtool binary
our $db = "$base_path/ow.rrd";        # directory where the database lives
our $htdocs = "$base_path/www";       # directory where the graphs will end up
our $remoteWeb = 'http://192.168.1.80';  # URL to get the data from

our $height = 200;
our $width = 800;

use strict;
use RRDp;
use RRD::Simple;
use LWP::Simple;
use POSIX qw(strftime); # Used for strftime in graph() method


our @TData; #where we store data (for now)
my $rrd = RRD::Simple->new(
    file => $db,
    on_missing_ds => "die" );

if ( defined $ARGV[0] ) {
  if ( $ARGV[0] eq "graph" ) {
    print "generating graphs...\n";
    GraphRRD('end-1hour', 'now', "$htdocs/ow-1hourly.png", 'Hourly');
    GraphRRD('end-6hour', 'now', "$htdocs/ow-6hourly.png", '6Hour');
    GraphRRD('end-12hour', 'now', "$htdocs/ow-12hourly.png", '12Hour');
    GraphRRD('end-1day', 'now', "$htdocs/ow-daily.png", 'Daily');
    GraphRRD('end-1week', 'now', "$htdocs/ow-weekly.png", 'Weekly');
    GraphRRD('end-1month', 'now', "$htdocs/ow-monthly.png", 'Monthly');
    GraphRRD('end-1year', 'now', "$htdocs/ow-yearly.png", 'Yearly');
  }

  elsif ( $ARGV[0] eq "update" ) {
      print "updating $db...";
      getData();
      print "got data...";
      cleanup();
      updateRRD();
      print "updated!\n";
  }

  elsif ( $ARGV[0] eq "webdump" ) {
    getData();
    print "Got: @TData\n";
  }

    elsif ($ARGV[0] eq "info") {
        getRRDinfo();
    }

    else {
	usage(); 
    }
}
else {
    usage();
}

sub usage {
    print "Usage: onewire-graph graph|update|webdump|info\n";
    print "   graph   - Builds graphs\n";
    print "   update  - Reads data, inserts into rrd file\n";
    print "   webdump - Reads data, dumps to console\n";
    print "   info    - Dumps rrd info to console\n";
}


sub getData {
    my $content = get $remoteWeb;
    die "Couldn't get $remoteWeb" unless defined $content;

    if( $content =~ m{CSV:([0-9,.\- ]+)} ) {
        @TData = split(/,/,$1);
    }
}

sub cleanup() {
    for(my $i = 0; $i < @TData; $i++) {
        #cleanup
        $TData[$i] = sprintf("%.1f", $TData[$i]);
    }
}

sub updateRRD {
    $rrd->update(
        T1=>$TData[0],
        T2=>$TData[1],
        T3=>$TData[2],
        T4=>$TData[3],
        T5=>$TData[4],
        T6=>$TData[5],
        T7=>$TData[6],
        T8=>$TData[7],
        T9=>$TData[8],
        T10=>$TData[9]
    );
}


sub GraphRRD {
  my ( $starttime, $endtime, $ofname, $title ) = @_;

  RRDp::start "$rrdtool";
  RRDp::cmd "last $db";
  my $lastupdate = RRDp::read;

  my $timefmt = '%a %d/%b/%Y %T %Z';
  my $rtime = sprintf('RRD last updated: %s\r', strftime($timefmt,localtime($$lastupdate)));
  $rtime =~ s/:/\\:/g; 

  my $gtime = sprintf('Graph last updated: %s\r', strftime($timefmt,localtime(time)));
  $gtime =~ s/:/\\:/g;

  RRDp::cmd
    "graph $ofname --imgformat PNG",
    "--start '$starttime' --end '$endtime'",
    "--width $width --height $height",
    "--slope-mode",
    "--title $title",
    "--vertical-label 'Degrees (F)'",
    "DEF:T1=$db:T1:AVERAGE",
    "DEF:T2=$db:T2:AVERAGE",
    "DEF:T3=$db:T3:AVERAGE",
    "DEF:T4=$db:T4:AVERAGE",
    "DEF:T5=$db:T5:AVERAGE",
    "DEF:T6=$db:T6:AVERAGE",
    "DEF:T7=$db:T7:AVERAGE",
    "DEF:T8=$db:T8:AVERAGE",
    "DEF:T9=$db:T9:AVERAGE",
    "DEF:T10=$db:T10:AVERAGE",
#line1
    "COMMENT:\"       \"",
    "COMMENT:\"             Min       Max      Avg      Last\"",
    "COMMENT:\"            \"",
    "COMMENT:\"             Min       Max      Avg      Last\\n\"",
#line2
    "COMMENT:\"     \"",
    "LINE2:T1#FF8000:'Attic     '",
    "GPRINT:T1:MIN:\"%5.2lf F\"",
    "GPRINT:T1:MAX:\"%5.2lf F\"",
    "GPRINT:T1:AVERAGE:\"%5.2lf F\"",
    "GPRINT:T1:LAST:\"%5.2lf F\"",
    "COMMENT:\"      \"",
    "LINE2:T5#008000:'Utility Room'",
    "GPRINT:T5:MIN:\"%5.2lf F\"",
    "GPRINT:T5:MAX:\"%5.2lf F\"",
    "GPRINT:T5:AVERAGE:\"%5.2lf F\"",
    "GPRINT:T5:LAST:\"%5.2lf F\\n\"",
#line3
    "COMMENT:\"     \"",
    "LINE2:T3#804099:'Master Bed'",
    "GPRINT:T3:MIN:\"%5.2lf F\"",
    "GPRINT:T3:MAX:\"%5.2lf F\"",
    "GPRINT:T3:AVERAGE:\"%5.2lf F\"",
    "GPRINT:T3:LAST:\"%5.2lf F\"",
    "COMMENT:\"      \"",
    "LINE2:T2#c0b000:'Basement    '",
    "GPRINT:T2:MIN:\"%5.2lf F\"",
    "GPRINT:T2:MAX:\"%5.2lf F\"",
    "GPRINT:T2:AVERAGE:\"%5.2lf F\"",
    "GPRINT:T2:LAST:\"%5.2lf F\\n\"",
#line4
    "COMMENT:\"     \"",
    "LINE2:T6#000090:'Thermostat'",
    "GPRINT:T6:MIN:\"%5.2lf F\"",
    "GPRINT:T6:MAX:\"%5.2lf F\"",
    "GPRINT:T6:AVERAGE:\"%5.2lf F\"",
    "GPRINT:T6:LAST:\"%5.2lf F\"",
    "COMMENT:\"      \"",
    "LINE2:T9#000000:'Garage      '",
    "GPRINT:T9:MIN:\"%5.2lf F\"",
    "GPRINT:T9:MAX:\"%5.2lf F\"",
    "GPRINT:T9:AVERAGE:\"%5.2lf F\"",
    "GPRINT:T9:LAST:\"%5.2lf F\\n\"",
#line5
    "COMMENT:\"     \"",
    "LINE2:T8#a02020:'Kitchen   '",
    "GPRINT:T8:MIN:\"%5.2lf F\"",
    "GPRINT:T8:MAX:\"%5.2lf F\"",
    "GPRINT:T8:AVERAGE:\"%5.2lf F\"",
    "GPRINT:T8:LAST:\"%5.2lf F\"",
    "COMMENT:\"      \"",
    "LINE2:T10#4575d7:'Outside     '",
    "GPRINT:T10:MIN:\"%5.2lf F\"",
    "GPRINT:T10:MAX:\"%5.2lf F\"",
    "GPRINT:T10:AVERAGE:\"%5.2lf F\"",
    "GPRINT:T10:LAST:\"%5.2lf F\\n\"",
    "COMMENT:\"\\s\"",
#line6
    "COMMENT:\"$gtime\"",
    "COMMENT:\"$rtime\""
;

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
