#!/bin/bash

PASSWD=$1
KEYSTONE_IPA_USER=keystone
NOVA_IPA_USER=nova
GLANCE_IPA_USER=glance
CINDER_IPA_USER=cinder

echo $PASSWD | kinit admin
ipa config-mod --emaildomain=

printf "$KEYSTONE_IPA_USER\n$PASSWD\n$PASSWD" | ipa user-add --last=Administrator --first=none --uid=163 --gidnumber=163 --password
printf "$PASSWD\n$PASSWD\n$PASSWD" | kinit $KEYSTONE_IPA_USER

echo $PASSWD | kinit admin
printf "$NOVA_IPA_USER\n$PASSWD\n$PASSWD" | ipa user-add --last=Administrator --first=none --uid=162 --gidnumber=162 --password
printf "$PASSWD\n$PASSWD\n$PASSWD" | kinit $NOVA_IPA_USER

echo $PASSWD | kinit admin
printf "$GLANCE_IPA_USER\n$PASSWD\n$PASSWD" | ipa user-add --last=Administrator --first=none --uid=161 --gidnumber=161 --password
printf "$PASSWD\n$PASSWD\n$PASSWD" | kinit $GLANCE_IPA_USER

echo $PASSWD | kinit admin
printf "$CINDER_IPA_USER\n$PASSWD\n$PASSWD" | ipa user-add --last=Administrator --first=none --uid=165 --gidnumber=165 --password
printf "$PASSWD\n$PASSWD\n$PASSWD" | kinit $CINDER_IPA_USER
