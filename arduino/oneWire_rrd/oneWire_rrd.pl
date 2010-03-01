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


$base_path = "/opt/oneWire_rrd";         # main app path
$rrdtool = "/usr/bin/rrdtool";           # rrdtool binary
our $db = "$base_path/ow.rrd";           # directory where the database lives
our $htdocs = "$base_path/www";          # directory where the graphs will end up
our $remoteWeb = 'http://192.168.1.80';  # URL to get the data from

use strict;
use RRD::Simple;
use LWP::Simple;

our @TData; #where we store data (for now)
my $rrd = RRD::Simple->new(
    file => $db,
    on_missing_ds => "die" );

if ( defined $ARGV[0] ) {
    if ( $ARGV[0] eq "graph" ) {
        print "generating graphs...\n";
        graphRRD();
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

    if( $content =~ m{CSV:([0-9,. ]+)} ) {
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

sub graphRRD {
    my %rtn = $rrd->graph(
        destination => $htdocs,
        basename => "ow",
        timestamp => "both",
        source_labels => { T1 => "Attic",
                           T2 => "Basement",
                           T3 => "Master Bedroom",
                           T4 => "unused",
                           T5 => "Utility Room",
                           T6 => "Thermostat",
                           T7 => "unused",
                           T8 => "Kitchen",
                           T9 => "Garage",
                           T10 => "unused", },
        line_thickness => 2,
        extended_legend => 1,
        title => "Temperatures",
        vertical_label => "Degrees (F)",
        width => 800, 
        height => 200,
        );
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
