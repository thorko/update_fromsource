#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Long;
use Capture::Tiny ':all';

my $storage;
my $help = 0;
my $bg = 0;
my $sscs = '/usr/local/bin/sscs';

Getopt::Long::Configure('bundling');
GetOptions(
  "h|help" => \$help,
  "b|background" => \$bg,
  "s|storage=s" => \$storage);


if ( $help || !$storage ) {
  &help();
  exit(0);
}

sub help {
print <<'EOF'
Usage: check_storage.pl -s <storage system> 
EOF
}

if ( ! -f $sscs ) {
	print "sscs command not found in /usr/local/bin\n";
	exit 1;
}

my $state_file = "/tmp/$storage.state";
my $timeout = 50;     # timeout for the asynchronous sscs call

if ( $bg ) {
	eval {
		local $SIG{ALRM} = sub { open FD, ">$state_file"; print FD "0"; close FD; exit 0; };
		alarm $timeout;
		my ($stdout,$stderr,$exit);
		($stdout,$stderr,$exit) = capture {
			system("/usr/local/bin/sscs list array $storage | grep -P 'Health Status:'");
		};

		open FD, ">$state_file";
		if($stdout =~ /Health Status:\s+OK/) {
			print FD "1";
		} else {
			print FD "0";
		}
		close FD;

		alarm 0;
		exit 0;
	}
	
}


# run check asynchronously
my $pid = fork();

if($pid == 0) {
	# this is the child
	eval {
		local $SIG{ALRM} = sub { open FD, ">$state_file"; print FD "0"; close FD; exit 0; };
		alarm $timeout;
		# check the health status
		system("$0 -s $storage -b > /dev/null 2>&1 &");
		alarm 0;
		exit 0;
	}
} else {
	# this is the parent
	
	# get the current state
	if ( -f $state_file ) {
		my $status;
		open FD, "<$state_file";
		read FD, $status, 4;
		close FD;
		if($status) {
			print "$status";
		} else {
			print "0";
		}
		# if we have read the state delete the file
		# otherwise we would never know if the child 
		# has successfully created it
		qx{/bin/rm -f $state_file};
	} else {
		print "0";
	}
	exit 0;	
}
