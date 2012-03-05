#!/bin/bash
#$ID$

tmppath=/var/tmp/mozilla
version=$1
source="ftp://ftp.mozilla.org/pub/thunderbird/releases/$version/source/*source*.bz2"

if [ -z $version ]; then
	echo "Usage: $0 <version>"
	exit 1
fi

#/bin/mkdir $tmppath
cd $tmppath

# download source
/usr/bin/wget $source
/bin/tar -xjvf *.source.*bz2


echo -e "mk_add_options MOZ_OBJDIR=@TOPSRCDIR@/tbird
mk_add_options MOZ_CO_PROJECT=mail
mk_add_options MOZ_MAKE_FLAGS=\"-j3\"
ac_add_options --enable-application=mail
ac_add_options --enable-optimize=-O2
ac_add_options --enable-freetype2
ac_add_options --enable-static 
" > comm-1.9.2/.mozconfig
cd comm*

# build firefox
make -f client.mk build

# tar firefox
cd tbird/mozilla/dist/bin/
/bin/tar -cjhvf $tmppath/thunderbird-$version-x86_64.tar.bz2 ./

echo "your thunderbird is ready in $tmppath"
