#!/usr/bin/perl
#
use strict;
use warnings;
use Zabbix::API;
use Zabbix::API::Host;
use Zabbix::API::Template;
use Zabbix::API::HostGroup;
use Zabbix::API::Maintenance;
use Log::Log4perl qw(:easy);
use Denic::Log4perl::Conf;
use Config::Simple;
use Getopt::Long;


my $hostname = "";
my $group = "";
my $help = 0;
my $debug = 0;
my $period = "";
my $name = "";
my $config;
my $api_url;
my %cfg;


sub convert_period {
	my ($timespec) = @_;
	my $seconds = 0;
	my ($n, $x) = $timespec =~ m/(\d+)([a-z]+)/;
	if ($x eq "h") {
		$seconds = ($n * 3600);
	} elsif ( $x eq "min") {
		$seconds = ($n * 60);
	} elsif ($x eq "d") {
		$seconds = ($n * 86400);
	}
	return $seconds;	
}

sub help {
   print <<'EOF'
Usage: ./zbx_set_maintenance.pl [-c <config>] -H <host> -G <group> -P <period> -N <maintenance name> [-U] [-h] [-d]
-c, --config             config file to use
-H, --host               host to set maintenance for
			 hosts seperated by comma
-G, --group		 hostgroup to set maintenance for
			 hostgroups seperated by comma
-P, --period		 time inteval to use (1h, 1min, 1d)
-N, --name		 the name of the maintenance period. Please use your initials or name, 
			 so every knows who has set this maintenance
-U, --url                URL of the zabbix api
-h, --help		 print this help message
-d, --debug

Either Host or Group or both has to be specified.
EOF
}

Getopt::Long::Configure ("bundling");
GetOptions( 
	"c|config=s" => \$config,
	"H|host=s" => \$hostname,
	"P|period=s" => \$period,
	"G|group=s" => \$group,
	"N|name=s" => \$name,
	"U|url=s" => \$api_url,
	"h|help" => \$help,
	"d|debug" => \$debug
);

if ( $help || ($hostname eq "" && $group eq "") || $period eq "" || $name eq "" ) {
	help;
	exit 0;
}	

init_logger();
$config = defined($config) ? $config : "/data/scripts/zabbix_api.conf";

if( ! -e $config ) {
  ERRORDIE("config file $config doesn't exist.");
}
my $cfg_handle = new Config::Simple($config);
Config::Simple->import_from($config, \%cfg);

my $user = $cfg{'api.user'};
my $pass = $cfg{'api.password'};
$api_url = $cfg{'api.url'};

my $zabbix = Zabbix::API->new(server => $api_url, verbosity => $debug);

eval { $zabbix->login(user => $user, password => $pass ) };
if ($@) { ERRORDIE('could not authenticate'); };

my @hostids;
foreach (split(",",$hostname)) {
	my $host_o = $zabbix->fetch('Host', params => { filter => { host => $_ } })->[0];
	push @hostids, $host_o->id;
}

#my $hostgroup_exists = $zabbix->query(method => 'hostgroup.get', params => { output => 'extend', hostids => [$host_o->id] });
my @groupids;
foreach (split(",",$group)) {
	my $hostgroup_o = $zabbix->fetch('HostGroup', params => { filter => { name => [$group] }})->[0];
	push @groupids, $hostgroup_o->id;
}

my $seconds = convert_period($period);
my $active_till = ($seconds < 86400) ? 86400 : $seconds;
eval {
	$zabbix->query(method => 'maintenance.create', params => { name => $name, active_since => time, active_till => (time + $active_till), timeperiods => [{timeperiod_type => 0, period => $seconds}], hostids => \@hostids, groupids => \@groupids } );
};
if ($@) { ERRORDIE("Setting maintenance failed: ".$@); } else { INFO("Maintenance set successful.") }



=head1 SYNOPSIS

  Usage: ./zbx_set_maintenance.pl [-c <config>] -H <host> -G <group> -P <period> -N <maintenance name> [-U] [-h] [-d]
  -c, --config           config file to use
  -H, --host             host(s) to set maintenance for
			 hosts seperated by comma
  -G, --group		 hostgroup(s) to set maintenance for
			 hostgroups seperated by comma
  -P, --period		 time inteval to use (1h, 1min, 1d)
  -N, --name		 the name of the maintenance period. Please use your initials or name, 
  			 so every knows who has set this maintenance
  -U, --url              URL of the zabbix api
  -h, --help		 print this help message
  -d, --debug
  
  Either Host or Group or both has to be specified.

=head1 DESCRIPTION

B<zbx_set_maintenance.pl> will set a maintenance for host and/or group for the given period

=cut

