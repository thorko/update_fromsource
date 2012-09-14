#!/usr/bin/perl
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use Getopt::Long;
use Config::Simple;
use URI::Escape;
use LWP::UserAgent;


my $help = 0;
my $debug = 0;
my $to = "";
my $message = "";
my $config = "/usr/share/zabbix/etc/sms_alert.conf";
my $cfg_handle;
my %cfg;
my %apiargs;
my $url;


# smstrade response code error
my @response_code_arr;
$response_code_arr[0] = "Keine Verbindung zum Gateway";
$response_code_arr[10] = "Empfänger fehlerhaft";
$response_code_arr[20] = "Absenderkennung zu lang";
$response_code_arr[30] = "Nachrichtentext zu lang";
$response_code_arr[31] = "Messagetyp nicht korrekt";
$response_code_arr[40] = "Falscher SMS-Typ";
$response_code_arr[50] = "Fehler bei Login";
$response_code_arr[60] = "Guthaben zu gering";
$response_code_arr[70] = "Netz wird von Route nicht unterstützt";
$response_code_arr[71] = "Feature nicht über diese Route möglich";
$response_code_arr[80] = "SMS konnte nicht versendet werden";
$response_code_arr[90] = "Versand nicht möglich";
$response_code_arr[100] = "SMS wurde erfolgreich versendet";

Getopt::Long::Configure('bundling');
GetOptions(
	"c|config=s" => \$config,
	"d|debug" => \$debug,
	"h|help" => \$help,
);

$to = $ARGV[0];
$message = $ARGV[2];

if ( $help || $to eq "" || $message eq "") {
	&help_msg;
	exit 0;
}

if ( ! -f $config ) {
	print "config file: $config does not exist!\n";
	exit 1;
}

init_logger();

if ( ! ($to =~ /\d+/) ) {
	ERRORDIE("smstrade: To isn't numeric");
}

# get config
$cfg_handle = new Config::Simple($config);
Config::Simple->import_from($config, \%cfg);
#$cfg{'block.var'} = $cfg{'login.key'}
$apiargs{"key"}=$cfg{'login.key'};
$to =~ s/^0/49/;
$apiargs{"to"} = $to;
$apiargs{"message"}=$message;
$apiargs{"route"}=$cfg{'sms_settings.type'};
$apiargs{"charset"}=$cfg{'sms_settings.charset'};
$apiargs{"from"}=$cfg{'sms_settings.sender'} if ( defined($cfg{'sms_settings.sender'}) );
$apiargs{"dlr"}=$cfg{'sms_settings.dlr'} if ( defined($cfg{'sms_settings.dlr'}) );
$apiargs{"cost"}=$cfg{'sms_settings.cost'} if ( defined($cfg{'sms_settings.cost'}) );
$apiargs{"debug"}=$cfg{'sms_settings.debug'} if ( defined($cfg{'sms_settings.debug'}) );
$apiargs{"message_id"}=$cfg{'sms_settings.message_id'} if ( defined($cfg{'sms_settings.message_id'}) );

$url = $cfg{'url_settings.url'};
foreach my $k (keys %apiargs)  {
	$url .= "$k=".uri_escape($apiargs{$k})."&";
}

my($ua) = LWP::UserAgent->new;
if ( defined($cfg{'url_settings.proxy'}) ) {
	$ua->proxy(['http', 'https'] => $cfg{'url_settings.proxy'});
} else {
	 $ua->proxy(['http', 'https']  => "");
}

print "request: $url\n" if ($debug);

my($req) = HTTP::Request->new(GET => $url);
my($raw) = $ua->request($req)->content;

INFO("smstrade: ".$response_code_arr[$raw]." -- To: $to Message: \"$message\"");

print "response: ".$response_code_arr[$raw]."\n" if ($debug);

sub help_msg{
	print <<'MSG';

sms_alert.pl <recipient> <message> [-c <config file>] [-d] [-h]

-c, --config	config file to use
-d, --debug	debugging enabled
-h, --help	this help message

Script for sending sms through smstrade.de 
It uses a simple http(s) get call. smstrade.de api can be found
http://www.smstrade.de/pdf/SMS-Gateway_HTTP_API_v2_de.pdf

MSG
}
