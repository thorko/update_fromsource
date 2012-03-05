#!/usr/bin/env expect 
#$ID$
set timeout 60 
set password "yourpass"
set host [lrange $argv 1 1]
set user [lrange $argv 0 0]
spawn ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o NumberOfPasswordPrompts=1 -l $user $host 
expect "\[Pp\]assword: $" 
send "$password\n" 
interact
