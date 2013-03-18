#!/usr/bin/perl
use DB_File;

$|=1;

use Getopt::Long;
use Config::Simple;
my $config;
my %cc;
my $list;
my $help = 0;
Getopt::Long::Configure('bundling');
GetOptions(
	"h|help" => \$help,
	"l|list=s" => \$list,
        "c|config=s"       => \$config);

if ( $help || !$list || !$config ) {
	&help();
	exit(0);
}

die "Couldn't open config $config\n" if ( ! -e $config );
$cfghandle = new Config::Simple($config);
Config::Simple->import_from($config, \%cc) or print("ERROR: ".Config::Simple->error());
my $regex = $cfghandle->get_block('regex');



sub help () {
print <<'HELP';
logstatsctl.pl -c <config> -l <command> [-h]

-c, --config	config file
-l, --list	list regex counter as specified in config file
HELP
}

tie(%foo, "DB_File", $cc{'default.statsdb'}, O_RDONLY, 0666, $DB_HASH) || die ("Cannot open $cc{default.statsdb}");

foreach my $order (keys %$regex) {
    if($list eq $order) {
		print "$foo{$order}\n";
    }
}

untie %foo;

