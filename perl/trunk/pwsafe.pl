#!/usr/bin/perl
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use Getopt::Long;
use Config::Simple;
use Clipboard;
use GnuPG qw( :algo );

my $help = 0;
my $debug = 0;
my $config = "~/.pwsafe.conf";
my $cfg_handle;
my %cfg;
my $toclip = 0;
my $command;

Getopt::Long::Configure('bundling');
GetOptions(
	"c|config=s" => \$config,
	"d|debug" => \$debug,
	"t|toclip" => \$toclip,
	"o|option" => \$command,
	"h|help" => \$help,
);

if ( $help || $command eq "" ) {
	&help_msg;
	exit 0;
}

if ( ! -f $config ) {
	print "config file: $config does not exist!\n";
	exit 1;
}

init_logger();

# get config
$cfg_handle = new Config::Simple($config);
Config::Simple->import_from($config, \%cfg);
$cfg{'file.pwfile'};
$cfg{'file.cipher'};

my $gpg = new GnuPG(options => "--cipher-algo ".$cfg{'file.cipher'}." --no-use-agent");



Clipboard->copy("test");

sub help_msg{
	print <<'MSG';

pwsafe.pl [-c <config>] -o <option> [-d] [-h] [-t]

-c, --config	config file to use
-o, --option	option can be "edit", "get", "list"
		list will list all passwords
-t, --toclip	will paste the password to clipboard
-d, --debug	debugging enabled
-h, --help	this help message

pwsafe is a password manager. It stores the passwords in an encrypted file.
MSG
}
