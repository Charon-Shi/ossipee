#!/bin/bash
source /home/functions.sh

IPA=$1
REALM=$2
DB=$3
PASSWD=$4
DB_USER=keystone
IPA_USER=keystone
LOCAL_IP=`hostname -I`
LOCAL_IP="${LOCAL_IP%"${LOCAL_IP##*[![:space:]]}"}"

sync_ntp $IPA
remove_mariadb
kinit_admin $PASSWD
install_mariadb $IPA $REALM $DB $DB_USER $IPA_USER
get_keytab $PASSWD $REALM $IPA $IPA_USER
create_keystonerc $PASSWD $LOCAL_IP
