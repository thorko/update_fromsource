#!/usr/bin/perl
use strict;
use warnings;
use DB_File;
use File::Tail ;
use Proc::Daemon;
use Proc::PID::File;
use Getopt::Long;
use Config::Simple;
use Log::Log4perl;
my $debug = 0;
my $config;
my %cc;

Getopt::Long::Configure('bundling');
GetOptions(
        "d|debug" => \$debug,
        "c|config=s"       => \$config);

die("Couldn't find config $config\n") if ( ! -e $config);
Config::Simple->import_from($config, \%cc) or die Config::Simple->error();

MAIN:
{
Proc::Daemon::Init();
if (Proc::PID::File->running()) {
	print "another prog is running\n";
	exit(0);
}
my %stats;
my $relay;
$SIG{'HUP'} = 'handler';

my $log_conf = "
    log4perl.rootLogger=$cc{loglevel}, Logfile
    log4perl.appender.Logfile=Log::Log4perl::Appender::File
    log4perl.appender.Logfile.filename=$cc{logfile}
    log4perl.appender.Logfile.mode=append
    log4perl.appender.Logfile.layout=PatternLayout
    log4perl.appender.Logfile.layout.ConversionPattern=[%r] %F %L %c - %m%n
  ";

Log::Log4perl->init(\$log_conf);
our $logger = Log::Log4perl->get_logger();

my $db = tie(%stats, "DB_File", "$cc{statsdb}", O_CREAT|O_RDWR, 0666, $DB_HASH)
        || die ("Cannot open $cc{statsdb}");

our $logref=tie(*LOG,"File::Tail",(name=>$cc{mail_log},debug=>$debug));

$logger->info("Started $0...");

while (<LOG>) {
        if (/status=sent/) {
                next unless (/ postfix\//) ;
                # count sent messages
		if(/postfix\/local.*to.*relay=local/) {
			$logger->debug("received one mail $_");
			$stats{"RECEIVED:local"} += 1;
		}
		if(/postfix\/smtp.*to.*relay=(?!local)/) {
			$logger->debug("sent one mail $_");
			$stats{"SENT:smtp"} += 1;
		}
                $db->sync;
        } elsif (/status=bounced/) {
                # count bounced messages
		$logger->debug("bounced one message $_");
                $stats{"BOUNCED:smtp"} += 1;
                $db->sync ;
        } elsif (/NOQUEUE: reject/) {
                # count rejected messages
		$logger->debug("rejected one message $_");
                $stats{"REJECTED:smtp"} += 1;
                $db->sync ;
        } elsif (/smtpd.*client=/) {
                # count received smtp messages
                $stats{"RECEIVED:smtp"} += 1;
                $db->sync ;
        } elsif (/sqlgrey.*grey.*new/) {
		$logger->debug("greylisted one message $_");
		$stats{"POSTGREY:greylist"} += 1;
		$db->sync ;
	} elsif (/spamd.*identified spam/) {
		$logger->debug("detected one spam $_");
		$stats{"SPAM:detected"} += 1;
		$db->sync ;
	} elsif (/X-Bogosity: Spam/) {
		$logger->debug("detected one spam $_");
		$stats{"SPAM:detected"} += 1;
		$db->sync ;
	} elsif (/X-Bogosity: (Ham|Unsure)/) {
		$logger->debug("detected one ham $_");
		$stats{"HAM:detected"} += 1;
		$db->sync ;
	} ;
} ;


sub handler {
	my $signal = shift;
	$SIG{'HUP'} = 'handler';
	print "Signal: SIG$signal caught!\n";
	if ($signal eq "HUP" ) {
		untie $logref;
		untie %stats;
		$logger->info("Stopped mailstats....");
		exit 0;
	}
}
}
