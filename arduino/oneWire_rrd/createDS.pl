#!/usr/bin/perl

our $base_path = "/mnt/usb/oneWire_rrd";		# base app path
our $rrdtool = "/mnt/usb/rrdtool/bin/rrdtool";	# rrdtool binary
our $db = "$base_path/ow.rrd";					# path to rrd file                          


#use strict;
use RRDp ();
use RRD::Simple ();


# open main rrd for function use
our $mainrrd = RRD::Simple->new(
    file => $db,
#    on_missing_ds => "die" 
    on_missing_ds => "add" 
    
);


$mainrrd->add_source(
	T11 => "GAUGE"
);
$mainrrd->add_source(
	T12 => "GAUGE"
);
$mainrrd->add_source(
	T13 => "GAUGE"
);
