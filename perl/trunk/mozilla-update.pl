#!/usr/bin/perl
#$ID$

use strict;
use warnings;
use Getopt::Long;
use English;


my $debug = 0;
my $help = 0;
my $app = "firefox";
my $version = "0";
my $dest = "/opt/applications";

sub help() {
	print <<HELP
Usage: mozilla-update.pl [-h] [-d] -a <application> -v <version>
-h, --help
-d, --debug
-a, --app     application (firefox, thunderbird)
-v, --version version of application
HELP
}

Getopt::Long::Configure('bundling');
GetOptions(
	"h|help" => \$help,
	"d|debug" => \$debug,
	"a|app=s"	=> \$app,
	"v|version=s" => \$version);

if ( $help || !$app || !$version ) {
	help();
	exit(0);
}
my ($name, $pass, $uid, $gid) = getpwnam(getlogin());
if($uid != 0 && $EFFECTIVE_USER_ID != 0) {
	print "You should run this as root or use sudo\n";
	exit(1);
}

# download
my $url = "http://ftp.mozilla.org/pub/$app/releases/$version/linux-x86_64/en-US/$app-$version.tar.bz2";
print "Download $app-$version.tar.bz2\n" if ($debug);
my $r = system(qq(/usr/bin/wget -O /tmp/$app-$version.tar.bz2 $url));
if ($r) {
	print "Couldn't download $app-$version.tar.bz2\n";
	exit(1);
}

# extract
print "Extract $app-$version.tar.bz2\n" if ($debug);
$r = system(qq(/bin/tar -xjvf /tmp/$app-$version.tar.bz2 -C /tmp/));
if($r) {
	print "Couldn't extract $app-$version.tar.bz2\n";
	exit(1);
}

# mv
print "Moving it to applications\n" if($debug);
$r = system(qq(/bin/mv /tmp/$app $dest/$app/$version));
if($r) {
	print "Couldn't mv $app to $dest/$app/$version\n";
	exit(1);
}

# relink
print "relink everything..\n" if ($debug);
system(qq(/bin/rm -f $dest/$app/current && /bin/ln -s $dest/$app/$version $dest/$app/current));
system(qq(/bin/rm -f /usr/bin/$app && ln -s $dest/$app/current/$app /usr/bin/$app));
system(qq(/bin/rm -f /tmp/$app-$version.tar.bz2));
foreach (@ARGV) {
        print "$_\n";
}
