#!/bin/bash

PASSWD=$1

echo $PASSWD | kinit admin
ipa config-mod --emaildomain=
printf "keystone\n$PASSWD\n$PASSWD" | ipa user-add --last=Administrator --first=none --uid=163 --gidnumber=163 --password
printf "$PASSWD\n$PASSWD\n$PASSWD" | kinit keystone
