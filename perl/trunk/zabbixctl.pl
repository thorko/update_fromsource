#!/usr/bin/perl
#
use strict;
use warnings;
use DBI;
use Config::Simple;
use Getopt::Long;
use Data::Dump qw(dd);

my $config;
my $help = 0;
my $debug = 0;
my $cfg_handle;
my %cfg;
my $dsn;

sub help_msg {
   print <<'EOF'
Usage: ./zabbixctl.pl [-c <config>] [-h] [-d]
-c, --config		 config file use
-h, --help		 print this help message
-d, --debug
EOF
}

Getopt::Long::Configure ("bundling");
GetOptions( 
	"c|config=s" => \$config,
	"h|help" => \$help,
	"d|debug" => \$debug
);

if ( $help ) {
	help_msg;
	exit 0;
}
$config = defined($config) ? $config : "/etc/zabbix/zabbixctl.conf";
$cfg_handle = new Config::Simple($config);
Config::Simple->import_from($config, \%cfg);

$dsn = "DBI:$cfg{'driver'}:database=$cfg{'database'}:$cfg{'host'}:$cfg{'port'}" if ($cfg{'driver'} eq 'mysql');
$dsn = "DBI:$cfg{'driver'}:dbname=$cfg{'database'};host=$cfg{'host'};port=$cfg{'port'}"   if ($cfg{'driver'} eq 'Pg');
$dsn = "DBI:$cfg{'driver'}:$cfg{'database'}"          if ($cfg{'driver'} eq 'Oracle');
my $dbh = DBI->connect($dsn, $cfg{'user'}, $cfg{'pass'}) or die $DBI::errstr;

my $sth = $dbh->prepare("");
$sth->execute();
my $dbh = DBI->connect($dsn, $cfg{'user'}, $cfg{'pass'}) or die $DBI::errstr;

my $sth = $dbh->prepare("$cfg{'statement'}") or die "Can't prepare statement $DBI::errstr\n";
$sth->execute or die "Can't execute SQL statement: $DBI::errstr\n";

$dbh->disconnect;
exit 0;
