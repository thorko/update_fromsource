#!/bin/bash
#$ID$

tmppath=/var/tmp/mozilla
version=$1
source="ftp://ftp.mozilla.org/pub/firefox/releases/$version/source/*.source.*bz2"

if [ -z $version ]; then
	echo "Usage: $0 <version>"
	exit 1
fi

/bin/mkdir $tmppath
cd $tmppath

# download source
/usr/bin/wget $source
/bin/tar -xjvf *.source.*bz2


echo -e ". \$topsrcdir/browser/config/mozconfig
ac_add_options --enable-optimize --enable-update-channel=release --enable-update-packaging --disable-debug --enable-tests --enable-official-branding
mk_add_options MOZ_OBJDIR=@TOPSRCDIR@/objdir-ff-release
mk_add_options MOZ_MAKE_FLAGS=\"-j4\" " > mozilla-1.9.2/mozconfig
cd mozilla*

# build firefox
make -f client.mk

# tar firefox
cd objdir-ff-release/dist/bin/
/bin/tar -cjhvf $tmppath/firefox-$version-x86_64.tar.bz2 ./

echo "your firefox is ready in $tmppath"
