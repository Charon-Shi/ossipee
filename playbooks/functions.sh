#!/bin/bash

# Overall idea:
# 1. kinit as admin
# 2. install mariadb-galera
# 3. fetch keytab for mariadb-galera
# 4. fetch keytab for keystone as ipa user
# 5. fetch keytab for nova as ipa user
#TODO  6. fetch keytab for cinder and neutron as ipa users

# must run under sudo
# must have ipa-client running

sync_ntp() {
_IPA=$1
ntpdate -u $_IPA
}

remove_mariadb() {
#no need to invoke if using mariadb-galera instead of mariadb since we need to save original data
yum remove -y mariadb-server mariadb
}

remove_all() {
#TODO _EUID can be multiple and should be specified
_REALM=$1
_IPA=$2
_IPA_USER=$3
_EUID=$4

ipa-rmkeytab -p MySQL/$(hostname -f)@$_REALM -k /var/lib/mysql/mysql.keytab
ipa service-del MySQL/$(hostname -f)
yum remove -y mariadb-server mariadb

ipa-rmkeytab -p $_IPA_USER@$_REALM -k /var/kerberos/krb5/user/$_EUID/client.keytab
sudo rm -r /var/kerberos/krb5/user/$_EUID
sudo rm -r /home/keystone.rc
}

kinit_admin() {
_PASSWD=$1

echo "$_PASSWD" | kinit admin
}

install_mariadb() {
_IPA=$1
_REALM=$2
_DB=$3
#_DB_USER=$4     transfered to get_keytab function
#_IPA_USER=$5    transfered to get_keytab function

yum install -y ipa-admintools

cd /etc/yum.repos.d/
wget https://copr.fedoraproject.org/coprs/rharwood/mariadb/repo/epel-7/rharwood-mariadb-epel-7.repo

yum install -y epel-release
yum update -y
#yum install -y  mariadb{,-debuginfo,-devel,-libs,-server}
yum install -y mariadb-galera{,-debuginfo,-server}
ipa service-add MySQL/$(hostname -f)

cd /var/lib/mysql
ipa-getkeytab -s $_IPA -p MySQL/$(hostname -f)@$_REALM -k mysql.keytab
chown mysql:mysql mysql.keytab
chmod 660 /var/lib/mysql/mysql.keytab

service mariadb start
mysql -u root << EOF
install plugin kerberos soname 'kerberos';
EOF

service mariadb stop
cd /etc/my.cnf.d/
#sed -i "/\[server\]/a kerberos_principal_name=MySQL\/$_DB@$_REALM\nkerberos_keytab_path=/var/lib/mysql/mysql.keytab"  server.cnf
echo "[server]" >> server.cnf
echo "kerberos_principal_name=MySQL/$_DB@$_REALM" >> server.cnf
echo "kerberos_keytab_path=/var/lib/mysql/mysql.keytab" >> server.cnf
service mariadb start
}

create_db_user() {
_DB_USER=$1
_IPA_USER=$2
_REALM=$3
_DB_NAME=$4

mysql -u root << EOF    
CREATE USER $_DB_USER IDENTIFIED VIA kerberos AS '$_IPA_USER@$_REALM';
GRANT ALL PRIVILEGES ON $_DB_NAME.* to $_DB_USER@'%';
EOF
}

get_keystone_keytab() {
_PASSWD=$1
_REALM=$2
_IPA=$3
_KEYSTONE_IPA_USER=$4
_KEYSTONE_EUID=$5
_KEYSTONE_DB_USER=$6

#comment out the keystone line in /etc/passwd
sed -e "s/Keystone Daemons:\/var\/lib\/keystone:\/sbin\/nologin/Keystone Daemons:\/var\/lib\/keystone:\/bin\/bash/" -i /etc/passwd

#change connection URL
sed -e "s/keystone_admin:$_PASSWD/$_KEYSTONE_DB_USER/" -i /etc/keystone/keystone.conf

sudo mkdir /var/kerberos/krb5/user/$_KEYSTONE_EUID
sudo chown $_KEYSTONE_IPA_USER:$_KEYSTONE_IPA_USER /var/kerberos/krb5/user/$_KEYSTONE_EUID
sudo chmod 700 /var/kerberos/krb5/user/$_KEYSTONE_EUID
ipa-getkeytab -p $_KEYSTONE_IPA_USER@$_REALM -k /var/kerberos/krb5/user/$_KEYSTONE_EUID/client.keytab -s $_IPA
chcon -v --type=httpd_sys_content_t /var/kerberos/krb5/user/$_KEYSTONE_EUID/client.keytab
sudo chown $_KEYSTONE_IPA_USER:$_KEYSTONE_IPA_USER /var/kerberos/krb5/user/$_KEYSTONE_EUID/client.keytab
#sync db, nolonger needed if using mariadb-galera since we need to save original data from it
#keystone-manage db_sync
}

get_nova_keytab() {
_PASSWD=$1
_REALM=$2
_IPA=$3
_NOVA_IPA_USER=$4
_NOVA_EUID=$5
_NOVA_DB_USER=$6

sed -e "s/Nova Daemons:\/var\/lib\/nova:\/sbin\/nologin/Nova Daemons:\/var\/lib\/nova:\/bin\/bash/" -i /etc/passwd

#change connection URL
sed -e "s/nova:$_PASSWD/$_NOVA_DB_USER/" -i /etc/nova/nova.conf
#sed -e "s/nova:nova/$_NOVA_DB_USER/" -i /etc/nova/nova.conf
sed -e "/#connection=/a connection=mysql:\/\/$_NOVA_DB_USER@localhost\/nova" -i /etc/nova/nova.conf

sudo mkdir /var/kerberos/krb5/user/$_NOVA_EUID
sudo chown $_NOVA_IPA_USER:$_NOVA_IPA_USER /var/kerberos/krb5/user/$_NOVA_EUID
sudo chmod 700 /var/kerberos/krb5/user/$_NOVA_EUID
ipa-getkeytab -p $_NOVA_IPA_USER@$_REALM -k /var/kerberos/krb5/user/$_NOVA_EUID/client.keytab -s $_IPA
chcon -v --type=httpd_sys_content_t /var/kerberos/krb5/user/$_NOVA_EUID/client.keytab
sudo chown $_NOVA_IPA_USER:$_NOVA_IPA_USER /var/kerberos/krb5/user/$_NOVA_EUID/client.keytab
}


get_glance_keytab() {
_PASSWD=$1
_REALM=$2
_IPA=$3
_GLANCE_IPA_USER=$4
_GLANCE_EUID=$5
_GLANCE_DB_USER=$6

sed -e "s/Glance Daemons:\/var\/lib\/glance:\/sbin\/nologin/Glance Daemons:\/var\/lib\/glance:\/bin\/bash/" -i /etc/passwd

#change connection URL
sed -e "s/glance:$_PASSWD/$_GLANCE_DB_USER/" -i /etc/glance/glance-api.conf

sudo mkdir /var/kerberos/krb5/user/$_GLANCE_EUID
sudo chown $_GLANCE_IPA_USER:$_GLANCE_IPA_USER /var/kerberos/krb5/user/$_GLANCE_EUID

ipa-getkeytab -p $_GLANCE_IPA_USER@$_REALM -k /var/kerberos/krb5/user/$_GLANCE_EUID/client.keytab -s $_IPA
chcon -v --type=httpd_sys_content_t /var/kerberos/krb5/user/$_GLANCE_EUID/client.keytab
sudo chown $_GLANCE_IPA_USER:$_GLANCE_IPA_USER /var/kerberos/krb5/user/$_GLANCE_EUID/client.keytab
}

get_cinder_keytab() {
_PASSWD=$1
_REALM=$2
_IPA=$3
_CINDER_IPA_USER=$4
_CINDER_EUID=$5
_CINDER_DB_USER=$6

sed -e "s/Cinder Daemons:\/var\/lib\/cinder:\/sbin\/nologin/Cinder Daemons:\/var\/lib\/cinder:\/bin\/bash/" -i /etc/passwd

#change connection URL
sed -e "s/cinder:$_PASSWD/$_CINDER_DB_USER/" -i /etc/cinder/cinder.conf

sudo mkdir /var/kerberos/krb5/user/$_CINDER_EUID
sudo chown $_CINDER_IPA_USER:$_CINDER_IPA_USER /var/kerberos/krb5/user/$_CINDER_EUID
sudo chmod 700 /var/kerberos/krb5/user/$_CINDER_EUID
ipa-getkeytab -p $_CINDER_IPA_USER@$_REALM -k /var/kerberos/krb5/user/$_CINDER_EUID/client.keytab -s $_IPA
chcon -v --type=httpd_sys_content_t /var/kerberos/krb5/user/$_CINDER_EUID/client.keytab
sudo chown $_CINDER_IPA_USER:$_CINDER_IPA_USER /var/kerberos/krb5/user/$_CINDER_EUID/client.keytab
}
