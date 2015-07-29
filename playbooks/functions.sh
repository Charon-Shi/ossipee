#!/bin/bash
# must run under sudo
# must have ipa-client running

sync_ntp() {
_IPA=$1
ntpdate -u $_IPA
}

remove_mariadb() {
yum remove -y mariadb-server mariadb
}

remove_all() {
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
_DB_USER=$4
_IPA_USER=$5

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
CREATE USER $_DB_USER IDENTIFIED VIA kerberos AS '$_IPA_USER@$_REALM';
GRANT ALL PRIVILEGES ON keystone.* to $_DB_USER@'%';
EOF

service mariadb stop
cd /etc/my.cnf.d/
#sed -i "/\[server\]/a kerberos_principal_name=MySQL\/$_DB@$_REALM\nkerberos_keytab_path=/var/lib/mysql/mysql.keytab"  server.cnf
echo "[server]" >> server.cnf
echo "kerberos_principal_name=MySQL/$_DB@$_REALM" >> server.cnf
echo "kerberos_keytab_path=/var/lib/mysql/mysql.keytab" >> server.cnf
service mariadb start
}

get_keytab() {
_PASSWD=$1
_REALM=$2
_IPA=$3
_IPA_USER=$4
_EUID=$5
_DB_USER=$6

#comment out the keystone line in /etc/passwd
#sed -e '/keystone*/ s/^#*/#/' -i /etc/passwd
#change connection URL
sed -e "s/keystone_admin:$_PASSWD/$_DB_USER/" -i /etc/keystone/keystone.conf

sudo mkdir /var/kerberos/krb5/user/$_EUID
sudo chown keystone:keystone /var/kerberos/krb5/user/$_EUID
sudo chmod 700 /var/kerberos/krb5/user/$_EUID
ipa-getkeytab -p $_IPA_USER@$_REALM -k /var/kerberos/krb5/user/$_EUID/client.keytab -s $_IPA
chcon -v --type=httpd_sys_content_t /var/kerberos/krb5/user/$_EUID/client.keytab
sudo chown keystone:keystone /var/kerberos/krb5/user/$_EUID/client.keytab
#sync db
#keystone-manage db_sync
}



