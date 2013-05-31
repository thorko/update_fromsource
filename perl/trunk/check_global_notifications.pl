#!/usr/bin/perl
# this script will parse the retention.dat file
# and search for disabled notifications
# it sends a mail about those hosts / services 
# hosts / services can be specified in disabled_notifications.conf
# to be excluded til resubmission date.

use strict;
use Fcntl qw(:flock);
use Sys::Hostname;
use Getopt::Long;

# config variables
my $ret_file;
my $recipient;
my $help = 0;
my $hostname = hostname;

sub help_msg{
  print <<'MSG';
./check_global_notifications.pl -s <retention file> -r <recipient> [-h]
MSG
}


Getopt::Long::Configure('bundling');
GetOptions(
  "s|retentionfile=s" => \$ret_file,
  "r|recipient=s" => \$recipient,
  "h|help" => \$help,
);

if($help || $ret_file eq "" || $recipient eq "" ) {
	help_msg;
	exit 0;
}

# enable locking
unless (flock(DATA, LOCK_EX|LOCK_NB)) {
	exit_error("$0 is already running. Exiting.\n");
}
$/="";
open RET, "<$ret_file" or die("Couldn't open $ret_file");
while(<RET>) {
	if( $_ =~ /.*programstatus\s+{.*enable_notifications=0.*/s) {	
		open(SENDMAIL,"|echo 'CRITICAL: global notification disabled on $hostname'| /bin/mail -s \"Notifications disabled on $hostname\" $recipient");
		close(SENDMAIL);
		exit 2;
	}
}

__DATA__

