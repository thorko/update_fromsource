#!/bin/bash
LOCK=/tmp/server-backup.lock
SRC=/opt/scripts/backup/server.conf
EXC=/opt/scripts/backup/server-exc.conf
DEST=/mnt/usb/server_backup
LOG=/var/log/server-backup.log
KEY=/root/.ssh/id_rsa
PORT=193
USER=root
HOST=thorko.de
LOGIN="ssh -i $KEY -p $PORT $USER@$HOST"
TODAY=$(date +'%Y%m%d')

function log() {
	echo $1
	echo $1 >> $LOG 2>&1
}

if [ `id -u` -ne 0 ]; then
	echo "Please run it as root"
	exit 1
fi

mount | grep usb
if [ $? == 1 ]; then
	log "opt of external disk not mounted, attempt to mount it"
	mount /dev/local/opt /mnt/usb
fi

# locking
if [ -e $LOCK ]; then
        log "Another instance running. Exiting"
        exit 0
fi
touch $LOCK

# rotate directories on remote system
test -d ${DEST}/${TODAY}
if [ ! -d ${DEST}/${TODAY} ]; then
        # get last day
        LASTDAY=$(ls -t -1 ${DEST} |tail -1)
        # copy using hard-links to preserve disk space
        /bin/cp -al ${DEST}/${LASTDAY} ${DEST}/${TODAY}
fi

# make backup of all databases
if [ ! -d ${DEST}/${TODAY}/db/ ]; then
	mkdir $DEST/$TODAY/db
fi
$($LOGIN 'mysqldump -uroot -pMyp@n3tbc. --all-databases' > ${DEST}/${TODAY}/db/db.sql)

rsync -LpDtgHrz --log-file=$LOG --delete --exclude-from=$EXC --files-from=$SRC root@thorko.de:/ ${DEST}/${TODAY}/files

rm -f $LOCK
