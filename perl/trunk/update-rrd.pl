#!/usr/bin/perl
#$ID$
# add a new datasource to an existing rrd file
#
use strict;
use warnings;
use RRD::Simple();
use Getopt::Long;
use List::Util qw(min max);
use Switch;

my $debug = 0;
my $help = 0;
my $file = "";
my $option = "";

GetOptions(
    "f|file=s" => \$file,
    "o|option=s" => \$option,
    "d|debug" => \$debug,
    "h|help" => \$help);

if( $help || $file eq "" || $option eq "") {
    &help();
    exit(1);
}

my $rrd = RRD::Simple->new();

switch($option) {
	case "add_source" {
		my $max = max($rrd->sources($file))+1;
		print "adding new source $max with type GAUGE...\n" if ($debug);
		$rrd->add_source($file, "$max" => 'GAUGE');
	}
}

sub help () {
print <<'HELP';
update-rrd.pl -f <rrd file> -o <option> [-d] [-h]

-f, --file    the rrd file to update
-o, --option  what to update
	      add_source = add a new datasource
-d, --debug   debugging on
-h, --help    print help message
HELP
}
