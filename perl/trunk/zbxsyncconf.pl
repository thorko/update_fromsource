#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Long;
use Log::Log4perl qw(:easy);

my $debug = 0;
my $help = 0;

my $tables="actions applications autoreg_host conditions config dchecks dhosts drules dservices escalations expressions functions globalmacro globalvars graph_discovery graph_theme graphs graphs_items groups help_items hostmacro hosts hosts_groups host_inventory hosts_templates housekeeper httpstep httpstepitem httptest httptestitem icon_map icon_mapping ids images interface item_discovery items items_applications maintenances maintenances_groups maintenances_hosts maintenances_windows mappings media media_type node_cksum nodes opcommand opcommand_grp opcommand_hst opconditions operations opgroup opmessage opmessage_grp opmessage_usr optemplate profiles proxy_autoreg_host proxy_dhistory proxy_history regexps rights screens screens_items scripts service_alarms services services_links services_times slides slideshows sysmap_element_url sysmap_url sysmaps sysmaps_elements sysmaps_link_triggers sysmaps_links timeperiods trigger_depends trigger_discovery triggers user_history users users_groups usrgrp valuemaps";
my $tables_list = "";
my $user="postgres";
my $schema="public";
my $database="zabbix";
my $remote_host = "";
my $zbx_cf_dump = "/tmp/zabbix_config_dump.sql";


Getopt::Long::Configure('bundling');
GetOptions(
  "h|help" => \$help,
  "r|remote=s" => \$remote_host,
  "u|user=s" => \$user,
  "d|database=s" => \$database,
  "s|schema=s" => \$schema,
  );


if ( $remote_host eq "" || $help ) {
	&print_help();
	exit 1;
}

init_logger();

system("rm -f $zbx_cf_dump") if ( -e $zbx_cf_dump);
ERRORDIE("Couldn't delete $zbx_cf_dump") if ($? != 0);

###### Build sql restore script ######
open(SQLDUMP, ">>$zbx_cf_dump") || ERRORDIE("Couldn't write to $zbx_cf_dump\n");
print SQLDUMP "SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

SET search_path = public, pg_catalog;
BEGIN;\n";
foreach my $t ( split(/ /, $tables) ) {
	print SQLDUMP "TRUNCATE $t CASCADE;\n";
}
close SQLDUMP;

foreach my $t ( split(/ /, $tables) ) {
	$tables_list .= "-t $t ";
}

system("/usr/bin/pg_dump -U $user -a --schema=$schema $tables_list $database >> $zbx_cf_dump 2>/dev/null");
ERRORDIE("pg_dump of zabbix config tables on $database failed\n") if( $? != 0 );

open(SQLDUMP, ">>$zbx_cf_dump") || ERRORDIE("Couldn't write to $zbx_cf_dump\n");
print SQLDUMP "COMMIT;\n";
close SQLDUMP;
#####################################

system("/bin/cat $zbx_cf_dump | ssh $remote_host \"cat - | psql -U $user -d $database\ | grep COMMIT\"");
if($? != 0) {
ERRORDIE("restore of the $zbx_cf_dump script on $remote_host failed\nPlease check $zbx_cf_dump for syntax issues\n 
          to test run: /bin/cat $zbx_cf_dump | ssh $remote_host \"cat - | psql -U $user -d $database\"\n");
} else {
   INFO("Sync of zabbix configuration tables to $remote_host successfull");
}

system("/bin/rm -f $zbx_cf_dump");

sub print_help {
	print <<'HELP'
zbxsyncconf.pl -r <remote host> [-d <database>] [-u <user>] [-s <schema>] [-v] [-h]

-r, --remote		remote host to sync to
-v, --verbose           enable verbose output
-u, --user		user which runs the dump and restore
-d, --database		database name of zabbix
-s, --schema		schema of zabbix
HELP
}
