#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Long;
use Log::Log4perl qw(:easy);
use Denic::Log4perl::Conf;
use POSIX qw(strftime);

my $help = 0;
my $keep = 5;

my $tables="actions application_template applications autoreg_host conditions config dbversion dchecks dhosts drules dservices escalations expressions functions globalmacro globalvars graph_discovery graph_theme graphs graphs_items group_discovery group_prototype groups hostmacro hosts hosts_groups hosts_templates housekeeper httpstep httpstepitem httptest httptestitem host_discovery host_inventory icon_map icon_mapping ids images interface interface_discovery item_discovery items items_applications maintenances maintenances_groups maintenances_hosts maintenances_windows mappings media media_type node_cksum nodes opcommand opcommand_grp opcommand_hst opconditions operations opgroup opmessage opmessage_grp opmessage_usr optemplate profiles proxy_autoreg_host proxy_dhistory proxy_history regexps rights screens screens_items scripts service_alarms services services_links services_times slides slideshows sysmap_element_url sysmap_url sysmaps sysmaps_elements sysmaps_link_triggers sysmaps_links timeperiods trigger_depends trigger_discovery triggers user_history users users_groups usrgrp valuemaps";
my $tables_list = "";
my $user="root";
my $database="zabbix";
my $backupdir = "";
my $date = strftime "%Y-%m-%d", localtime;

Getopt::Long::Configure('bundling');
GetOptions(
  "h|help" => \$help,
  "b|backupdir=s" => \$backupdir,
  "k|keep=i" => \$keep,
  );


if ( $backupdir eq "" || $help ) {
	&print_help();
	exit 1;
}

init_logger();

ERRORDIE("Backup directory doesn't exist") if ( ! -d $backupdir);

my $backupfile = $backupdir."/zabbix_config.sql"."-$date";
if ( -e "$backupfile.gz" ) {
	unlink "$backupfile.gz";
}

###### Build sql restore script ######
open(SQLDUMP, ">>$backupfile") || ERRORDIE("Couldn't write to $backupfile\n");
print SQLDUMP "
START TRANSACTION;
set FOREIGN_KEY_CHECKS=0;\n";
foreach my $t ( split(/ /, $tables) ) {
	print SQLDUMP "TRUNCATE $t;\n";
}
close SQLDUMP;

foreach my $t ( split(/ /, $tables) ) {
	$tables_list .= " $t ";
}

system("/usr/bin/mysqldump -u $user --single-transaction $database $tables_list >> $backupfile 2>/dev/null");

open(SQLDUMP, ">>$backupfile") || ERRORDIE("Couldn't write to $backupfile\n");
print SQLDUMP "COMMIT;\n";
close SQLDUMP;
system("/bin/gzip $backupfile");
system("/bin/rm -f $backupdir/zabbix_config_dump.sql.gz");
link("$backupfile.gz", "$backupdir/zabbix_config_dump.sql.gz");
INFO("Zabbix Config successfully exported");
my $cc = qx(ls -t -1 $backupdir | wc -l);
my $td = (($cc-$keep) < 0) ? 0 : ($cc-$keep);
system("ls -t -1 $backupdir | tail -n $td | xargs rm -f ");
INFO("Old config deleted.");
#######################################

sub print_help {
	print <<'HELP'
zbxsyncconf.pl -b <backup directory> [-k] [-v] [-h]

-b, --backupdir		backup directory
-k, --keep		how many config backups to keep 
			default: 5

zbxsyncconf.pl will backup the configuration of Zabbix. 
It does not backup the historical data.

If you want to restore the backup simply run
mysql -u root zabbix < {backupfile}
You need to prepare the schema of the zabbix database before you can restore the config.
HELP
}
