#!/usr/bin/perl -w
#$ID$
# ##############################################################################
# Copyright (c) 2007,2008 Lars Michelsen http://www.vertical-visions.de
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following
# conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
# ##############################################################################
# SCRIPT:       nagios_downtime
# AUTHOR:       Lars Michelsen
# DECRIPTION:   Sends a HTTP(S)-GET to the nagios web server to
#	              enter a downtime for a host or service.
# CHANGES IN 0.4:
# 19.05.2008    - Some code formating
#               - The downtime type is now automaticaly detected on given params
#               - Changed case of the parameters
#               - Added proxy configuration options
#               - User Agent is now "nagios_downtime.pl / <version>"
#               - Added parameter -S and -p for setting server options via param
# CHANGES IN 0.5:
# changes made by thorko
# 20.05.2011	- Added option for multiple hosts
#		- Added option for setting a start time of downtime
#
# $Id$
# ##############################################################################

# ##############################################################################
# Configuration (-> Here you have to set some values!)
# ##############################################################################

# Protocol for the GET Request, In most cases "http", "https" is also possible
my $nagiosWebProto = "http";
# IP or FQDN of Nagios server (example: nagios.domain.de)
my $nagiosServer = "nagios-nsl-1.fra1.svc.denic.de";
# IP or FQDN of Nagios web server. In most cases same as $nagiosServer, if
# empty automaticaly using $nagiosServer
#my $nagiosWebServer = "nagios-nsl-1.fra1.svc.denic.de";
my $nagiosWebServer = "";
# Port of Nagios webserver (If $nagiosWebProto is set to https, this should be
# SSL Port 443)
my $nagiosWebPort = 80;
# Web path to Nagios cgi-bin (example: /nagios/cgi-bin) (NO trailing slash!)
my $nagiosCgiPath = "/nagios/cgi-bin";
# User to take for authentication and author to enter the downtime (example:
# nagiosadmin)
my $nagiosUser = "thorstek";
# Password for above user
my $nagiosUserPw = "";
# Name of authentication realm, set in the Nagios .htaccess file 
# (example: "Nagios Access")
my $nagiosAuthName = "Nagios Access";
# Nagios date format (same like set in value "date_format" in nagios.cfg)
my $nagiosDateFormat = "iso8601";
# When you have to use a proxy server for access to the nagios server, set the
# URL here. The proxy will be set for this script for the choosen web protocol
# When this is set to 'env', the proxy settings will be read from the env.
my $proxyAddress = 'http://172.21.4.14:8080';

# Some default options (Usualy no changes needed below this)

# Default downtime type (1: Host Downtime, 2: Service Downtime)
my $downtimeType = 1;
# Default Downtime duration in minutes
my $downtimeDuration = 10;
# Default Downtime text
my $downtimeComment = "Perl Downtime-Script";
# Default Debugmode: off => 0 or on => 1
my $debug = 0;
# Script version
my $version = "0.5";

# ##############################################################################
# Don't change anything below, except you know what you are doing.
# ##############################################################################

use strict;
use warnings;
use Net::Ping;
use LWP 5.64;
use Sys::Hostname;
use Getopt::Long;
use Switch;

my $arg;
my $p;
my $i = 0;
my $oBrowser;
my $oResponse;
my $hostname = "";
my $service = "";
my $start;
my $starttime;
my $end;
my $url = "";
my $help = "";

Getopt::Long::Configure('bundling');
GetOptions(
	"h|help" => \$help,
	"d|debug"   => \$debug,
	"H|hostname=s" => \$hostname,
	"S|server=s" => \$nagiosServer,
	"p|path=s" => \$nagiosCgiPath,
	"b|starttime=s" => \$starttime,
	"t|downtime=i" => \$downtimeDuration,
	"c|comment=i" => \$downtimeComment,
	"s|service=s" => \$service);

if($help) {
	about();
	exit(0);
}

# Get hostname if not set via param
if($hostname eq "") {
	$hostname = hostname;
}

# When no nagios webserver is set the webserver and Nagios should be on the same
# host 
if($nagiosWebServer eq "") {
	$nagiosWebServer = $nagiosServer;
}

# When a service name is set, this will be a service downtime
if($service ne "") {
	$downtimeType = 2;
}

# set time
if($starttime eq "") {
	# Calculate the start of the downtime
	$start = gettime(time+60);
} else {
	my @time = split(/#/,$starttime);
	$start = $time[0]." ".$time[1];
}
 
# Calculate the end of the downtime
$end = gettime(time+$downtimeDuration*60);

#print "start: $start\n";
#exit 0;

# split hosts and set a downtime for all of it
my @hosts = split(/,/, $hostname);

foreach my $host (@hosts) {
         print "#" x 20;
	 print "\nSetting downtime for $host\n";
# Check if Nagios web server is reachable via ping, if not, terminate the script
#$p = Net::Ping->new();
#if(!$p->ping($nagiosWebServer)) {
	# Nagios web server is not pingable
#	print "ERROR: Given Nagios web server \"" . $nagiosWebServer . "\" not reachable via ping\n";
#	exit(1);
#} else {
	# initialize browser
	$oBrowser = LWP::UserAgent->new(keep_alive => 1,timeout => 10);
	$oBrowser->agent("nagios_downtime.pl / " . $version);
	
	# Set the proxy address depending on the configured option
	if($proxyAddress eq 'env') {
		$oBrowser->env_proxy = 1;
	} else {
		$oBrowser->proxy([$nagiosWebProto], $proxyAddress);
	}

	if($downtimeType == 1) {
		# Schedule Host Downtime
		$url = $nagiosWebProto . "://" . $nagiosWebServer . ":" . $nagiosWebPort . $nagiosCgiPath . "/cmd.cgi?cmd_typ=55&cmd_mod=2" .
			"&host=" . $host .
			"&com_author=" . $nagiosUser . "&com_data=" . $downtimeComment .
			"&trigger=0&start_time=" . $start . "&end_time=" . $end .
			"&fixed=1&childoptions=1&btnSubmit=Commit";

		if($debug == 1) {
			print "HTTP-GET: " . $url;
		}
	} else {
		# Schedule Service Downtime
		$url = $nagiosWebProto . "://" . $nagiosWebServer . ":" . $nagiosWebPort . $nagiosCgiPath . "/cmd.cgi?cmd_typ=56&cmd_mod=2" .
			"&host=" . $host . "&service=" . $service .
			"&com_author=" . $nagiosUser . "&com_data=" . $downtimeComment .
			"&trigger=0&start_time=" . $start . "&end_time=" . $end .
			"&fixed=1&btnSubmit=Commit";
		
		if($debug == 1) {
			print "HTTP-GET: " . $url;
		}
	}
 
	# Only try to auth if auth informations given
	if($nagiosAuthName ne "" && $nagiosUserPw ne "") {
		# submit auth informations
		$oBrowser->credentials($nagiosWebServer.':'.$nagiosWebPort, $nagiosAuthName, $nagiosUser => $nagiosUserPw);
	}

	# Send the get request to the web server
	$oResponse = $oBrowser->get($url);

	if($debug == 1) {
		print "HTTP-Response: " . $oResponse->content;
	}

	# Handle response code, not in detail, only first char
	switch(substr($oResponse->code,0,1)) {
		# 2xx response code is OK
		case 2 {
			# Do some basic handling with the response content
			switch($oResponse->content) {
				case /Your command request was successfully submitted to Nagios for processing/ {
					print "OK: Downtime was submited successfully\n";
					#exit(0);
				}
				case /Sorry, but you are not authorized to commit the specified command\./ {
					print "ERROR: Maybe not authorized or wrong host- or servicename\n";
					#exit(1);
				}
				case /Author was not entered/ {
					print "ERROR: No Author entered, define Author in \$nagiosUser var\n";
					#exit(1);
				}
				else {
					print "ERROR: Some undefined error occured, turn debug mode on to view what happened\n";
					#exit(1);
				}
			}
		}
		case 3 {
			print "ERROR: HTTP Response code 3xx says \"moved url\" (".$oResponse->code.")\n";
			#exit(1);
		}
		case 4 {
			print "ERROR: HTTP Response code 4xx says \"client error\" (".$oResponse->code.")\n";
			#exit(1);
		}
		case 5 {
			print "ERROR: HTTP Response code 5xx says \"server error\" (".$oResponse->code.")\n";
			#exit(1);
		}
		else {
			print "ERROR: HTTP Response code unhandled by script (".$oResponse->code.")\n";
			#exit(1);
		}
	}
	print "#" x 20 ."\n";
#}
}

# Regular end of script
# ##############################################################################

# ###
# Subs
# ###

sub about {
		print <<'ABOUT';
Usage:
  nagios_downtime [-H <hostname>] [-s <service>] [-t <minutes>] [-S <webserver>] [-p <cgi-bin-path>] [-d]
  nagios_downtime -h

Nagios Downtime Script by Lars Michelsen <lars@vertical-visions.de>
Sends a HTTP(S) request to the nagios cgis to add a downtime for a host or service.

Parameters:
 -H, --hostname(s)   Name of the host(s) the downtime should be scheduled for.
                     Important: The name must be same as in Nagios.(Hostnames seperated by comma)
 -s, --service       Name of the service the downtime should be scheduled for.
                     Important: The name must be same as in Nagios. 
                     When empty or not set a host downtime is being submited.
 -b, --starttime     Start time of downtime (Format: YYYY-mm-dd#HH:MM:SS)
 -t, --downtime      Duration of the fixed downtime in minutes
 -c, --comment       Comment for the downtime
 -S, --server        Nagios Webserver address (IP or DNS)
 -p, --path          Web path to Nagios cgi-bin (Default: /nagios/cgi-bin)
 -d, --debug         Enable debug mode
 -h, --help          Show this message

If you call nagios_downtime without parameters the script takes the default options which are
hardcoded in the script.

ABOUT
}

sub gettime {
	my $timestamp;
	$timestamp = shift;

	if($timestamp eq "") {
			$timestamp = time;
	}

	my ($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst) = localtime($timestamp);
	# correct values
	$year += 1900;
	$month += 1;

	# add leading 0 to values lower than 10
	$month = $month < 10 ? $month = "0".$month : $month;
	$mday = $mday < 10 ? $mday = "0".$mday : $mday;
	$hour = $hour < 10 ? $hour = "0".$hour : $hour;
	$min = $min < 10 ? $min = "0".$min : $min;
	$sec = $sec < 10 ? $sec = "0".$sec : $sec;

	switch ($nagiosDateFormat) {
		case "euro" {
			return $mday."-".$month."-".$year." ".$hour.":".$min.":".$sec;
		}
		case "us" {
			return $month."-".$mday."-".$year." ".$hour.":".$min.":".$sec;
		}
		case "iso8601" {
			return $year."-".$month."-".$mday." ".$hour.":".$min.":".$sec;
		}
		case "strict-iso8601" {
			return $year."-".$month."-".$mday."T".$hour.":".$min.":".$sec;
		}
		else {
			print "ERROR: No valid date format given in \$nagiosDateFormat";
			exit(1);
		}
	}
}

# #############################################################
# EOF
# #############################################################
