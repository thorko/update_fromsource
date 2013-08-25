#!/bin/bash

path="/etc/apache2/ssl"

name=$1

if [ "x$name" = "x" ]; then
	echo "Usage: $0 <name>"
	exit 1
fi

echo -n "In which directory you want to store the CSR: "
read dir


openssl genrsa -out $path/$dir/${name}.key 4096
openssl req -new -key $path/$dir/${name}.key -out $path/$dir/${name}.csr

cat  $path/$dir/${name}.csr
