#!/usr/bin/perl -w
use strict;
use Getopt::Long;
use Time::Piece;
use Capture::Tiny ':all';
use warnings;

my $openssl = "/usr/bin/openssl";

my $help;
my $cert;

Getopt::Long::Configure('bundling');
GetOptions(
  "h|help" => \$help,
  "f|file=s" => \$cert,
);


if ( $cert eq "" || $help ) {
  &print_help();
  exit 1;
}

my $cmd = "$openssl x509 -inform der -in $cert -text -noout";

my ($stdout, $stderr, $exit) = capture {
  system($cmd);
};

my ($enddate) = $stdout =~ m/Not After\s:\s(.*)\sGMT/;
if ( defined $enddate ) {
  my $t = Time::Piece->strptime($enddate, "%b %e %H:%M:%S %Y %Z");
  print $t->strftime("%s")."\n";
} else {
  print "3\n";
}

sub print_help () {
print <<'HELP';
check_cert.pl -f <certificate file>

-f, --file  certificate file
HELP
}
