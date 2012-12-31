#!/bin/sh
 
SADIR=/var/spool/bayes
DBPATH=$SADIR/bayes
LOCK=/tmp/sa-learn.lck
log="/var/log/sa-learn.log"

if [ -f $LOCK ]; then
	echo "Another instance running"
	exit 1
fi
touch $LOCK


# Learn Spam
echo "Learning Spam"
echo "##############################################"
for i in $(find /var/spool/*/*/Maildir/.Learn.Spam/{cur,new} -type f -ctime -1); do
 if [ "x$i" != "x" ]; then
   /usr/bin/sa-learn --spam --no-sync $i >> $log
   /usr/local/bogofilter/current/bin/bogofilter -l -Ns < $i
   rm -f $i
 fi
done

# Learn Ham
echo "Learning Ham"
echo "##############################################"
for i in $(find /var/spool/*/*/Maildir/.Learn.Ham/{cur,new} -type f -ctime -1); do
 if [ "x$i" != "x" ]; then
   /usr/bin/sa-learn --ham --no-sync $i >> $log
   /usr/local/bogofilter/current/bin/bogofilter -l -Sn < $i
   rm -f $i
 fi
done


# add whitelist
echo "Adding sender address to whitelist"
echo "##############################################"
for y in $(find /var/spool/dovecot/ -maxdepth 1 -type d); do
  user=$(basename $y)
  for i in $(find /var/spool/dovecot/$user/Maildir/.Learn.Whitelist/{cur,new} -type f -ctime -1); do
    if [ "x$i" != "x" ]; then
      fromline=$(grep "From:" $i)
      sender=$(expr match "$fromline" '\From:\s.*\s<\(.*\)>')
      mysql -u roundcube -pxHY2f7MBh0 roundcube -e "insert into spam_userpref (username, preference, value) values('$user', 'whitelist_from', '$sender');"
      rm -f $i
    fi
  done
done

# sync db
echo -n $(date +'%Y-%m-%d %H:%M:%d') >> $log
sa-learn --sync >> $log

# rebuild index
for i in $(find /var/spool/dovecot -mindepth 1 -maxdepth 1 -type d); do
	echo "rebuild index.... "$(basename $i)
        doveadm -v index -u $(basename $i) Learn.Spam
        doveadm -v index -u $(basename $i) Learn.Ham
done

rm -f $LOCK
