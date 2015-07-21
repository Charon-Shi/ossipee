#!/bin/bash
# must run under sudo
# must have ipa-client running

IPA=$1
REALM=$2
DB=$3
PASSWD=$4
DB_USER=keystone
IPA_USER=keystone
LOCAL_IP=$5

#uninstall mariadb and ipa-client
ntpdate -u $IPA
yum remove -y mariadb-server mariadb
echo "$PASSWD" | kinit admin

yum install -y ipa-admintools

cd /etc/yum.repos.d/
wget https://copr.fedoraproject.org/coprs/rharwood/mariadb/repo/epel-7/rharwood-mariadb-epel-7.repo

yum install -y epel-release
yum update -y
yum install -y  mariadb{,-debuginfo,-devel,-libs,-server}
ipa service-add MySQL/$(hostname -f)

cd /var/lib/mysql
ipa-getkeytab -s $IPA -p MySQL/$(hostname -f)@$REALM -k mysql.keytab
chown mysql:mysql mysql.keytab
chmod 660 /var/lib/mysql/mysql.keytab

service mariadb start
mysql -u root << EOF
install plugin kerberos soname 'kerberos';
CREATE USER $DB_USER IDENTIFIED VIA kerberos AS '$IPA_USER@$REALM';
GRANT ALL PRIVILEGES ON keystone.* to '$DB_USER'@"$LOCAL_IP";
EOF

service mariadb stop
cd /etc/my.cnf.d/
sed -i "/\[server\]/a kerberos_principal_name=MySQL\/$DB@$REALM\nkerberos_keytab_path=/var/lib/mysql/mysql.keytab"  server.cnf

service mariadb start

#comment out the keystone line in /etc/passwd
sed -e '/keystone*/ s/^#*/#/' -i /etc/passwd
#change connection URL
sed -e "s/keystone_admin:$PASSWD/keystone/" -i /etc/keystone/keystone.conf

#TODO 163 is EUID for keystone user in IPA, maybe it should be parameterized
sudo mkdir /var/kerberos/krb5/user/163
sudo chown keystone:keystone /var/kerberos/krb5/user/163
sudo chmod 700 /var/kerberos/krb5/user/163
ipa-getkeytab -p $IPA_USER@$REALM -k /var/kerberos/krb5/user/163/client.keytab -s $IPA
chcon -v --type=httpd_sys_content_t /var/kerberos/krb5/user/163/client.keytab
sudo chown keystone:keystone /var/kerberos/krb5/user/163/client.keytab

#sync db
keystone-manage db_sync

#create keystone.rc
touch /home/keystone.rc
echo "export OS_AUTH_URL=http://$LOCAL_IP:5000/v2.0/" >> /home/keystone.rc
echo 'export OS_USERNAME=admin' >> /home/keystone.rc
echo "export OS_PASSWORD=$PASSWD" >> /home/keystone.rc
Gme: execute script
  #- command: sh /home/mariadb_setup.sh ipa.testscl TESTSCL rdo.testscl {{ ipa_admin_user_password }}
RANT ALL PRIVILEGES ON keystone.* to '$DB_USER'@'127.0.0.1';
echo 'export OS_USER_DOMAIN_NAME=Default' >> /home/keystone.rc
echo 'export OS_PROJECT_DOMAIN_NAME=Default' >> /home/keystone.rc
echo 'export OS_PROJECT_NAME=IdM' >> /home/keystone.rc
