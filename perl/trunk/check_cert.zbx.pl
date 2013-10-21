#!/usr/bin/perl -w
use strict;
use Getopt::Long;
use Time::Piece;
use Capture::Tiny ':all';
use warnings;

my $openssl = "/usr/bin/openssl";

my $help;
my $cert;
my $form;

Getopt::Long::Configure('bundling');
GetOptions(
  "h|help" => \$help,
  "f|file=s" => \$cert,
  "t|type=s" => \$form,
);


if ( $cert eq "" || $form eq "" || $help ) {
  &print_help();
  exit 1;
}

if ( ! -x $openssl ) {
  print "Coudn't find or isn't executable: $openssl\n";
  exit 1;
}

my $cmd = "$openssl x509 -inform $form -in $cert -text -noout";

my ($stdout, $stderr, $exit) = capture {
  system($cmd);
};

if ( $exit ) {
  print "Couldn't read certificate file: $cert\n";
  exit 1;
}

my ($enddate) = $stdout =~ m/Not After\s:\s(.*)\sGMT/;
if ( defined $enddate ) {
  my $t = Time::Piece->strptime($enddate, "%b %e %H:%M:%S %Y %Z");
  print $t->strftime("%s")."\n";
} else {
  print "3\n";
}

sub print_help () {
print <<'HELP';
check_cert.pl -f <certificate file> -t <cert form> [-h]

-f, --file  certificate file
-t, --type  certificate format (der, pem)
-h, --help  this help message

It returns the timestamp til the certificate is valid. 
So it can be compared against the timestamp of Zabbix server.
HELP
}
