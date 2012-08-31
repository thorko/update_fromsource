#!/usr/bin/perl
#
use strict;
use warnings;
use Zabbix::API;
use Zabbix::API::Host;
use Zabbix::API::Template;
use Zabbix::API::HostGroup;
use Log::Log4perl qw(:easy);
use Getopt::Long;
use Data::Dump qw(dd);


my $user = "Admin";
my $pass = "zabbix";
my $hostname = "";
my $port = "";
my $help = 0;
my $debug = 0;

my $api_url = "http://zabbix.thorko.de/zabbix/api_jsonrpc.php";

sub help {
   print <<'EOF'
Usage: ./zabbix_add_jmx_interfaces.pl -H <host> -P <port> [-U] [-h] [-d]
-H, --host               dns hostname for jmx interface
-P, --port               port for jmx interface
-U, --url                url of zabbix server api
-h, --help		 print this help message
-d, --debug
EOF
}

Getopt::Long::Configure ("bundling");
GetOptions( 
	"H|host=s" => \$hostname,
	"P|port=s" => \$port,
	"U|url=s" => \$api_url,
	"h|help" => \$help,
	"d|debug" => \$debug
);

if ( $help || $hostname eq "" || $port eq "" ) {
	help;
	exit 0;
}

init_logger();
my $zabbix = Zabbix::API->new(server => $api_url, verbosity => $debug);

eval { $zabbix->login(user => $user, password => $pass ) };
if ($@) { die 'could not authenticate' };

my $host_o = $zabbix->fetch('Host', params => { filter => { host => $hostname } })->[0];
my $host_interfaces_o = $zabbix->query(method => 'host.get', params => { selectInterfaces => "extend", filter => { host => $hostname } });

foreach my $ifaces (@{$host_interfaces_o}) {
      foreach my $iface ( values %{$ifaces->{'interfaces'}} ) {
         if ( $iface->{'type'} == 4 ){
            INFO("A JMX interface already exists for $hostname");
            dd($iface) if($debug);
            exit 0;
         }
      }
}

INFO("zabbix - add JMX interface for host $hostname");
eval {
   $zabbix->query(method => 'hostinterface.create', params => { hostid => $host_o->id,  main => 1, type => 4, useip => 0, ip => "", dns => "$hostname", port => $port } );
};
if ($@) { ERRORDIE("could not add jmx interface: " . $@) };
