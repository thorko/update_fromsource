#!/bin/bash
cipher="AES256"
file[0]=/opt/scripts/perl/trunk/get_bank_status_comdirect.pl.pgp
file[1]=/opt/scripts/perl/trunk/get_bank_status_dkb.pl.pgp
documents=/home/thorko/Documents/bank

function decrypt_and_run () {
	for l in "${file[@]}"; do
		fn="${l%.*}"
		echo $fn
		gpg -d --no-use-agent -o $fn $l
		perl $fn
		rm $fn
	done
}

function show () {
	for l in "${file[@]}"; do
		fn="${l%.*}"
        	gpg -d --no-use-agent -o $fn $l
        	perl $fn -s
		rm -f $fn
	done
}

function clean () {
	cd $documents
	find . -name "*.html" -exec rm -f {} \;
	find . -name "*.csv" -exec rm -f {} \;
}

option=$1

case "$option" in
	show)
		show
		;;
	clean)
		clean
		;;
	*)
		decrypt_and_run
		;;
esac
