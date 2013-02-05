#!/bin/bash


echo "SSH => 4444"
echo "VNC => 5901"

case "$1" in 
	ssh)
		ssh -L 4444:thorko.de:7889 thorko.de
	;;
	vnc)
		ssh -L 5901:thorko.de:7888 thorko.de
	;;
	both)
		ssh -L 4444:thorko.de:7889 -L 5901:thorko.de:7888 thorko.de
	;;
	*)
		echo "Usage: $0 <ssh|vnc|both>"
		exit 1
	;;

esac
