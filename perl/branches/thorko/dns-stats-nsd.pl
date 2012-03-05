#!/usr/bin/perl
#$ID$
#

use Sys::Syslog;
use Fcntl qw(:DEFAULT :flock);

$config = '/local/dnsadm/nameserver.conf';
$bindlogs = '/local/dnsadm/var/log';
$dedns_cmd = '/usr/local/bin/de-dns';
$outfile = '/local/dnsadm/monitor/stats.out';
$nxdomainsoutfile = '/local/dnsadm/monitor/nxdomains.out';
$wd = '/local/dnsadm/monitor';
$queries_before_file = "$wd/log/stats.before";
$nxdomains_before_file = "$wd/log/nxdomains.before";
$query_loss_file = "$wd/log/query_loss_before";
$debugfile = "$wd/log/stats.log";
$date = `/bin/date +"%Y%m%d"`;
chomp($date);
$valuefile = "$wd/log/values.$date.log";
$thresholdfile = "$wd/log/threshold.log";
$stats_conf_file = "$wd/etc/stats.conf";
$mailto = 'ihl@denic.de, ops-sys@denic.de'; # fallback, sonst auslesen aus $config
$mailintervall = 10;

$gzip = '/usr/local/bin/gzip' if ( -e "/usr/local/bin/gzip" );
$gzip = '/bin/gzip' if ( -e "/bin/gzip" );

open(CONF,"$stats_conf_file") || &alert("$stats_conf_file: $!");
while ( <CONF> )
{
   next if ( $_ =~ /^#/ );
   next if ( $_ =~ /^\s*$/ );
   chomp($_);
   @a = split(/\s+/,$_);
   $b = scalar @a;
   $i = 1;
   while ( $i < $b )
   {
      $statsconf{$a[0]} = $statsconf{$a[0]}.$a[$i];
      $i++;
   }
}
close(CONF);

$mailto = $statsconf{'MAILTO'} if $statsconf{'MAILTO'};
$mailsos = $statsconf{'MAILTOSOS'} if $statsconf{'MAILTOSOS'};
$threshold_min = $statsconf{'MINSW'} if $statsconf{'MINSW'};
$sw = $statsconf{'MAXSW'} if $statsconf{'MAXSW'};
$debug = $statsconf{'DEBUG'} if $statsconf{'DEBUG'};
$faktor = $statsconf{'FAKTOR'} if $statsconf{'FAKTOR'};
$mailintervall = $statsconf{'MAILINTERVALL'} if $statsconf{'MAILINTERVALL'};

### Definitionen für das Nagiosgedoens ###
$sw_warn_nx = "50";
$sw_crit_nx = "75";
$nagiosserver_fra1 = 'nagios-nsl-1.fra1.svc.denic.de';
$nagiosserver_ams1 = 'nagios-nsl-1.ams1.svc.denic.de';
$sendtonagios_fra1 = "/usr/local/nagios/bin/send_nsca -H $nagiosserver_fra1 -p 8080 -c /usr/local/nagios/etc/send_nsca.cfg";
$sendtonagios_ams1 = "/usr/local/nagios/bin/send_nsca -H $nagiosserver_ams1 -p 8080 -c /usr/local/nagios/etc/send_nsca.cfg";
$server = "`/bin/hostname`";
chomp($server);
$string = "$service OK";
$exitcode = 0;
$exitstatus = "OK";

$date = `/bin/date +"%Y%m%d%H%M%S"`;
chomp($date);

open(DEBUG,">>$debugfile") || &alert("$debugfile: $!");
print DEBUG "$date " if ( $debug );


open(CONFIG,"<$config") || die "upps, kann Configfile $config nicht oeffnen! $!\n";
while ( <CONFIG> )
{
   next if ( $_ =~ m/^\#/ );
   next if ( $_ =~ m/^\s*$/ );
   chomp($_);
   $lcline = lc $_;
   @line = split(/\s+/,$lcline);
   $conf{$line[0]} = $line[1];
}
$hostname = $conf{'service'};

&alert("NameserverSW nicht in $config") if ( ! $conf{'nameserversw'} );

open(BEFORE,"$queries_before_file") || &debug("read $queries_before_file nicht vorhanden");
$queries_before = <BEFORE>;
close(BEFORE);

open(NXDOMAINS,"$nxdomains_before_file") || &debug("read $nxdomains_before_file nicht vorhanden");
$nxdomains_before = <NXDOMAINS>;
close(NXDOMAINS);

@packetloss_before;
open(QUERYLOSS,"<$query_loss_file") || &debug("read $query_loss_file nicht vorhanden");
while ( $line = <QUERYLOSS> ) {
	push @packetloss_before $line;
}
close(QUERYLOSS);

if ( $conf{'nameserversw'} eq 'bind8' ) { &bind8; }
elsif ( $conf{'nameserversw'} eq 'bind9' ) { &bind9; }
elsif ( $conf{'nameserversw'} eq 'bind9.3' ) { &bind93; }
elsif ( $conf{'nameserversw'} eq 'nsd' ) { &nsd; }
else { &alert("NameserverSW $conf{'nameserversw'} in $config nicht korrekt"); }

&del_stats;

&values;

&thresholdcheck;

&alertcheck;

if ( ! $alert_count )
{
   unlink("$wd/log/warn") if ( -e "$wd/log/warn" );
   unlink("$wd/log/alert") if ( -e "$wd/log/alert" );
}

&sendtonagios;

close(DEBUG) if ( $debug );

#####################################################

sub bind8
{
   @ans_stats = `$dedns_cmd stats` || &alert("dedns_cmd stats: $!");
   $ok = 0;
   $sum = 0;

   foreach ( @ans_stats )
   {
      $ok = 1 if  ( $_ =~ /Statistics\ dump\ initiated/ );
   }
   &log_syslog("Statistikdump wurde nicht erzeugt") if ( ! $ok );

   open(STATS,"<$bindlogs/named.stat") || &alert("$bindlogs/named.stat: $!");
   while ( <STATS> )
   {
      chomp($_);
      &debug("$_") if ( $debug == 2 );
      if ( $_ =~ m/quer/ )
      {
         @q = split(/\s/,$_);
         $sum = $sum + $q[0];
      }
      ### ich will die nxdomains einzeln noch mal.
      ### die stehen an 25. stelle in der zeile nach 'Global'
      if ( $_ =~ /Global/ )
      {
         $naechste = 1;
         next;
      }
      if ( $naechste == 1 )
      {
         $_ =~ s/\s*//;
         @bla = split(/\s+/,$_);
         $nxdomains = $bla[24];
         $naechste = 0;
      }
   }
   close(STATS);
   $sum_last = $sum - $queries_before;
   #print "nxdomain $nxdomains nxdomainbefore $nxdomains_before\n";
   $nx_last = $nxdomains - $nxdomains_before;

   #print "sumnx $nx_last\n";

   $nx_prozent = $nx_last / $sum_last * 100 if ( $sum_last != 0 );
   $nx_prozent = 0 if ( $sum_last == 0 );

   &debug("$date $conf{'nameserversw'} queries: $sum_last");
   &debug("$date $conf{'nameserversw'} nxdomains: $nx_last");
   &debug("$date $conf{'nameserversw'} nxprozent: $nx_prozent");

   open(BEFORE,">$queries_before_file") || &debug("$queries_before_file nicht vorhanden");
   print BEFORE $sum;
   close(BEFORE);

   open(NXDOMAINS,">$nxdomains_before_file") || &debug("$nxdomains_before_file nicht vorhanden");
   print NXDOMAINS $nxdomains;
   close(NXDOMAINS);

   open(OUT,">$outfile") || &alert("$outfile: $!");
   print OUT "$hostname\t$sum_last";
   close(OUT);

   open(NXOUT,">$nxdomainsoutfile") || &alert("$nxdomainoutfile: $!");
   print NXOUT "$hostname\n";
   print NXOUT "nxdomains\t$nx_last\n";
   print NXOUT "prozent\t$nx_prozent\n";
   close NXOUT;
}


sub bind93
{
   @ans_stats = `$dedns_cmd stats`;
   $sum = 0;
   %req_packetloss;

   open(STATS,"<$bindlogs/named.stat") || &alert("$bindlogs/named.stat: $!");
   while ( <STATS> )
   {
      chomp($_);
      &debug("$_") if ( $debug == 2 );
      next if ( $_ =~ m/^\-\-\-/ );
      next if ( $_ =~ m/^\+\+\+/ );
      next if ( $_ =~ m/^\SSTATS/ );
      @q = split(/\s/,$_);
      $sum = $sum + $q[1];
      ### ich will die nxdomains einzeln.
      if ( $_ =~ /nxdomain/ )
      {
         @nxd = split(/\s/,$_);
         $nxdomains = $nxd[1];
      }

      # IPv4 / IPv6 Request ermitteln
      $req_packetloss{'ipv4_received'} = (split(/\s+/, $_)[1]) if ( $_ =~ /IPv4 requests received/ );
      $req_packetloss{'ipv6_received'} = (split(/\s+/, $_)[1]) if ( $_ =~ /IPv6 requests received/ );
      $req_packetloss{'ipv4_sent'} = (split(/\s+/, $_)[1]) if ( $_ =~ /IPv4 queries sent/ );
      $req_packetloss{'ipv6_sent'} = (split(/\s+/, $_)[1]) if ( $_ =~ /IPv6 queries sent/ );
      
   }
   close(STATS);

   # berechne 
   $sum_ip4_loss = $req_packetloss{'ipv4_received'} - $req_packetloss{'ipv4_sent'};
   $sum_ip6_loss = $req_packetloss{'ipv6_received'} - $req_packetloss{'ipv6_sent'};
   $packetloss_ip4 = $packetloss_before[0] - $sum_ip4_loss;
   $packetloss_ip6 = $packetloss_before[1] - $sum_ip6_loss; 

   # schreibe die Statistiken 
   open(BEFORE,">$query_loss_file") || &debug("$query_loss_file nicht vorhanden");
   flock(BEFORE, LOCK_EX);
   # immer die Anzahl zwischen Received und Sent schreiben, da dies Counter sind die hochgezählt werden
   print BEFORE $sum_ip4_loss."\n".$sum_ip6_loss;
   close(BEFORE);

   $sum_last = $sum - $queries_before;
   $nx_last = $nxdomains - $nxdomains_before;

   # schreibe die Statistiken 
   open(BEFORE,">$query_loss_file") || &debug("$query_loss_file nicht vorhanden");
   flock(BEFORE, LOCK_EX);
   # immer die Anzahl zwischen Received und Sent schreiben, da dies Counter sind die hochgezählt werden
   print BEFORE $sum_ip4_loss."\n".$sum_ip6_loss;
   close(BEFORE);

   # wir können von sum nicht einfach queries_before abziehen
   if ( $queries_before > $sum ) {
       # wir nehmen an Bind wurde neugestartet, deshalb sum kleiner als queries_before
       $sum_last = $sum;
   } else {
       $sum_last = $sum - $queries_before;
   }

   # das Gleiche gilt für nxdomains
   if ( $nxdomains_before > $nxdomains ) {
       $nx_last = $nxdomains;
   } else {
       $nx_last = $nxdomains - $nxdomains_before;
   }

   $nx_prozent = $nx_last / $sum_last * 100 if ( $sum_last != 0 );
   $nx_prozent = 0 if ( $sum_last == 0 );

   &debug("$date $conf{'nameserversw'} queries: $sum_last");
   &debug("$date $conf{'nameserversw'} nxdomains: $nx_last");
   &debug("$date $conf{'nameserversw'} nxprozent: $nx_prozent");

   open(BEFORE,">$queries_before_file") || &debug("$queries_before_file nicht vorhanden");
   print BEFORE $sum;
   close(BEFORE);

   open(NXDOMAINS,">$nxdomains_before_file") || &debug("$nxdomains_before_file nicht vorhanden");
   print NXDOMAINS $nxdomains;
   close(NXDOMAINS);

   open(OUT,">$outfile") || &alert("$outfile: $!");
   print OUT "$hostname\t$sum_last";
   close(OUT);

   open(NXOUT,">$nxdomainsoutfile") || &alert("$nxdomainoutfile: $!");
   print NXOUT "$hostname\n";
   print NXOUT "nxdomains\t$nx_last\n";
   print NXOUT "prozent\t$nx_prozent\n";
   close NXOUT;
}

sub bind9
{
   @ans_stats = `$dedns_cmd stats`;
   $sum = 0;
   %req_packetloss;

   open(STATS,"<$bindlogs/named.stat") || &alert("$bindlogs/named.stat: $!");
   while ( <STATS> )
   {
      chomp($_);
      &debug("$_") if ( $debug == 2 );
      if ($_ =~ m/IPv4 requests received/)
      {

        $_ =~ s/^\s+//g;
	@q = split(/ /,$_);
	$sum = $sum + $q[0];
      }
      ### ich will die nxdomains einzeln.
      elsif ( $_ =~ m/NXDOMAIN/ )
      {
        $_ =~ s/^\s+//g;
        @nxd = split(/ /,$_);
        $nxdomains = $nxd[0];
      }
      
      # IPv4 / IPv6 Request ermitteln
      $req_packetloss{'ipv4_received'} = (split(/\s+/, $_)[1]) if ( $_ =~ /IPv4 requests received/ );
      $req_packetloss{'ipv6_received'} = (split(/\s+/, $_)[1]) if ( $_ =~ /IPv6 requests received/ );
      $req_packetloss{'ipv4_sent'} = (split(/\s+/, $_)[1]) if ( $_ =~ /IPv4 queries sent/ );
      $req_packetloss{'ipv6_sent'} = (split(/\s+/, $_)[1]) if ( $_ =~ /IPv6 queries sent/ );
   }
   close(STATS);

   # berechne 
   $sum_ip4_loss = $req_packetloss{'ipv4_received'} - $req_packetloss{'ipv4_sent'};
   $sum_ip6_loss = $req_packetloss{'ipv6_received'} - $req_packetloss{'ipv6_sent'};
   $packetloss_ip4 = $packetloss_before[0] - $sum_ip4_loss;
   $packetloss_ip6 = $packetloss_before[1] - $sum_ip6_loss; 

   # schreibe die Statistiken 
   open(QUERYLOSS,">$query_loss_file") || &debug("$query_loss_file nicht vorhanden");
   flock(QUERYLOSS, LOCK_EX);
   # immer die Anzahl zwischen Received und Sent schreiben, da dies Counter sind die hochgezählt werden
   print QUERYLOSS $sum_ip4_loss."\n".$sum_ip6_loss;
   close(QUERYLOSS);
   
   $sum_last = $sum - $queries_before;
   $nx_last = $nxdomains - $nxdomains_before;

   # schreibe die Statistiken 
   open(QUERYLOSS,">$query_loss_file") || &debug("$query_loss_file nicht vorhanden");
   flock(QUERYLOSS, LOCK_EX);
   # immer die Anzahl zwischen Received und Sent schreiben, da dies Counter sind die hochgezählt werden
   print QUERYLOSS $sum_ip4_loss."\n".$sum_ip6_loss;
   close(QUERYLOSS);
   
   # wir können von sum nicht einfach queries_before abziehen
   if ( $queries_before > $sum ) {
       # wir nehmen an Bind wurde neugestartet, deshalb sum kleiner als queries_before
       $sum_last = $sum;
   } else {
       $sum_last = $sum - $queries_before;
   }

   # das Gleiche gilt für nxdomains
   if ( $nxdomains_before > $nxdomains ) {
       $nx_last = $nxdomains;
   } else {
       $nx_last = $nxdomains - $nxdomains_before;
   }

   $nx_prozent = $nx_last / $sum_last * 100 if ( $sum_last != 0 );
   $nx_prozent = 0 if ( $sum_last == 0 );

   &debug("$date $conf{'nameserversw'} queries: $sum_last");
   &debug("$date $conf{'nameserversw'} nxdomains: $nx_last");
   &debug("$date $conf{'nameserversw'} nxprozent: $nx_prozent");

   open(BEFORE,">$queries_before_file") || &debug("$queries_before_file nicht vorhanden");
   print BEFORE $sum;
   close(BEFORE);

   open(NXDOMAINS,">$nxdomains_before_file") || &debug("$nxdomains_before_file nicht vorhanden");
   print NXDOMAINS $nxdomains;
   close(NXDOMAINS);

   open(OUT,">$outfile") || &alert("$outfile: $!");
   print OUT "$hostname\t$sum_last";
   close(OUT);

   open(NXOUT,">$nxdomainsoutfile") || &alert("$nxdomainoutfile: $!");
   print NXOUT "$hostname\n";
   print NXOUT "nxdomains\t$nx_last\n";
   print NXOUT "prozent\t$nx_prozent\n";
   close NXOUT;
}

#
# function calculates the nsd queries since the last run
# it does that by determing all running nsd processes
# getting the stats for those and subtracting the queries
# of the run before
# it than writes back the new stats to a state file
#
sub nsd {
   # run statistic command to write out new statistics
   @ans_stats = `$dedns_cmd stats`;

   # sleep some seconds to be sure all stats are
   # written to file
   sleep(2);
  
   my ($pid, $pidline);
   my $sum_before;
   my (@new_lines, @pids);
   my ($sum_last,$nx_last, $rq, $nx);
   my $no_calc = 0; # no calculation flag

   # first get all PIDs of running nsd processes
   open(CMD, "/sbin/pidof nsd |") or die $!;
   while(<CMD>) {
   	$pidline = $_;
   }
   close(CMD);
   chomp($pidline);
   @pids = split(/ /,$pidline);
   
   &debug("PIDs of nsd found: $pidline") if ($debug >= 1);
   
   # if state file not exits, assume we just started nsd
   if( ! -e $queries_before_file ) {
	$pos = 0;
	# don't calculate any queries yet
	$no_calc = 1;
   } else {
      # open state file to get pos of logfile and Counter of PIDs
      &debug("read stats from $queries_before_file") if ($debug >= 1);
      open(FILE,"<$queries_before_file") || &alert("$queries_before_file: $!");
      while ( my $line = <FILE> ) {
      	# get last read position
      	if ( $line =~ /^POS/ ) { $pos = (split(/=/, $line))[1] }
      	# get all PIDs and store 'em in a hash
      	if ( $line =~ /^PID/ ) { 
      		my @values = split(/\s/, $line);
      		foreach my $el (@values) {
      			if( $el =~ /^PID/ ) { $pid = (split(/=/,$el))[1] }
      			if( $el =~ /^RQ/ ) { $stats{$pid}{'RQ'} = (split(/=/,$el))[1] }
      			if( $el =~ /^SNXD/ ) { $stats{$pid}{'SNXD'} = (split(/=/,$el))[1] }
      			if( $el =~ /^RNXD/ ) { $stats{$pid}{'RNXD'} = (split(/=/,$el))[1] }
      		}	
      	}
      }
      close(FILE);
   }

   
   # get all new lines of logfile
   &debug("reading new lines of nsd log file") if ($debug >= 1);
   ($pos, @new_lines) = read_last_change_of_file("$bindlogs/nsd.log", $pos);
   # if no new lines given back
   if( ! defined(@new_lines) ) { 
	# check how big the log file is
	$filesize = -s "$bindlogs/nsd.log";
	# if the last read position is greater than filesize
	if($pos > $filesize) {
		$pos = 0;
		&debug("no new lines found or $bindlogs/nsd.log got truncated, new pos: $pos") if ($debug >= 1);
	}
   } else {
      foreach my $line (@new_lines) {
	#if ( $line =~ /\snsd.started\s/ ) {
		# nsd got restarted
	#	&debug("nsd got restarted") if ($debug >= 1);
	#}
      	# check if line contains XSTATS
      	if ( $line =~ /\sXSTATS\s/ ) {
      		# split line by space
      		my @values = split(/\s/, $line);
      		foreach my $el (@values) {
      			# get PID
      			if( $el =~ /^nsd/ ) { $pid = (split(/([\[,\]])/,$el))[2]; }
      			# build hash with PID
      			# Note: there can be more than one line for a PID
      			# but it will take the last line which holds the most updated value
      			if( $el =~ /^RQ/ ) { $queries{$pid}{'RQ'} = (split(/=/,$el))[1] }
      			if( $el =~ /^SNXD/ ) { $queries{$pid}{'SNXD'} = (split(/=/,$el))[1] }
      			if( $el =~ /^RNXD/ ) { $queries{$pid}{'RNXD'} = (split(/=/,$el))[1] }
      		}
      	}
      }
   }
   
   # if no state file exists
   if ( $no_calc == 1 ) {
	&debug("no calcuation takes place because state file isn't existing yet") if ($debug >= 1);
	$sum_last = 0;
	$nx_last = 0;
   } else {
   	# calculate the queries
        foreach my $key (keys %queries) {
             # foreach PID subtract the queries before, but only if queries exist
             # because sometimes nsd doesn't write stats for each PID
             if ( defined($queries{$key}{'RQ'}) ) {
        		$rq = $queries{$key}{'RQ'} - $stats{$key}{'RQ'};
             }
        	# do it also for the NXD queries
             if ( defined($queries{$key}{'SNXD'}) ) {
        		$nx = ($queries{$key}{'SNXD'} + $queries{$key}{'RNXD'}) - ($stats{$key}{'SNXD'} + $stats{$key}{'RNXD'});
             }
        	# build sum of queries
        	$sum_last += $rq;
        	$nx_last += $nx;
        	&debug("PID=$key: RQ_counter=$queries{$key}{RQ}") if ($debug >= 1);
        	&debug("PID=$key: RQ_before=$stats{$key}{RQ}") if ($debug >= 1);
        }
   	# no new lines could be found, therefore no stats available
   	# and queries are 0
   	if( ! defined($sum_last) || ! defined($nx_last) ) {
   	     $sum_last = 0;
   	     $nx_last = 0;
   	     &debug("No new lines in nsd.log file") if ($debug >= 1);
   	}
   }
  
   &debug("RQ: $sum_last\nNX: $nx_last") if ($debug >= 1);
   
   # update state file
   &debug("Writing stats to state $queries_before_file file") if ($debug >= 1);
   open(FILE, ">$queries_before_file"); 
   # set a lock on file
   flock(FILE, LOCK_EX);
   print FILE "POS=$pos\n";
   # foreach determined process write the stats
   foreach my $process (@pids) {
   	# if new line with queries of process exist
   	if ( defined($queries{$process}) && defined($queries{$process}{'RQ'}) ) {
   		print FILE "PID=$process RQ=$queries{$process}{RQ} SNXD=$queries{$process}{SNXD} RNXD=$queries{$process}{RNXD}\n";
   	}
   	# if no new lines of process exist write the old stats 
   	elsif ( defined($stats{$process}) && defined($stats{$process}{'RQ'}) ) {
   		print FILE "PID=$process RQ=$stats{$process}{RQ} SNXD=$stats{$process}{SNXD} RNXD=$stats{$process}{RNXD}\n";
   	}
   	# if even no new lines and old stats exist
   	# write stats counter 0 
   	else {
   		print FILE "PID=$process RQ=0 SNXD=0 RNXD=0\n";
   	}
   }
   close(FILE);

   # write some other stats, (I don't know what it is needed for)
   open(OUT,">$outfile") || &alert("$outfile: $!");
   # always set a exclusive lock on file 
   flock(OUT, LOCK_EX);
   print OUT "$hostname\t$sum_last";
   close(OUT);

}

# reads the new lines given at pos
# returns the new lines and the new position
sub read_last_change_of_file {
   my ($read_file, $pos) = @_;
   my @lines;
   my $status;
   
   open (FILE, "<".$read_file) || &alert("$read_file: $!");;
   # jump to pos
   $status = seek(FILE, $pos, 0);
   # if position isn't readable,
   # file probably got truncated
   while(my $line = <FILE>) {
   	push(@lines, $line);
   }
   # get new pos of file
   $pos = tell(FILE);
   close(FILE);
   return $pos, @lines;
}

sub del_stats
{
   `/bin/cp $bindlogs/named.stat /var/tmp/named.stat.bm`;
   @del_stats = `/bin/cat /dev/null > $bindlogs/named.stat`;
   &alert("@del_stats") if ( @del_stats );
   @del_stats = `/bin/cat /dev/null > $bindlogs/named.memstats` if ( $conf{'nameserversw'} eq 'bind8' );
   &alert("@del_stats") if ( @del_stats );
}

sub debug
{
   $al = shift;
   print DEBUG "$al\n" if ( $debug );
}

sub log_syslog
{
   $al = shift;
   openlog("$0 ",'cons,pid','messages') || die "openlog: $!\n";
   syslog('info',$al);
   closelog;
}


sub alert
{
   $al = shift;

   if ( -e "$wd/log/alert" )
   {
      open(ALERT,"<$wd/log/alert") || die "$wd/log/alert: $!\n";
      $alert_count = <ALERT>;
      close(ALERT);
      $bla = $alert_count % $mailintervall;
      if ( $bla == 0 )
      {
       #keine mails mehr 03.02.09##   &alert_mail;
      }
      $alert_count++;
      open(ALERT,">$wd/log/alert") || die "$wd/log/alert: $!\n";
      print ALERT $alert_count;
      close(ALERT);
      &debug("$alert_count: $al");
   }
   else
   {
      $alert_count = 1;
       #keine mails mehr 03.02.09## &alert_mail;
      open(ALERT,">$wd/log/alert") || die "$wd/log/alert: $!\n";
      print ALERT $alert_count;
      close(ALERT);
   }
   open(OUT,">$outfile") || die "$outfile: $!";
   $sum_last = 0;
   print OUT "$hostname\t$sum_last";
   close(OUT);
   exit(1);
}

sub alert_mail
{
   $mailprog = '/usr/bin/sendmail -t' if ( -e "/usr/bin/sendmail" );
   $mailprog = '/usr/sbin/sendmail -t' if ( -e "/usr/sbin/sendmail" );
   $maildate = `/bin/date +"%Y%m%d.%H:%M"`;
   chomp($maildate);
   $mailsubject = "E.NS.$hostname.$maildate.\"$al\"";

   open(MAIL,"|$mailprog")||die "Fehler $mailprog - $!\n";
   print MAIL "To: $mailto\n";
   print MAIL "X-Denic-Script: $0\n";
   print MAIL "X-errors: petrasch\@denic.de\n";
   print MAIL "Subject: $mailsubject\n\n";
   print MAIL "$0:\n";
   print MAIL "nameserver on $hostname\n";
   print MAIL "ERROR: $al\n";
   close(MAIL);
   &debug("E:$mailsubject");
}

sub warn
{
   $al = shift;

   if ( -e "$wd/log/warn" )
   {
      open(ALERT,"<$wd/log/warn") || die "$wd/log/warn: $!\n";
      $alert_count = <ALERT>;
      close(ALERT);
      $bla = $alert_count % $mailintervall;
      if ( $bla == 0 )
      {
          #keine mails mehr 03.02.09## &warn_mail;
      }
      $alert_count++;
      open(ALERT,">$wd/log/warn") || die "$wd/log/alert: $!\n";
      print ALERT $alert_count;
      close(ALERT);
      &debug("$alert_count: $al");
   }
   else
   {
      $alert_count = 1;
       #keine mails mehr 03.02.09##&warn_mail;
      open(ALERT,">$wd/log/warn") || die "$wd/log/alert: $!\n";
      print ALERT $alert_count;
      close(ALERT);
#      print `$wd/bin/querylog.sh`;
   }
}


sub warn_mail
{
   $mailprog = '/usr/bin/sendmail -t' if ( -e "/usr/bin/sendmail" );
   $mailprog = '/usr/sbin/sendmail -t' if ( -e "/usr/sbin/sendmail" );
   $maildate = `/bin/date +"%Y%m%d.%H:%M"`;
   chomp($maildate);
   $mailsubject = "W.PRO.NS.$hostname.$maildate.\"$al\".S!";

   open(MAIL,"|$mailprog")||die "Fehler $mailprog - $!\n";
   print MAIL "To: $mailto\n";
   print MAIL "X-Denic-Script: $0\n";
   print MAIL "X-errors: petrasch\@denic.de\n";
   print MAIL "Subject: $mailsubject\n\n";
   print MAIL "$0:\n";
   print MAIL "nameserver on $hostname\n";
   print MAIL "WARN: $al\n";
   &debug("W:$mailsubject");
   close(MAIL);
}


sub values
{
   open(VALUES,">>$valuefile") || &alert("$valuefile: $!\n");
   print VALUES "$date $conf{'nameserversw'} $sum_last\n";
   close(VALUES);
}

sub thresholdcheck
{
   if ( -e $thresholdfile )
   {
      open(THRESHOLD,"<$thresholdfile") || &alert("$thresholdfile: $!\n");
      $avg_yesterday = <THRESHOLD>;
      close(THRESHOLD);
      $threshold = $faktor * $avg_yesterday;
      #cp-20090903 - print "$threshold\n";
      &debug("Schwellwert(avg_yesterday * $faktor): $threshold");
      $threshold = $sw if ( $threshold > $sw );
      $threshold = $threshold_min if ( $threshold < $threshold_min );
      &debug("Schwellwert(real): $threshold");

   }
   else
   {
      &warn("Schwellwert nicht aus Datei gelesen: nutze Standart: $threshold_min");
      open(THRESHOLD,">$thresholdfile") || &alert("$thresholdfile: $!\n");
      $threshold_temp = $threshold_min / 2;
      print THRESHOLD $threshold_temp;
      close(THRESHOLD);
      $threshold = $threshold_min;
   }
}

sub alertcheck
{
   &warn("$sum_last > $threshold!") if ( $sum_last > $threshold );
}

sub sendtonagios
{
   # Anzahl Queries ans Nagios schicken
   $perfdata = "dnsqueries=$sum_last";
   $service = "DNS-QUERIES";
#   if ( $sum_last > $threshold ) {
#      $exitstatus = "WARNING";
#      $exitcode = 1;
#      $string = "Schwellwertueberschreitung! $sum_last Queries > $threshold";
#   }
#   else {
      $exitstatus = "OK";
      $exitcode = 0;
      $string = "$sum_last Queries in der letzten Minute.";
#   }
   $output = "$service $exitstatus $string | $perfdata";
   `/usr/bin/printf "%s\t%s\t%s\t%s\n" "$server" "$service" "$exitcode" "$output" | $sendtonagios_fra1`;
   `/usr/bin/printf "%s\t%s\t%s\t%s\n" "$server" "$service" "$exitcode" "$output" | $sendtonagios_ams1`;

   # Anzahl NXDOMAINS ans Nagios schicken
   $perfdata = "nxdomains=$nx_last";
   $service = "DNS-NXDOMAINS";
   if ( $nx_prozent >= $sw_crit_nx ) {
      $exitstatus = "CRITICAL";
      $exitcode = 2;
      $string = "Anteil NXDOMAINS (Anz=$nx_last) groesser als $sw_crit_nx %";
   }
   elsif ( $nx_prozent >= $sw_warn_nx ) {
      $exitstatus = "WARNING";
      $exitcode = 1;
      $string = "Anteil NXDOMAINS (Anz=$nx_last) groesser als $sw_warn_nx %";
   }
   else {
      $exitstatus = "OK";
      $exitcode = 0;
      $string = "Anteil NXDOMAINS (Anz=$nx_last) kleiner als $sw_warn_nx %";
   }
   $output = "$service $exitstatus $string | $perfdata";
   `/usr/bin/printf "%s\t%s\t%s\t%s\n" "$server" "$service" "$exitcode" "$output" | $sendtonagios_fra1`;
   `/usr/bin/printf "%s\t%s\t%s\t%s\n" "$server" "$service" "$exitcode" "$output" | $sendtonagios_ams1`;

   # Prozentualer Anteil NXDOMAINS ans Nagios schicken
   $perfdata = "nxprozent=$nx_prozent";
   $service = "DNS-NXPROZENT";
   $output = "$service $exitstatus $string | $perfdata";
   `/usr/bin/printf "%s\t%s\t%s\t%s\n" "$server" "$service" "$exitcode" "$output" | $sendtonagios_fra1`;
   `/usr/bin/printf "%s\t%s\t%s\t%s\n" "$server" "$service" "$exitcode" "$output" | $sendtonagios_ams1`;
}

