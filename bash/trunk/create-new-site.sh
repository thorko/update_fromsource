#!/bin/bash
source colors

# Your sitename
echo -n "What domain should the site created for: "
read site

# create new site
# apache config
cp /etc/apache2/sites-available/skeleton /etc/apache2/sites-available/$site
cp /etc/apache2/sites-available/ssl-skeleton /etc/apache2/sites-available/ssl-$site

a2ensite $site
a2ensite ssl-$site

apachectl -t 
if [ $? -eq 0 ]; then 
  apachectl graceful
else
  echo -e "${red}Couldn't restart apache. Config issue${nc}"
fi


# postfix config
perl -i -e "s/^(mydestination =.*)/\$1, $site/g" /etc/postfix/main.cf
 # create alias for webmaster
 echo -e "webmaster@$site\tinfo" >> /etc/postfix/virtual
 postmap /etc/postfix/virtual
 if [ $? -eq 0 ]; then
  /etc/init.d/postfix reload
 else 
  echo -e "${red}Couldn't reload postfix configuration. Postmap has failed.${nc}"
 fi

# 
