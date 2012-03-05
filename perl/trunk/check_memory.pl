#!/usr/bin/perl
#$ID$
# check memory consumption of process
# author: thorko 2012

use strict;
use warnings;
use Getopt::Long;
use Fcntl qw(:flock);

my $debug = 0;
my $help = 0;
my $warning = "";
my $critical = "";
my $processname = "";
my $memory;
# fields to be extracted
# check /proc/pid/status for valid fields
our @fields = ("VmData", "VmStk", "VmExe", "VmLib", "VmRSS");

my $line;
my @pids;
my $pid;

## help function ###
sub help () {
	print << 'HELP';
check_memory.pl [-d] [-h] -w <warning> -c <crtical> -p <processname>

-p, --pname	process name to check for memory consumption
-w, --warning	warning threshold in KB (VmData + VmStk)
-c, --critical	critical threshold in KB (VmData + VmStk)
-d, --debug	enable debug mode
-h, --help	show help message
HELP
}

## memusage ##
sub memusage {
    my ($mem, $line);
    my %memory;
    my ($process) = @_;
    open STAT, "< /proc/$process/status" or die("Couldn't read /proc/$process/status");
    while($line = <STAT>) {
        foreach my $field (@fields) {
            ($mem) = $line =~ m/^$field:\s+(.*)\skB/;
            if ( $mem ) {
                $memory{$field} = $mem;
            }
        }
    }
    close STAT;
    return \%memory;
}

# get options
Getopt::Long::Configure('bundling');
GetOptions(
        "h|help" => \$help,
        "d|debug" => \$debug,
        "w|warning=f" => \$warning,
        "c|critical=f" => \$critical,
        "p|pname=s" => \$processname);

if ( $help ) {
	help();
	exit(0);
}

if ( $processname eq "" || $warning eq "" || $critical eq "" ) {
	help();
	exit(1);
}

flock(DATA, LOCK_EX|LOCK_NB) or die "Program already running.";

# get pid of process
open CMD, "pgrep $processname|" or die ("Couldn't run pgrep");
while ( $pid = <CMD> ) {
	chomp $pid;
	push @pids, $pid;
	print "pid of $processname: $pid\n" if ($debug);
}
close CMD;

if ( scalar @pids ) {
	# calculate overall memory
	foreach (@pids) {
        print "$_: " if ($debug);
		my $n = memusage($_);
        foreach (keys %$n) {
            # summarize all fields
            $memory->{$_} += $n->{$_};
            print "$_: $n->{$_}, " if ($debug);
        }
        print "\n" if ($debug);
	}
}

my $perfdata;
my $size = $memory->{"VmData"} + $memory->{"VmStk"};
# create perfdata
foreach (keys %$memory) {
    $perfdata .= "$_: $memory->{$_} ";
}

# check thresholds
if ( $size > $critical ) {
	print "CRITICAL: $processname, memory: $size KB | $perfdata\n";
	exit(2);
} elsif ( $size > $warning ) {
	print "WARNING: $processname, memory: $size KB | $perfdata\n";
	exit(1);
} else {
	print "OK: $processname, memory: $size KB | $perfdata\n";
	exit(0);
}

__DATA__
