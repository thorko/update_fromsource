#!/usr/bin/perl
use strict;
use warnings;
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

our $tmp_pass = "/tmp/.passwd.db";
our $gpg = new GnuPG();

Getopt::Long::Configure('bundling');
GetOptions(
	"c|config=s" => \$config,
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
sub decrypt {
	ReadMode('noecho');
	print "Enter your Passphrase: ";
	chomp(my $passphrase = ReadLine(0));
	
	# decrypt
	eval {
		$gpg->decrypt( ciphertext => $cfg{'file.pwfile'}, output => $tmp_pass, passphrase => $passphrase, symmetric => "true");
	};
	ReadMode('restore');
	print "\n";
}

sub get {
	my $password;
	print "Your regex pattern you look for: ";
	chomp(my $pattern = ReadLine(0));
	decrypt();
	my @match = fgrep { /$pattern/ } $tmp_pass;
	foreach (@match) {
		foreach my $i (keys $_->{'matches'}) {
			my $username = (split(/[\t]+/, $_->{'matches'}{$i}))[2];
			my $password = (split(/[\t]+/, $_->{'matches'}{$i}))[3];
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

sub add {
	print "Sitename: ";
	my $sitename = ReadLine(0);
	print "Sitelink: ";
	my $sitelink = ReadLine(0);
	print "Username: ";
	my $username = ReadLine(0);
	print "Password: ";
	my $password = ReadLine(0);
	print "Sitetype: ";
	my $sitetype = ReadLine(0);
	decrypt();
	system('echo -e "$sitename\t$sitelink\t$username\t$password\t$sitetype" >> $tmp_pass');
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
	case "add"	{ add(); }
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
-h, --help	this help message

pwsafe is a password manager. It stores the passwords in an encrypted file.
MSG
}
