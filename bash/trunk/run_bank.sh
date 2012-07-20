#!/bin/bash
cipher="AES256"
file=/opt/scripts/perl/trunk/get_bank_status.pl.pgp
documents=/home/thorko/Documents/bank

function decrypt_and_run () {
	fn="${file%.*}"
	echo $fn
	gpg -d --no-use-agent -o $fn $file
	perl $fn
	rm $fn
}

function show () {
	# get latest document
	cd $documents
	file=$(ls -tr | tail -n 1)
	filename=$(echo ${file%.*})
	gpg --no-use-agent -d -o $filename $file

	firefox $filename
}

function clean () {
	cd $documents
	find . -name "*.html" -exec rm -f {} \;
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
