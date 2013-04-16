#!/usr/bin/perl
eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell

use strict;
use warnings;
use DB_File;
use File::Tail;
use Pod::Usage;
use Proc::Daemon;
use Proc::PID::File;
use Getopt::Long;
use Config::Simple;
use Log::Log4perl;
my $debug = 0;
my $config;
my %cc;
my $cfghandle;

Getopt::Long::Configure('bundling');
GetOptions(
        "d|debug" => \$debug,
        "c|config=s"       => \$config);

print("ERROR: Couldn't find config $config") if ( ! -e $config);
$cfghandle = new Config::Simple($config);
Config::Simple->import_from($config, \%cc) or print("ERROR: ".Config::Simple->error());
my $resptime = $cc{'default.timepattern'};
my $regex = $cfghandle->get_block('regex');

MAIN:
{
my %stats;
my $relay;
$SIG{'HUP'} = 'handler';


Proc::Daemon::Init();
if (Proc::PID::File->running()) {
	print( "ERROR: another prog is running");
}
my $log_conf = "
    log4perl.rootLogger=".$cc{'default.loglevel'}.",Logfile,SYSLOG
    log4perl.appender.Logfile=Log::Log4perl::Appender::File
    log4perl.appender.Logfile.filename=".$cc{'default.logfile'}."
    log4perl.appender.Logfile.mode=append
    log4perl.appender.Logfile.layout=PatternLayout
    log4perl.appender.Logfile.layout.ConversionPattern=[%r] %F %L %c - %m%n
    log4perl.appender.SYSLOG           = Log::Dispatch::Syslog
    log4perl.appender.SYSLOG.min_level = ".lc($cc{'default.loglevel'})."
    log4perl.appender.SYSLOG.ident     = logstats.pl
    log4perl.appender.SYSLOG.facility  = daemon
    log4perl.appender.SYSLOG.layout    = Log::Log4perl::Layout::SimpleLayout
  ";
Log::Log4perl->init(\$log_conf);
our $logger = Log::Log4perl->get_logger();

my $db = tie(%stats, "DB_File", $cc{'default.statsdb'}, O_CREAT|O_RDWR, 0666, $DB_HASH);

our $logref=tie(*LOG,"File::Tail",(name=>$cc{'default.service_log'},debug=>$debug,resetafter=>10,interval=>5,maxinterval=>2));

# initialize all counters to zero
$stats{'responsetime'} = 0;
foreach my $order (keys %$regex) {
     $logger->debug("Set order $order to 0");
     $stats{$order} = 0;
     $db->sync;
}

$logger->info("Started $0...");

while (<LOG>) {
   foreach my $order (keys %$regex) {
       if (/$regex->{$order}/) {
             $logger->debug("$order Order: $_");
	     $stats{$order} += 1;
	     $db->sync;
       }
   }
   if (/$resptime/) {
         # close the db before getting current value
	 # otherwise it doesn't work
	 untie %stats;
	 $db = tie(%stats, "DB_File", $cc{'default.statsdb'}, O_CREAT|O_RDWR, 0666, $DB_HASH);
	 my $value = 0;
         my $status = $db->get("responsetime", $value);
         my ($tt) = $_ =~ m/$resptime/;
         if ($value < $tt) {
            $logger->debug("Responsetime: $tt");
            $db->put('responsetime', $tt);
            $db->sync; 
         }
   }
};

sub handler {
	my $signal = shift;
	$SIG{'HUP'} = 'handler';
	$logger->debug("Signal: SIG$signal caught!");
	if ($signal eq "HUP" ) {
		untie $logref;
		untie %stats;
		$logger->info("Stopped logstats....");
		exit 0;
	}
}
}
