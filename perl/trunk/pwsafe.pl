#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Config::Simple;
use Clipboard;
use Term::ReadKey;
use Switch;
use File::Grep qw(fgrep);
use File::Basename;
#use Data::Dumper;

my $help = 0;
my $debug = 0;
my $config = $ENV{"HOME"}."/.pwsafe.conf";
my $cfg_handle;
our %cfg;
my $toclip;
my $command;
my %stats;
my $lookup;

our $tmp_pass = "/tmp/.passwd.db";

Getopt::Long::Configure('bundling');
GetOptions(
	"c|config=s" => \$config,
	"t|toclip=i" => \$toclip,
	"o|option=s" => \$command,
	"l|look=s"   => \$lookup,
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
	system("gpg -d --no-use-agent --passphrase $passphrase -o $tmp_pass $cfg{'file.pwfile'}");
	ReadMode('restore');
	print "\n";
}

sub encrypt {
	my ($passphrase, $passphrase2);
	ReadMode('noecho');
	do {
		print "\nEnter your Passphrase to encrypt new file: ";
		chomp($passphrase = ReadLine(0));
		print "\nRepeat Passphrase: ";
		chomp($passphrase2 = ReadLine(0));
	} until ($passphrase eq $passphrase2);
	ReadMode('restore');
	print "\n";
	system("gpg -c --cipher-algo $cfg{'file.cipher'} --no-use-agent --passphrase $passphrase -o $cfg{'file.pwfile'} $tmp_pass");
	unlink($tmp_pass);
	if($cfg{'options.usegit'}) {
		my $dir = dirname($cfg{'file.pwfile'});
		my $filename = basename($cfg{'file.pwfile'});
		system("cd $dir && git commit -m 'update passwddb' $filename");
		system("cd $dir && git push origin master");
	}
}

sub get {
	my ($lookup) = @_;
	my $password;
        my $pattern;
        if ( ! defined($lookup) ) {
		print "Your regex pattern you look for: ";
		chomp($pattern = ReadLine(0));
	} else {
		$pattern = $lookup;
	}
	decrypt();
	my @match = fgrep { /$pattern/i } $tmp_pass;
	print "-" x 30 ."\n";
	foreach (@match) {
		foreach my $i (keys $_->{'matches'}) {
			my ($name,$username,$password,$sitetype,$notes) = (split(/;/, $_->{'matches'}{$i}));
			if ( !$cfg{'toclip'} ) {
				print "Name: $name\nUsername: $username\nPassword: $password\n$notes\n";
			} else {
				print "Name: $name\nUsername: $username\n$notes\n";
				Clipboard->copy($password) if ($cfg{'toclip'});
			}
			print "-" x 30 ."\n";
		}
	}
	unlink($tmp_pass);
}

sub add {
	print "Name: ";
	chomp(my $sitename = ReadLine(0));
	print "Notes: ";
	chomp(my $sitelink = ReadLine(0));
	print "Username: ";
	chomp(my $username = ReadLine(0));
	print "Password: ";
	ReadMode('noecho');
	chomp(my $password = ReadLine(0));
	ReadMode('restore');
	print "\n";
	print "Sitetype: ";
	chomp(my $sitetype = ReadLine(0));
	decrypt();
	open(FILE, ">>$tmp_pass") || die("Can't open file: $tmp_pass");
	print FILE "$sitename;$username;$password;$sitetype;$sitelink;\n";
	close(FILE);
	encrypt();
}

sub edit {
	decrypt();
	system("vim $tmp_pass");
	encrypt();
}

sub delete_pw {
	print "Your regex pattern you look for: ";
	chomp(my $pattern = ReadLine(0));
	decrypt();
	my @match = fgrep { /$pattern/i } $tmp_pass;
	foreach (@match) {
		if(scalar keys $_->{'matches'} > 1) {
			print "An unique entry could not be found for '$pattern'\n";
			unlink($tmp_pass);
			return 0;
		} else {
			system("sed -i '/$pattern/d' $tmp_pass");
		}

	}
	encrypt();
}


############
# end subs #
############

# get config
$cfg_handle = new Config::Simple($config);
Config::Simple->import_from($config, \%cfg);

$cfg{'toclip'} = defined($toclip) ? $toclip : $cfg{'options.toclip'};
$cfg{'debug'} = 1 if ( $debug || $cfg{'options.debug'} );


switch($command) {
	case "get"	{ 
			  if ( $lookup ne "" ) { get($lookup);} else { get(); } 
			}
	case "add"	{ add(); }
	case "edit"	{ edit(); }
	case "delete"	{ delete_pw(); }
}


sub help_msg{
	print <<'MSG';

pwsafe.pl [-c <config>] -o <option> [-l <lookup pattern>] [-d] [-h] [-t <0|1>]

-c, --config	config file to use
-o, --option	option can be "edit", "get", "add", "delete"
-l, --lookup	pattern to search in the password database
-t, --toclip	0 or 1 
		0 will disable copy to clipboard
		1 will enable copy to clipboard
-h, --help	this help message

pwsafe is a password manager. It stores the passwords in an encrypted file.
MSG
}
