#!/usr/bin/perl
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use Getopt::Long;
use Config::Simple;
use Clipboard;
use GnuPG qw( :algo );
use Term::ReadKey;
use Switch;
use File::Grep qw(fgrep);
use Data::Dumper;

my $help = 0;
my $debug = 0;
my $config = "/home/thorko/.pwsafe.conf";
my $cfg_handle;
our %cfg;
my $toclip = 0;
my $command;
my %stats;

# stats{sitename}, stats{sitelink}, 
# stats{smtp_server}, stats{pop3_server}, stats{imap_server} 
# stats{username}, stats{password}
# stats{sitetype}

our $gpg = new GnuPG();


Getopt::Long::Configure('bundling');
GetOptions(
	"c|config=s" => \$config,
	"d|debug" => \$debug,
	"t|toclip" => \$toclip,
	"o|option=s" => \$command,
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

########
# subs #
########
sub get {
	my $password;
	my $tmp_pass = "/tmp/.passwd.db";
	print "Your regex pattern you look for: ";
	chomp(my $pattern = ReadLine(0));
	ReadMode('noecho');
	print "Enter your Passphrase: ";
	chomp(my $passphrase = ReadLine(0));
	
	# decrypt
	eval {
		$gpg->decrypt( ciphertext => $cfg{'file.pwfile'}, output => $tmp_pass, passphrase => $passphrase, symmetric => "true");
	};
	ReadMode('restore');
	print "\n";
	my @match = fgrep { /$pattern/ } $tmp_pass;
	foreach (@match) {
		foreach my $i (keys $_->{'matches'}) {
			$username = (split(/[\t]+/, $_->{'matches'}{$i}))[2];
			$password = (split(/[\t]+/, $_->{'matches'}{$i}))[3];
			if ( !$cfg{'toclip'} ) {
				print "Username: $username, Password: $password\n";
			} else {
				print "Username: $username\n";
				Clipboard->copy($password) if ($cfg{'toclip'});
			}
		}
	}
	unlink($tmp_pass);
}


############
# end subs #
############

# get config
$cfg_handle = new Config::Simple($config);
Config::Simple->import_from($config, \%cfg);

$cfg{'toclip'} = 1 if ( $toclip );
$cfg{'debug'} = 1 if ( $debug );

#$gpg->encrypt(plaintext => "/tmp/.pwsafe", output => $cfg{'file.pwfile'} );

switch($command) {
	case "get"	{ get(); }
	case "add"	{ print 1; }
	case "edit"	{ print 1; }
	case "delete"	{ print 1; }
}


sub help_msg{
	print <<'MSG';

pwsafe.pl [-c <config>] -o <option> [-d] [-h] [-t]

-c, --config	config file to use
-o, --option	option can be "edit", "get", "add", "delete"
		list will list all passwords
-t, --toclip	will paste the password to clipboard
-d, --debug	debugging enabled
-h, --help	this help message

pwsafe is a password manager. It stores the passwords in an encrypted file.
MSG
}
