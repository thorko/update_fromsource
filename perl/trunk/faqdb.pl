#!/usr/bin/perl

use Getopt::Long;
use Config::Simple;
use URI::Escape;
use LWP::UserAgent;
use WWW::Mechanize;
use HTTP::Cookies;
use POSIX qw(strftime);

my $bank = "http://www.thorko.de/faqdb.html?id=6&keywords=something&category=All&search=search";
my $help = 0;
my $debug = 0;
my $query = "";


Getopt::Long::Configure('bundling');
GetOptions(
	"q|query=s" => \$query,
	"d|debug" => \$debug,
	"h|help" => \$help,
);


if ( $help || $query eq "") {
	&help_msg;
	exit 0;
}


my $outpage = "/tmp/out.html";

#my $date = strftime "%Y%m%d-%H%M%S", localtime;


my($ua) = LWP::UserAgent->new;
if ( defined($cfg{'url_settings.proxy'}) ) {
	$ua->proxy(['http', 'https'] => $cfg{'url_settings.proxy'});
} else {
	 $ua->proxy(['http', 'https']  => "");
}

print "request: $url\n" if ($debug);

my($req) = HTTP::Request->new(GET => $url);
my($raw) = $ua->request($req)->content;

sub help_msg{
	print <<'MSG';

faqdb.pl -q "query" [-d] [-h]

-q, --query	query faqdb for string
-d, --debug	debugging enabled
-h, --help	this help message

Script for sending sms through smstrade.de 
It uses a simple http(s) get call. smstrade.de api can be found
http://www.smstrade.de/pdf/SMS-Gateway_HTTP_API_v2_de.pdf

MSG
}
