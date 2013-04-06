#!/usr/bin/perl


use strict;
use warnings;

use Getopt::Long;
use Config::Simple;
use File::Slurp;
use Date::Manip;
use Log::Log4perl;
use POSIX;

my %cc;
my $config;
my $cfghandle;
my $help;
our $logger;

my $datetime = POSIX::strftime( "%a, %d %b %Y %H:%M:%S", localtime());
Getopt::Long::Configure('bundling');
GetOptions(
        "h|help" => \$help,
        "c|config=s"       => \$config);

if ( $help || !$config ) {
        &help();
        exit(0);
}

print("ERROR: Couldn't find config $config") if ( ! -e $config);                                                                                                        
$cfghandle = new Config::Simple($config);
Config::Simple->import_from($config, \%cc) or print("ERROR: ".Config::Simple->error());

my $log_conf = "
    log4perl.rootLogger=".$cc{'default.loglevel'}.",Logfile
    log4perl.appender.Logfile=Log::Log4perl::Appender::File
    log4perl.appender.Logfile.filename=".$cc{'default.logfile'}."
    log4perl.appender.Logfile.mode=append
    log4perl.appender.Logfile.layout=PatternLayout
    log4perl.appender.Logfile.layout.ConversionPattern=%d [%r] %F %L %c - %m%n";

Log::Log4perl->init(\$log_conf);
$logger = Log::Log4perl->get_logger();
my $path = $cc{'default.path'}."/".$cc{'default.user'}."/Maildir/.".$cc{'default.folder'}."/cur/*";
my $sentpath = $cc{'default.path'}."/".$cc{'default.user'}."/Maildir/.Sent/cur/";
my @mailfiles = glob($path);

$logger->debug("Found ".scalar @mailfiles." mails");

foreach my $file (@mailfiles) {
  # read each file in config path
  my $mail = read_file($file);

  # extract send time from subject
  my ($sendtime) = $mail =~ m/Subject: (\d{4}-\d{2}-\d{2} \d{2}:\d{2}(:\d{2})?)/;
  $mail =~ s/Subject: \d{4}-\d{2}-\d{2} \d{2}:\d{2}(:\d{2})?\s/Subject: /;

  # change date time to now
  $mail =~ s/Date: \w{3}, \d{2} \w{3} \d{4} \d{2}:\d{2}:\d{2} \+0100/Date: $datetime/;

  my $sendepoch = UnixDate(ParseDate($sendtime), "%s")."\n";
  my $now = UnixDate(ParseDate($datetime), "%s")."\n";
  # send mail
  # only send if sendtime is set
  if(defined $sendtime) {
    if($sendepoch < $now) {
      $logger->info("Send mail, from $sendtime");
      system("echo '$mail' | /usr/sbin/sendmail -t ");
      $logger->debug("deleting file $file");
      # move mail to sent folder
      $logger->debug("move mail to sent folder");
      system("/bin/mv $file $sentpath");
      $logger->debug("rebuild dovecot index for folder $cc{'default.folder'}");
      system("/usr/local/bin/doveadm -v index -u $cc{'default.user'} $cc{'default.folder'} 2> /dev/null");
      system("/usr/local/bin/doveadm -v index -u $cc{'default.user'} Sent 2> /dev/null");
    }
  }
}

sub help () {
print <<'HELP';
sendmail_later.pl -c <config> [-h]
script will send an email at a given time and date placed in subject
-c, --config    config file

config file
  path      path to the Drafts folder, where the mails get stored
  logfile   logfile to use (full path)
  loglevel  loglevel to use (DEBUG, INFO)
HELP
}

