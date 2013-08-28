#!/bin/bash
source colors

# Your sitename
echo -n "What domain should the site created for: "
read site
site_no_tld="${site%.*}"

# create new site
# apache config
cp /etc/apache2/sites-available/skeleton /etc/apache2/sites-available/$site
cp /etc/apache2/sites-available/ssl-skeleton /etc/apache2/sites-available/ssl-$site
# replace name with site_no_tld
/usr/bin/perl -i -pe "s/name/$site_no_tld/g" /etc/apache2/sites-available/$site /etc/apache2/sites-available/ssl-$site
# replace domain with site
/usr/bin/perl -i -pe "s/domain/$site/g" /etc/apache2/sites-available/$site /etc/apache2/sites-available/ssl-$site

# generate ssl csr and key
mkdir /etc/apache2/ssl/$site_no_tld
/etc/apache2/ssl/create-csr.sh $site_no_tld

# create logging directory
mkdir /var/log/apache2/$site_no_tld && chown -R www-data:www-data /var/log/apache2/$site_no_tld

# install last release of modx
echo -n "Which version of modx should be installed: "
read version
wget http://modx.com/download/direct/modx-$version-pl.zip -O /usr/local/src/modx-$version-pl.zip
unzip /usr/local/src/modx-$version-pl.zip -d /var/www/ && mv /var/www/modx-$version-pl /var/www/$site_no_tld-modx
chown -R www-data:www-data /var/www/$site_no_tld-modx

a2ensite $site
a2ensite ssl-$site

# can't start yet, cause ssl certificate not created
#apachectl -t 
#if [ $? -eq 0 ]; then 
#  apachectl graceful
#else
#  echo -e "${red}Couldn't restart apache. Config issue${nc}"
#fi


# postfix config
/usr/bin/perl -i -pe "s/^(mydestination =.*)/\$1, $site/g" /etc/postfix/main.cf
 # create alias for webmaster
 echo -e "webmaster@$site\tinfo" >> /etc/postfix/virtual
 #postmap /etc/postfix/virtual
 #if [ $? -eq 0 ]; then
 # /etc/init.d/postfix reload
 #else 
 # echo -e "${red}Couldn't reload postfix configuration. Postmap has failed.${nc}"
 #fi

# 
