#!/usr/bin/perl -w
#$ID$
#############################################################
# Skript wertet DNS Statistiken über einen Tag aus
# gibt Minimum, Maximum, Summe und Durchschnitt der 
# Queries ausa
# 
# Benötigt
# -f DNS Query Statistik Datei
# -d Datum des gewünschten Tages der Auswertung
# -l Location 
# 
# Rückgabe von
# Min queries: minimale Anzahl an Queries
# Max queries: maximale Anzahl an Queries
# Average:     Durchschnitt der Queries sowie prozentualen
#	       Anteil der Maximal erlaubten Queries
# Sum queries: Summe aller Queries des Tages
# 
# 2011-04-20 TK
############################################################

use strict;
use POSIX;
use Getopt::Std;
use RRDTool::OO ();
$Getopt::Std::STANDARD_HELP_VERSION = 1;
our( $opt_f, $opt_d, $opt_l, $opt_t, $opt_u );
my ( $stats_file, $eval_date, $location, $timestart, $timeend );
my ( $timeframe_start, $timeframe_end );
my %opts;
# interval für den Graphen auf 1 Tag eingestellt
my $interval = 86400;

my ( @queries, @queries_sorted, @max_queries, @percent_queries );
my ( $max, $min, $average, $max_element, $sum, $av_percent, $rrdfile );


getopts('hf:d:l:t:u:', \%opts);

if ( $opts{'h'} ) {
	help_message();
	exit 0;
}

# cmdline Optionen auswerten
if ( ! defined($opts{'f'}) || ! defined($opts{'d'}) || ! defined($opts{'l'})) {
	print "Usage: stats_per_day.pl -f <stats file> -d <date [YYYYMMDD]> [-t <timeframe [hhmm-hhmm]>] -l <location> [-u <RRD file>]\n";
	exit 1;
} else {
	$stats_file =  $opts{'f'};
	$eval_date = $opts{'d'};
	$location = $opts{'l'};
	if ( defined($opts{'t'}) ) {
		($timestart, $timeend) = split(/-/, $opts{'t'});
	}
	if ( defined($opts{'u'}) ) {
		$rrdfile = $opts{'u'};
	}
}

if ( ! -e $stats_file ) {
	print "Stats file doesn't exist: $stats_file\n";
	exit 1;
}
if ( !($eval_date =~ /^[+-]?\d+$/) ) {
	print "This is not a valid date: $eval_date\n";
	exit 1;
}
# wenn timeframe angegeben, baue timestamp
if ( defined($timestart) && defined($timeend) ) {
	$timeframe_start = $eval_date.$timestart;
	$timeframe_end = $eval_date.$timeend;
} else {
	$timeframe_start = $eval_date."000000";
	$timeframe_end = $eval_date."235959";
}
#print $timeframe_start."\n".$timeframe_end."\n";

open FILE, '<', $stats_file;
while(<FILE>) {
	my ($line) = $_;
	my $timestamp = (split(/:/, $line))[0];

	# wenn Zeile mit timestamp beginnt
	if ( $timestamp le $timeframe_end && $timestamp ge $timeframe_start ) {
		# prüfen der location
		if ($line =~ /LOC=$location/) {
			my @value = split(/[\s,]/, $line);
			foreach my $el (@value) { 
				if ( $el =~ /^SQ/ ) { push(@queries, (split(/=/,$el))[1]) }
				if ( $el =~ /^MQ/ ) { push(@max_queries, (split(/=/,$el))[1]) }
			}
		}
	}
}
close FILE;

# nur ausführen falls es Einträge gab
if ( @queries ) {
	# queries sortieren
	@queries_sorted = sort { $a <=> $b } @queries;
	$max_element = scalar(@queries_sorted);
	
	# Durchschnitt berechnen
	foreach my $x (@queries_sorted) {
		$sum += $x;
	}
	$average = ceil($sum / $max_element);

	# Prozent des Averages bilden
	$av_percent = $average / $max_queries[0] * 100;
	
	$min = $queries_sorted[0];
	$max = $queries_sorted[$max_element-1];
	
	
	print "Min queries:\t$min\n";
	print "Max queries:\t$max\n";
	printf("Average:\t%d\t%.2f%%\n", $average, $av_percent);
	print "Sum queries:\t$sum\n";
	
	# wenn Option u angegeben dann auch das RRD File aktualisieren
	if ( defined($rrdfile) ) {
		update_graph($rrdfile, $max, $min, $average);
	}
}


#
# Help Message ausgeben
#
sub help_message {
	print "Usage: stats_per_day.pl -f <stats file> -d <date [YYYYMMDD]> [-t <timeframe [hhmm-hhmm]>] -l <location>\n";
	print "\t-f\tDNS statistics file to be read\n";
	print "\t-d\tDate which will get analysed. Format: YYYYMMDD\n";
	print "\t-t\tOptional: Only analyse a specific timeframe of the day\n";
	print "\t-l\tDNS location. Ex: de1\n";
	print "\t-u\tOptional: RRD file to update\n";
	exit 0;
}

# 
# aktualisiert das RRD Graphic File
#
sub update_graph {
	my ($graphfile, $max, $min, $avg) = @_;
	my $timestamp = time;
	my $rrd;

	$rrd = RRDTool::OO->new( file => $graphfile );
	# wenn noch kein RRD File existiert
	if ( ! -e $graphfile ) {
		$rrd->create(
			step => $interval,
			data_source => { name => "max", type => "GAUGE" },
			data_source => { name => "min", type => "GAUGE" },
			data_source => { name => "avg", type => "GAUGE" },
			archive => { rows => 365 });
	}
				
	

	$rrd->update(time => $timestamp,
		     values => { max => $max, min => $min, avg => $avg }
		    );
}
