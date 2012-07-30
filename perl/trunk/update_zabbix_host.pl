#!/usr/bin/perl
#
use strict;
use warnings;
use Zabbix::API;
use Zabbix::API::Host;
use Zabbix::API::Template;
use Getopt::Long;
use Data::Dump qw(dd);


my $user = "Admin";
my $pass = "zabbix";
my $hostname = "";
my $template = "";
my $initial_template = "";
my $help = 0;
my $debug = 0;

my $api_url = "http://sysmon-1.rz2012.adm.denic.de/zabbix/api_jsonrpc.php";

sub help {
   print <<'EOF'
Usage: ./update_zabbix_host.pl -H <host> -T <template> -I <initial template> [-h] [-d]
-H, --host               host to update
-T, --template           template to be added
-I, --initial_template   initial template, which will be cleared
-h, --help		 print this help message
-d, --debug
EOF
}

Getopt::Long::Configure ("bundling");
GetOptions( 
	"H|host=s" => \$hostname,
	"T|template=s" => \$template,
	"I|initial_template=s" => \$initial_template,
	"h|help" => \$help,
	"d|debug" => \$debug
);

if ( $help || $hostname eq "" || $template eq "" || $initial_template eq "") {
	help;
	exit 0;
}

my $zabbix = Zabbix::API->new(server => $api_url, verbosity => $debug);

eval { $zabbix->login(user => $user, password => $pass ) };
if ($@) { die 'could not authenticate' };

my $host_o = $zabbix->fetch('Host', params => { filter => { host => $hostname } })->[0];
my $template_exists = $zabbix->query(method => 'template.get', params => { output => 'extend', hostids => [$host_o->id]  });

my $initial_template_o = $zabbix->fetch('Template',  params => { filter => { host => $initial_template } } )->[0];
my $template_o = $zabbix->fetch('Template',  params => { filter => { host => $template } } )->[0];

my @temp_array;
my $x->{'templateid'} = $template_o->id;
push @temp_array, $x;

foreach my $t (@{$template_exists}) {
	if ( $t->{'hostid'} != $initial_template_o->id ) {
		$x->{'templateid'} = $t->{'hostid'};
		push @temp_array, $x;
	}
	if ( $t->{'hostid'} == $template_o->id ) {
		print "Template already linked: ".$t->{'host'}."\n";
		exit 0;
	}
}

$zabbix->query(method => 'host.update', params => { hostid => $host_o->id, templates => \@temp_array, templates_clear => [{templateid => $initial_template_o->id}]  } );

