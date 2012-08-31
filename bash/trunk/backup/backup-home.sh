#/bin/bash

# config variables
KEEP=7				# keep backup in days
SOURCES=/opt/scripts/bash/trunk/backup/sources.conf		# list of directories to bakup
EXCLUDES=/opt/scripts/bash/trunk/backup/excludes.conf
USER=root			# remote user
HOST=thorko.de			# remote host
PORT=193			# remote port
KEY=/root/.ssh/id_rsa
DEST=/home/thorko/backup/thorko-laptop/home	# remote destination
LOG=/var/log/backup.log
LOCK=/tmp/backup.lock
################################

TODAY=$(date +'%Y%m%d')
LOGIN="ssh -i $KEY -p $PORT $USER@$HOST"

# locking
if [ -e $LOCK ]; then
	echo "$(date) Another instance running. Exit" >> $LOG 2>&1
	exit 0
fi
touch $LOCK

# check if remote host is reachable
ping -c 1 $HOST > /dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "$(date) no network connectivity" >> $LOG 2>&1
	exit 1
fi

# rotate directories on remote system
echo "if [ ! -d ${DEST}/backup.${TODAY} ]; then
	/bin/cp -Rpl ${DEST}/\$(ls -1 ${DEST} | tail -1) ${DEST}/backup.${TODAY} 
fi

if [ \$(ls -1 $DEST/ | wc -l) -gt $KEEP ]; then 
	ls -1 -r --color=never $DEST/ | tail -n 1 | xargs rm -rf 
fi" > /tmp/cphome.sh

cat /tmp/cphome.sh | $LOGIN

/usr/bin/rsync -LpDtgHrz -e "ssh -i $KEY -p $PORT" --log-file=$LOG --delete --exclude-from=$EXCLUDES --files-from=$SOURCES / $USER@$HOST:$DEST/backup.$TODAY

rm -f $LOCK
