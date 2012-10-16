#!/usr/bin/php
<?php
require_once('Log.php');

// logging settings
$log_level = PEAR_LOG_INFO;
//$log_level = PEAR_LOG_DEBUG;
$logconf = array('mode' => 0775, 'timeFormat' => '%X %x');
$logger = &Log::singleton('file', '/var/log/sms.log', 'ident', $logconf, $log_level);

$cfg_array = parse_ini_file("/etc/zabbix/alert.d/smsclickatell.ini");

// Do not change anything beneath this line:
 
if($_SERVER["argc"]<3){
 $logger->log("Usage: ".$_SERVER["argv"][0]." recipientmobilenumber message", PEAR_LOG_ERR);
 die("Usage: ".$_SERVER["argv"][0]." recipientmobilenumber message\n");
}
 
$apiargs=array();
$apiargs["key"]=$cfg_array["key"];
$apiargs["to"]=$_SERVER["argv"][1];
$apiargs["message"]=$_SERVER["argv"][2];
$apiargs["route"]=$cfg_array["route"];
$apiargs["debug"]=$cfg_array["debug"];
$apiargs["cost"]=$cfg_array["cost"];
$apiargs["message_id"]=$cfg_array["message_id"];
$apiargs["charset"]=$cfg_array["charset"];
//$apiargs["from"]="4917683035400";
 
$url="http://gateway.smstrade.de/?";
foreach($apiargs as $k=>$v)$url.="$k=".urlencode($v)."&";

$result_1 = @file($url);

$logger->log("Send sms to ".$apiargs["to"]." Msg: ".$apiargs["message"]." Result: ".intval($result_1[0])." msgID: ".intval($result_1[1])." Cost: ".floatval($result_1[2]), PEAR_LOG_INFO);
?>
