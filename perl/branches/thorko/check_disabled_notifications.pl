#!/usr/bin/perl
#$ID$
# this script will parse the retention.dat file
# and search for disabled notifications
# it sends a mail about those hosts / services 
# hosts / services can be specified in disabled_notifications.conf
# to be excluded til resubmission date.

use strict;
use Fcntl qw(:flock);
use Sys::Hostname;

# config variables
#my $ret_file="/usr/local/nagios/var/retention.dat";
my $ret_file="/usr/local/nagios/var/status.dat";
our $mailto="kohlhepp\@denic.de";
my $mail="/tmp/disabled_notifications.mail";
my $conf="/usr/local/nagios/bin/disabled_notifications.conf";
our $hostname = hostname;
my ($year, $month, $day) = (localtime(time))[5,4,3];
my $date = sprintf("%04d%02d%02d", $year+1900, $month+1, $day);

my ($found, $host, $service, $not);
my %not_disabled, my %conf;
my $x = 0;
my $debug = $ARGV[0];

# enable locking
unless (flock(DATA, LOCK_EX|LOCK_NB)) {
	exit_error("$0 is already running. Exiting.\n");
}

# read config file
if ( -e $conf ) {
	open CONF, "<$conf" or exit_error("Couldn't open $conf");
	while(my $line = <CONF>) {
		# skip comments
		if ( $line !~ /^#/) { 
			($conf{$x}{'host'}, $conf{$x}{'service'}, $conf{$x}{'resubdate'}) = split(/\s+/,$line);
			$x++;
		}
	}
	close CONF;
}

$x = 0;

open RET, "<$ret_file" or exit_error("Couldn't open $ret_file");
while(my $line = <RET>) {
	#if( $line =~ /^(host|service) \{/ ) {	
	if( $line =~ /^(hoststatus|servicestatus) \{/ ) {	
		# set flag to parse the block
		$found = "found";
	}

	if ( $found eq "found" ) {
		if ( $line =~ /host_name/ ) {
			$host = (split(/=/, $line))[1];
			chomp $host;
			
		}
		#if ( $line =~ /display_name/ ) {
		if ( $line =~ /service_description/ ) {
			$service = (split(/=/, $line))[1];
			chomp $service;
		}
		# found notifications disabled
		if ( $line =~ /notifications_enabled=0/ ) {
			$not = (split(/=/, $line))[1];
			chomp $not;
			# add this host or service only if notifications disabled
			$not_disabled{$x}{'not'} = $not;
			$not_disabled{$x}{'host'} = $host;
			$not_disabled{$x}{'service'} = $service;
			# set flag done
			$found = "done";
			$x++;
		}
	}

}

close RET;

open MAIL, ">$mail" or exit_error("Couldn't open $mail");
# set exclusive lock
flock(MAIL, LOCK_EX);
# print header
print MAIL "Host\t\t\tService\t\tNotifications\n";
print MAIL "-" x 60, "\n";
for (my $l = 0; $l < scalar keys %not_disabled; $l++) {
	my $skip = 0;
	# only print line if not specified in conf
	foreach my $k (keys %conf) {
		if($conf{$k}->{'host'} eq $not_disabled{$l}->{'host'} &&
		   (!$conf{$k}->{'service'} || $conf{$k}->{'service'} eq $not_disabled{$l}->{'service'}) &&
		   $date < $conf{$k}->{'resubdate'}) {
			$skip = 1;
		}
	}
	if ( ! $skip ) {
		print MAIL $not_disabled{$l}->{'host'}."\t".$not_disabled{$l}->{'service'}."\t".$not_disabled{$l}->{'not'}."\n";
	}
}
close MAIL;

if ( $debug eq "-d" ) {
	open (CMD,"|/bin/cat $mail");
	close CMD;
} else {
	# send mail
	open (SENDMAIL,"|/bin/cat $mail |/bin/mail -s \"Disabled Notifications on $hostname\" $mailto");
	close SENDMAIL;
}

sub exit_error {
	(my $err_msg) = @_;
	open (SENDMAIL,"|echo \"$err_msg\" |/bin/mail -s \"Disabled Notifications on $hostname\" $mailto");
	close SENDMAIL;
	exit(1);
}
__DATA__

