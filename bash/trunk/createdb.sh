#!/bin/bash


echo -n "Database to create: "
read _db

echo -n "User to create: "
read _dbuser

echo -n "Password to use: "
read _dbpass

echo -n "Your mysql root password: "
read _dbrootpw

mysql -u root -p$_dbrootpw -e "create database $_db; create user '$_dbuser'@'localhost' identified by '$_dbpass'; grant all on $_db.* to '$_dbuser'@'localhost' identified by '$_dbpass'; flush privileges;"
