#!/bin/bash
source /home/functions.sh

IPA=$1
REALM=$2
DB=$3
PASSWD=$4

KEYSTONE_DB_USER=test_keystone
NOVA_DB_USER=test_nova
GLANCE_DB_USER=test_glance
CINDER_DB_USER=test_cinder

KEYSTONE_IPA_USER=keystone
NOVA_IPA_USER=nova
GLANCE_IPA_USER=glance
CINDER_IPA_USER=cinder

KEYSTONE_DB_NAME=keystone
NOVA_DB_NAME=nova
GLANCE_DB_NAME=glance
CINDER_DB_NAME=cinder

KEYSTONE_EUID=163
NOVA_EUID=162
GLANCE_EUID=161
CINDER_EUID=165

LOCAL_IP=`hostname -I`
LOCAL_IP="${LOCAL_IP%"${LOCAL_IP##*[![:space:]]}"}"

sync_ntp $IPA
# no need to remove mariadb if using mariadb-galera
#remove_mariadb
kinit_admin $PASSWD
install_mariadb $IPA $REALM $DB

create_db_user $KEYSTONE_DB_USER $KEYSTONE_IPA_USER $REALM $KEYSTONE_DB_NAME
get_keystone_keytab $PASSWD $REALM $IPA $KEYSTONE_IPA_USER $KEYSTONE_EUID $KEYSTONE_DB_USER

create_db_user $NOVA_DB_USER $NOVA_IPA_USER $REALM $NOVA_DB_NAME
get_nova_keytab $PASSWD $REALM $IPA $NOVA_IPA_USER $NOVA_EUID $NOVA_DB_USER

create_db_user $GLANCE_DB_USER $GLANCE_IPA_USER $REALM $GLANCE_DB_NAME
get_glance_keytab $PASSWD $REALM $IPA $GLANCE_IPA_USER $GLANCE_EUID $GLANCE_DB_USER

create_db_user $CINDER_DB_USER $CINDER_IPA_USER $REALM $CINDER_DB_NAME
get_cinder_keytab $PASSWD $REALM $IPA $CINDER_IPA_USER $CINDER_EUID $CINDER_DB_USER

#TODO use the keystonerc_admin instead for now
#create_keystonerc $PASSWD $LOCAL_IP
