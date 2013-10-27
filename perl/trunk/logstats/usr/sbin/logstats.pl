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
use Data::Dumper;
my $debug = 0;
my $config = "";
my $help = 0;

Getopt::Long::Configure('bundling');
GetOptions(
        "d|debug" => \$debug,
	"h|help" => \$help,
        "c|config=s"  => \$config);

if ( $config eq "" || $help ) {
	&help_msg;
	exit 0;
}



MAIN:
{
my %stats;
my $relay;
$SIG{'HUP'} = 'handler';
$SIG{'QUIT'} = 'handler';


#Proc::Daemon::Init();
#if (Proc::PID::File->running()) {
#	print( "ERROR: another prog is running");
#}

# read the config file
my ($cc) = read_config($config);
my %regex = map { $_ => $cc->{$_} } grep { /^regex/ } keys(%$cc);

my $log_conf = "
    log4perl.rootLogger=".$cc->{'default.loglevel'}.",Logfile,SYSLOG
    log4perl.appender.Logfile=Log::Log4perl::Appender::File
    log4perl.appender.Logfile.filename=".$cc->{'default.logfile'}."
    log4perl.appender.Logfile.mode=append
    log4perl.appender.Logfile.layout=PatternLayout
    log4perl.appender.Logfile.layout.ConversionPattern=[%r] %F %L %c - %m%n
    log4perl.appender.SYSLOG           = Log::Dispatch::Syslog
    log4perl.appender.SYSLOG.min_level = ".lc($cc->{'default.loglevel'})."
    log4perl.appender.SYSLOG.ident     = logstats.pl
    log4perl.appender.SYSLOG.facility  = daemon
    log4perl.appender.SYSLOG.layout    = Log::Log4perl::Layout::SimpleLayout
  ";
Log::Log4perl->init(\$log_conf);
our $logger = Log::Log4perl->get_logger();

my $db = tie(%stats, "DB_File", $cc->{'default.statsdb'}, O_CREAT|O_RDWR, 0666, $DB_HASH);

our $logref=tie(*LOG,"File::Tail",(name=>$cc->{'default.service_log'},debug=>$debug,resetafter=>10,interval=>5,maxinterval=>2));

# initialize all counters to zero
foreach my $counter (keys %regex) {
     $logger->debug("Set all $counter to 0");
     $stats{$counter} = 0;
     $db->sync;
}

$logger->info("Started $0...");

while (<LOG>) {
   foreach my $counter (keys %regex) {
       if (/$regex{$counter}/) {
             $logger->debug("$counter: $_");
	     $stats{$counter} += 1;
	     $db->sync;
       }
   }
};

sub read_config {
	my %cc;
	my ($config) = @_;
	print("ERROR: Couldn't find config $config") if ( ! -e $config);
	my $cfghandle = new Config::Simple($config);
	Config::Simple->import_from($config, \%cc) or print("ERROR: ".Config::Simple->error());
	return (\%cc);
}

sub handler {
	my $signal = shift;
	$SIG{'HUP'} = 'handler';
	$SIG{'QUIT'} = 'handler';
	$logger->debug("Signal: SIG$signal caught!");
	if ($signal eq "QUIT" ) {
		untie $logref;
		untie %stats;
		$logger->info("Stopped logstats....");
		exit 0;
	} elsif ($signal eq "HUP" ) {
		$logger->debug("Reload config...");
		$cc = read_config($config);
	}
}
}

sub help_msg {
print<<'HELP'
logstats.pl -c <config file> [-d]

-c, --config    config file to use
-d, --debug     enable debug mode

HELP
}
