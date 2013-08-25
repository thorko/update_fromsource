#!/bin/bash

# Your sitename
echo -n "What domain should the site created for: "
read site

# create new site


# apache config


# postfix config
perl -i -e "s/^(mydestination =.*)/\$1, $site/g" /etc/postfix/main.cf
 # create alias for webmaster
 echo -e "webmaster@$site\tinfo" >> /etc/postfix/virtual
 postmap /etc/postfix/virtual
 if [ $? -eq 0 ]; then
  /etc/init.d/postfix reload
 else 
  echo "Couldn't reload postfix configuration. Postmap has failed."
 fi

# 
