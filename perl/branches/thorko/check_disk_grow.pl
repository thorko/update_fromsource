#!/usr/bin/perl
#$ID$
# this script will check the disk growth since the last time 
# it was executed.
# todo: status of each partition gets overwritten
use strict;
use Getopt::Long;

# use df -l
# check all local partitions available
# don't check remote partitions, otherwise it could get stuck
# get os
my $disk_cmd = ""; 
if ( $^O eq "solaris" ) {
	$disk_cmd = "/usr/ucb/df -l";
} 
if ( $^O eq "linux" ) {
	$disk_cmd = "/bin/df -l";
}
my $debug = 0;
my $version = "1.0";
my $help = "";
my $disk = "";
my $warning = "";
my $critical = "";

Getopt::Long::Configure('bundling');
GetOptions(
	"h|help" => \$help,
	"d|debug" => \$debug,
	"w|warning=f" => \$warning,
	"c|critical=f" => \$critical,
	"p|partition=s" => \$disk);

if($help) {
	help();
	exit(0);
}

if($disk eq "" || $warning eq "" || $critical eq "") {
	help();
	exit(1);
}

# check if partition exists
my $r = system("$disk_cmd |grep $disk > /dev/null 2>&1");
if ( $r ) {
	print "Sorry partition $disk doesn't exist\n";
	exit 3;
}

my $disk_state = "/var/tmp/disk.$disk.state";

# if old state file doesn't exist it will be created
if ( ! -e $disk_state ) {
	# get disk stats and write it to statefile
	open CMD, "| $disk_cmd > $disk_state" or die("Couldn't run $disk_cmd > $disk_state");
	close CMD;
}

# get total size of partition
open CMD, "cat $disk_state | grep $disk | awk '{ print \$2 }'|" or die("Couldn't run cat $disk_state | grep $disk | awk '{ print \$2 }");
my $disk_size = <CMD>;
chomp $disk_size;
close CMD;

# get the old states now
open CMD, "cat $disk_state | grep $disk | awk '{ print \$3 }'|" or die("Couldn't run cat $disk_state | grep $disk | awk '{ print \$3 }");
my $oldstate=<CMD>;
chomp $oldstate;
close CMD;

# get current state
open CMD, "$disk_cmd | grep $disk | awk '{ print \$3 }'|" or die("Couldn't run $disk_cmd | grep $disk | awk '{ print \$3 }");
my $currentstate = <CMD>;
chomp $currentstate;
close CMD;

# write new state to file
open CMD, "| $disk_cmd | grep $disk > $disk_state" or die("Couldn't run $disk_cmd > $disk_state");
close CMD;

# do calculation
my $g=($currentstate-$oldstate)*100/$disk_size;
print "Old state: $oldstate\nCurrent state: $currentstate\nGrowth: $g\n" if ($debug);
print "($currentstate-$oldstate)*100/$disk_size\n" if ($debug);

# format 
$g = sprintf("%.5f", $g);


# check thresholds 
if ( $g < $warning ) {
	print "Partition growth OK | $disk=$g%\n";
	exit 0;
}
elsif ( $g >= $warning && $g < $critical ) {
	print "Partition growth WARNING | $disk=$g%\n";
	exit 1;
} else {
	print "Partition growth CRITICAL | $disk=$g%\n";
	exit 2;
}

sub help {
	print <<'HELP';

check_disk_grow.pl -p <partition> -w <warning %> -c <critical %> [-d] [-h]
Checks the disk growth relative to the total space.

 -p, --partition    partition to check
 -w, --warning      warning threshold in %, growth of the partition 
 -c, --critical     critical threshold in %, growth of the partition
 -d, --debug        enable debug mode
 -h, --help         show help message

HELP
}

