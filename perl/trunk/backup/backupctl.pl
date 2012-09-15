#!/usr/bin/perl
use strict;
use warnings;
use Log::Log4perl;
use Getopt::Long;
use Config::Simple;
use Net::Ping;
use Net::SSH::Perl;
use POSIX qw/strftime/;
use Fcntl qw(:flock);

my $help = 0;
my $debug = 0;
my %cfg;
my $config = "";
my $date = strftime("%Y%m%d", localtime);

Getopt::Long::Configure('bundling');
GetOptions(
	"c|config=s" => \$config,
	"d|debug" => \$debug,
	"h|help" => \$help,
);

if ( $help || $config eq "" ) {
	&help_msg;
	exit 0;
}

Config::Simple->import_from($config, \%cfg);

my $log_conf = "
	log4perl.rootLogger=$cfg{'log.loglevel'}, Logfile
	log4perl.appender.Logfile=Log::Log4perl::Appender::File
  	log4perl.appender.Logfile.filename=$cfg{'log.logfile'}
	log4perl.appender.Logfile.mode=append
	log4perl.appender.Logfile.layout=PatternLayout
	log4perl.appender.Logfile.layout.ConversionPattern=%d %-5p %c - %m%n
";

Log::Log4perl->init(\$log_conf);
our $log = Log::Log4perl->get_logger();

if ( ! flock(DATA, LOCK_EX|LOCK_NB) ) { 
	$log->error("Program already running."); 
	exit 1; 
}

$log->debug("Trying to ping $cfg{'backup_settings.host'} on port $cfg{'backup_settings.port'}");
my $p = Net::Ping->new();
$p->port_number($cfg{'backup_settings.port'});
if ( ! $p->ping($cfg{'backup_settings.host'}) ) {
	$log->info("Remote host: $cfg{'backup_settings.host'} is not available on port: $cfg{'backup_settings.port'}");
	exit 0;
}

# check files
foreach my $f ( $cfg{'backup_settings.key'},
		$cfg{'backup_settings.source_file'},
		$cfg{'backup_settings.exclude_file'} ) {
	&check_file($f);
}

my $ssh = Net::SSH::Perl->new($cfg{'backup_settings.host'}, 
			      identity_files => [ $cfg{'backup_settings.key'} ],
			      port => $cfg{'backup_settings.port'},
			      protocol => '2,1'
);
$ssh->login($cfg{'backup_settings.user'});
$log->debug("rotate directories on remote host");
my ($out, $err, $code) = $ssh->cmd("
	if [ ! -d $cfg{'backup_settings.destination_folder'}/backup.$date ]; then
		/bin/cp -Rpl $cfg{'backup_settings.destination_folder'}/\$(ls -1 $cfg{'backup_settings.destination_folder'} | tail -1) $cfg{'backup_settings.destination_folder'}/backup.$date
	fi
	if [ \$(ls -1 $cfg{'backup_settings.destination_folder'} | wc -l) -gt $cfg{'backup_settings.keep_days'} ]; then
		ls -1 -r --color=never $cfg{'backup_settings.destination_folder'}/ | tail -n 1 | xargs rm -rf
	fi
");
if ( $code ) {
	$log->error("rotate directories gave an error: $err");
}

$log->debug("closing ssh connection");
$ssh->cmd("exit");

$log->info("running rsync...");
system("/usr/bin/rsync -LpDtgHrz -e \"ssh -i $cfg{'backup_settings.key'} \\
-p $cfg{'backup_settings.port'}\" --log-file=$cfg{'log.logfile'} \\
--delete --exclude-from=$cfg{'backup_settings.exclude_file'} \\
--files-from=$cfg{'backup_settings.source_file'} / \\
$cfg{'backup_settings.user'}\@$cfg{'backup_settings.host'}:$cfg{'backup_settings.destination_folder'}/backup.$date");

sub check_file {
	my $file = shift;
	if ( ! -e $file ) {
		$log->error("File: $file does not exist");
		exit 1;
	}
}

sub help_msg {
	print <<'MSG';
backupctl.pl -c <config file> [-d] [-h]

-c, --config	config file to use
-d, --debug	debugging enabled
-h, --help	this help message


MSG
}

__DATA__
