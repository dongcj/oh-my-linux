######################################################################
# 作用: 安装 Dovecot
# 用法: Install_Dovecot
# 注意：
######################################################################
Install_Dovecot (){

  install_apt dovecot-common dovecot-pop3d dovecot-imapd
  setup_ssl dovecot

  sed -e 's|#unix_listener /var/spool/postfix/private/auth {|unix_listener /var/spool/postfix/private/auth {\n\tmode = 0666\n\t}|' \
      -i /etc/dovecot/conf.d/10-master.conf

  sed -e 's|^mail_location =.*|mail_location = maildir:~/Maildir/|' \
      -i /etc/dovecot/conf.d/10-mail.conf

  sed -e 's/^#ssl = yes/ssl = yes/' \
      -e 's/^#ssl_parameters_regenerate.*/ssl_parameters_regenerate = 0/' \
      -i /etc/dovecot/conf.d/10-ssl.conf

  sed -e 's/#pop3_uidl_format.*/pop3_uidl_format = %08Xu%08Xv/' \
      -i /etc/dovecot/conf.d/20-pop3.conf

  sed -e 's/#disable_plaintext_auth = yes/disable_plaintext_auth = no/' \
      -i /etc/dovecot/conf.d/10-auth.conf

debug "Set up Dovecot"
return 0
} 


######################################################################
# 作用: 安装 Postfix
# 用法: Install_Dovecot
# 注意：
######################################################################
Install_Postfix () {
    # more options for LAMP...
    install_apt libsasl2-modules-otp libsasl2-modules-ldap libsasl2-modules-sql libsasl2-modules-gssapi-mit  ca-certificates procmail postfix-mysql postfix-pgsql postfix-ldap postfix-pcre sasl2-bin postfix-cdb ufw  binutils openssl-blacklist procmail

# MTA configuration

    cat << EOC > /etc/postfix/main.cf
# Network/Connections
myhostname = ${HOSTNAME}.${DOMAIN_NAME}
myorigin = /etc/mailname
mydestination = ${HOSTNAME}.${DOMAIN_NAME}, localhost.localdomain, ${HOSTNAME}, localhost
relayhost =
mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128
inet_interfaces = all
default_destination_concurrency_limit = 2

# Databases
alias_maps = hash:/etc/aliases
alias_database = hash:/etc/aliases

# SASL / SMTP authentication
smtpd_sasl_auth_enable = yes
smtpd_sasl_authenticated_header = yes
smtpd_sasl_local_domain =
smtpd_sasl_path = private/auth
smtpd_sasl_type = dovecot
broken_sasl_auth_clients = yes

# TLS parameters
smtpd_tls_cert_file=/etc/ssl/certs/postfix.pem
smtpd_tls_key_file=/etc/ssl/private/postfix.key
smtpd_use_tls=yes
smtpd_tls_session_cache_database = btree:\${data_directory}/smtpd_scache
smtp_tls_session_cache_database = btree:\${data_directory}/smtp_scache

# Security/Relay
smtpd_delay_reject = yes
smtpd_helo_restrictions = reject_invalid_hostname
smtpd_sender_restrictions = reject_unknown_address
smtpd_recipient_restrictions = permit_mynetworks, permit_sasl_authenticated, reject_unauth_destination

# Mailbox/Message
home_mailbox = Maildir/
mailbox_command = procmail -a "\$EXTENSION"
mailbox_size_limit = 0
message_size_limit = 104857600
unknown_local_recipient_reject_code = 550
recipient_delimiter = +

# misc
biff = no
allow_percent_hack = no
append_at_myorigin = no
append_dot_mydomain = no
swap_bangpath = no
readme_directory = no
EOC


    # add default procmailrc
    cat << EOF > /etc/procmailrc
DEFAULT=\$HOME/Maildir/
VERBOSE=no
DROPPRIVS=yes

###############################################################################
# Procmail rules follows
EOF

    cat << EOC > /etc/postfix/master.cf
# Postfix master process configuration file.  For details on the format
# of the file, see the master(5) manual page (command: "man 5 master").
#
# Do not forget to execute "postfix reload" after editing this file.
#
# ==========================================================================
# service type  private unpriv  chroot  wakeup  maxproc command + args
#               (yes)   (yes)   (yes)   (never) (100)
# ==========================================================================
smtp      inet  n       -       -       -       -       smtpd
#2525      inet  n       -       n       -       -       smtpd -o smtpd_recipient_restrictions=\$smtpd_recipient_restrictions_mailfilter
submission inet n       -       -       -       -       smtpd
  -o smtpd_tls_security_level=encrypt
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_client_restrictions=permit_sasl_authenticated,reject
#  -o milter_macro_daemon_name=ORIGINATING
smtps     inet  n       -       -       -       -       smtpd
  -o smtpd_tls_wrappermode=yes
#  -o smtpd_sasl_auth_enable=yes
#  -o smtpd_client_restrictions=permit_sasl_authenticated,reject
#  -o milter_macro_daemon_name=ORIGINATING
#628      inet  n       -       -       -       -       qmqpd
pickup    fifo  n       -       -       60      1       pickup
cleanup   unix  n       -       -       -       0       cleanup
qmgr      fifo  n       -       n       300     1       qmgr
#qmgr     fifo  n       -       -       300     1       oqmgr
tlsmgr    unix  -       -       -       1000?   1       tlsmgr
rewrite   unix  -       -       -       -       -       trivial-rewrite
bounce    unix  -       -       -       -       0       bounce
defer     unix  -       -       -       -       0       bounce
trace     unix  -       -       -       -       0       bounce
verify    unix  -       -       -       -       1       verify
flush     unix  n       -       -       1000?   0       flush
proxymap  unix  -       -       n       -       -       proxymap
proxywrite unix -       -       n       -       1       proxymap
smtp      unix  -       -       -       -       -       smtp
# When relaying mail as backup MX, disable fallback_relay to avoid MX loops
relay     unix  -       -       -       -       -       smtp
        -o smtp_fallback_relay=
#       -o smtp_helo_timeout=5 -o smtp_connect_timeout=5
showq     unix  n       -       -       -       -       showq
error     unix  -       -       -       -       -       error
retry     unix  -       -       -       -       -       error
discard   unix  -       -       -       -       -       discard
local     unix  -       n       n       -       -       local
virtual   unix  -       n       n       -       -       virtual
lmtp      unix  -       -       -       -       -       lmtp
anvil     unix  -       -       -       -       1       anvil
scache    unix  -       -       -       -       1       scache
#
# ====================================================================
# Interfaces to non-Postfix software. Be sure to examine the manual
# pages of the non-Postfix software to find out what options it wants.
#
# Many of the following services use the Postfix pipe(8) delivery
# agent.  See the pipe(8) man page for information about \${recipient}
# and other message envelope options.
# ====================================================================
#
# maildrop. See the Postfix MAILDROP_README file for details.
# Also specify in main.cf: maildrop_destination_recipient_limit=1
#
maildrop  unix  -       n       n       -       -       pipe
  flags=DRhu user=vmail argv=/usr/bin/maildrop -d \${recipient}
#
# See the Postfix UUCP_README file for configuration details.
#
uucp      unix  -       n       n       -       -       pipe
  flags=Fqhu user=uucp argv=uux -r -n -z -a\$sender - \$nexthop!rmail (\$recipient)
#
# Other external delivery methods.
#
ifmail    unix  -       n       n       -       -       pipe
  flags=F user=ftn argv=/usr/lib/ifmail/ifmail -r \$nexthop (\$recipient)
bsmtp     unix  -       n       n       -       -       pipe
  flags=Fq. user=bsmtp argv=/usr/lib/bsmtp/bsmtp -t\$nexthop -f\$sender \$recipient
scalemail-backend unix  -       n       n       -       2       pipe
  flags=R user=scalemail argv=/usr/lib/scalemail/bin/scalemail-store \${nexthop} \${user} \${extension}
mailman   unix  -       n       n       -       -       pipe
  flags=FR user=list argv=/usr/lib/mailman/bin/postfix-to-mailman.py
  \${nexthop} \${user}
EOC

  setup_ssl postfix
  setup_dovecot
  debug "Set up Postfix on all interfaces"

echo 'dovecot   unix  -       n       n       -       -       pipe      flags=DRhu user=mailuser:mailuser argv=/usr/lib/dovecot/deliver -c /etc/dovecot/conf.d/01-mail-stack-delivery.conf -f ${sender} -d ${user}@${nexthop} -m ${extension}
smtps     inet  n       -       -       -       -       smtpd
submission inet n       -       -       -       -       smtpd' >> /etc/postfix/master.cf

  
return 0
} 








###############################################################
# Write new configurations for dovecot/postfix+mysql backend
###############################################################
cat << ___EOC___ > /etc/dovecot/dovecot-sql.conf
driver = mysql
connect = host=127.0.0.1 dbname=dovecot user=dovecot password=$(tail -n1 /root/tine20_password)

# Default password scheme.
default_pass_scheme = PLAIN-MD5

# passdb with userdb prefetch
password_query = SELECT dovecot_users.username AS user, password, home AS userdb_home, uid AS userdb_uid, gid AS userdb_gid, CONCAT('*:bytes=', CAST(quota_bytes AS CHAR), 'M') AS userdb_quota_rule FROM dovecot_users WHERE dovecot_users.username='%u'

# userdb for deliver
user_query = SELECT home, uid, gid, CONCAT('*:bytes=', CAST(quota_bytes AS CHAR), 'M') AS userdb_quota_rule FROM dovecot_users WHERE dovecot_users.username='%u'

___EOC___

cat << ___EOC___ > /etc/dovecot/conf.d/auth-sql.conf.ext
passdb {
  driver = sql
  args = /etc/dovecot/dovecot-sql.conf
}
userdb {
  driver = sql
  args = /etc/dovecot/dovecot-sql.conf
}
___EOC___

echo "!include auth-sql.conf.ext" >> /etc/dovecot/conf.d/10-auth.conf

cat << ___EOC___ > /etc/dovecot/dovecot-dict-sql.conf
connect = host=127.0.0.1 dbname=dovecot user=dovecot password=$(tail -n1 /root/tine20_password)
map {
  pattern = priv/quota/storage
  table = quota
  username_field = username
  value_field = bytes
}
map {
  pattern = priv/quota/messages
  table = quota
  username_field = username
  value_field = messages
}
___EOC___

cat << ___EOC___ > /etc/dovecot/conf.d/01-mail-stack-delivery.conf
   # Some general options
   protocols = imap pop3 lmtp
   disable_plaintext_auth = yes
   ssl = yes
   ssl_cert = /etc/ssl/certs/ssl-mail.pem
   ssl_key = /etc/ssl/private/ssl-mail.key
   ssl_cipher_list = ALL:!LOW:!SSLv2:ALL:!aNULL:!ADH:!eNULL:!EXP:RC4+RSA:+HIGH:+MEDIUM
   mail_location = maildir:~/Maildir
   auth_username_chars = abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890.-_@
   first_valid_uid = 100

   # IMAP configuration
   protocol imap {
           mail_max_userip_connections = 10
           imap_client_workarounds = delay-newmail
           mail_plugins = quota imap_quota
   }

   # POP3 configuration
   protocol pop3 {
           mail_max_userip_connections = 10
           pop3_client_workarounds = outlook-no-nuls oe-ns-eoh
           mail_plugins = quota
   }

   # LDA configuration
   protocol lda {
           postmaster_address = postmaster
           mail_plugins = sieve quota
           quota_full_tempfail = yes
           deliver_log_format = msgid=%m: %$
           rejection_reason = Your message to <%t> was automatically rejected:%n%r
   }

   # Plugins configuration
   plugin {
       sieve=~/.dovecot.sieve
       sieve_dir=~/sieve
       quota = dict:user::proxy::quotadict
   }

   dict {
       quotadict = mysql:/etc/dovecot/dovecot-dict-sql.conf
   }

___EOC___

mkdir /etc/dovecot/auth.d
cat << ___EOC___ > /etc/dovecot/auth.d/01-mail-stack-delivery.auth
   mechanisms = plain login
   socket listen {
       master {
         # Master socket provides access to userdb information. It's typically
         # used to give Dovecot's local delivery agent access to userdb so it
         # can find mailbox locations.
         path = /var/run/dovecot/auth-master
         mode = 0600
         # Default user/group is the one who started dovecot-auth (root)
         user = deliver
         #group =
       }
           client {
                   path = /var/spool/postfix/private/dovecot-auth
                   mode = 0660
                   user = postfix
                   group = postfix
           }
   }
___EOC___
cat << ___EOC___ > /etc/dovecot/conf.d/10-master.conf
service imap-login {
  inet_listener imap {
    #port = 143
  }
  inet_listener imaps {
    #port = 993
    #ssl = yes
  }
}

service pop3-login {
  inet_listener pop3 {
    #port = 110
  }
  inet_listener pop3s {
    #port = 995
    #ssl = yes
  }
}

service lmtp {
  unix_listener /var/spool/postfix/private/dovecot-lmtp {
    mode = 0666
    user = postfix
    group = postfix
  }
  #inet_listener lmtp {
    #address =
    #port =
  #}
}

service imap {
  #vsz_limit = 256M
  #process_limit = 1024
}
service pop3 {
  #process_limit = 1024
}
service auth {
  unix_listener auth-userdb {
    mode = 0600
    user = postfix
    group = postfix
  }
  # Postfix smtp-auth
  unix_listener /var/spool/postfix/private/auth {
    mode = 0666
  }
  # Auth process is run as this user.
  #user = \$default_internal_user
}
service auth-worker {
  #user = root
}
service dict {
  unix_listener dict {
    mode = 0600
    user = mailuser
    group = mailuser
  }
}
___EOC___

sed -i 's/!include auth-system.conf.ext/#!include auth-system.conf.ext/g' /etc/dovecot/conf.d/10-auth.conf

cat << ___EOC___ > /etc/postfix/main.cf
smtpd_banner = '${HOSTNAME}.${DOMAIN_NAME} ESMTP (Ubuntu)'
biff = no

# appending .domain is the MUA's job.
append_dot_mydomain = no

readme_directory = no

# TLS parameters
smtpd_tls_cert_file=/etc/ssl/certs/postfix.pem
smtpd_tls_key_file=/etc/ssl/private/postfix.key
smtpd_use_tls=yes
smtpd_tls_session_cache_database = btree:\${data_directory}/smtpd_scache
smtp_tls_session_cache_database = btree:\${data_directory}/smtp_scache

# See /usr/share/doc/postfix/TLS_README.gz in the postfix-doc package for
# information on enabling SSL in the smtp client.

myhostname = ${HOSTNAME}.${DOMAIN_NAME}
alias_maps = hash:/etc/aliases
alias_database = hash:/etc/aliases
myorigin = /etc/mailname
mydestination = localhost
relayhost =
mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128
mailbox_size_limit = 0
recipient_delimiter = +
inet_interfaces = all
#default_transport = error
#relay_transport = error
home_mailbox = Maildir/
smtpd_sasl_auth_enable = yes
smtpd_sasl_type = dovecot
smtpd_sasl_path = private/auth
smtpd_sasl_authenticated_header = yes
smtpd_sasl_security_options = noanonymous
smtpd_sasl_local_domain = $myhostname
broken_sasl_auth_clients = yes
smtpd_recipient_restrictions = reject_unknown_sender_domain, reject_unknown_recipient_domain, reject_unauth_pipelining, permit_mynetworks, permit_sasl_authenticated, reject_unauth_destination
smtpd_sender_restrictions = reject_unknown_sender_domain
mailbox_command = /usr/lib/dovecot/deliver -c /etc/dovecot/conf.d/01-mail-stack-delivery.conf -m "\${EXTENSION}"
smtp_use_tls = yes
smtpd_tls_received_header = yes
smtpd_tls_mandatory_protocols = SSLv3, TLSv1
smtpd_tls_mandatory_ciphers = medium
smtpd_tls_auth_only = yes
tls_random_source = dev:/dev/urandom

virtual_transport = lmtp:unix:private/dovecot-lmtp

virtual_mailbox_domains = mysql:/etc/postfix/sql/sql-virtual_mailbox_domains.cf
virtual_mailbox_maps = mysql:/etc/postfix/sql/sql-virtual_mailbox_maps.cf
virtual_alias_maps = mysql:/etc/postfix/sql/sql-virtual_alias_maps_aliases.cf

___EOC___

mkdir /etc/postfix/sql

cat << ___EOC___ > /etc/postfix/sql/sql-virtual_alias_maps_aliases.cf
user     = postfix
password = $(tail -n1 /root/tine20_password)
hosts    = 127.0.0.1
dbname   = postfix
query    = SELECT destination FROM smtp_destinations WHERE source='%s'
___EOC___

cat << ___EOC___ > /etc/postfix/sql/sql-virtual_mailbox_domains.cf
user     = postfix
password = $(tail -n1 /root/tine20_password)
hosts    = 127.0.0.1
dbname   = postfix
query    = SELECT DISTINCT 1 FROM smtp_destinations WHERE SUBSTRING_INDEX(source, '@', -1) = '%s';
___EOC___

cat << ___EOC___ > /etc/postfix/sql/sql-virtual_mailbox_maps.cf
user     = postfix
password = $(tail -n1 /root/tine20_password)
hosts    = 127.0.0.1
dbname   = postfix
query    = SELECT 1 FROM smtp_users WHERE username='%s' AND forward_only=0
___EOC___

echo "root: admin@${HOSTNAME}.${DOMAIN_NAME}" >> /etc/aliases
newaliases

return 0
} 


######################################################################
# 作用: 安装 Dovecot
# 用法: Install_Dovecot
# 注意：
######################################################################

Install_MysqlServer ()
{
  sudo debconf-set-selections <<< 'mysql-server-5.1 mysql-server/root_password password '"${PLAIN_ROOT_PW}"''
  sudo debconf-set-selections <<< 'mysql-server-5.1 mysql-server/root_password_again password '"${PLAIN_ROOT_PW}"''
  install_apt mysql-server

return 0
}

######################################################################
# 作用: 安装 Dovecot
# 用法: Install_Dovecot
# 注意：
######################################################################

Install_Vsftpd ()
{
  install_apt vsftpd libcap2
  if [ -e /etc/vsftpd.conf ]; then
    sed -i 's/anonymous_enable=YES/anonymous_enable=NO/g' /etc/vsftpd.conf
    sed -i 's/^#xferlog_file=\/var\/log\/vsftpd.log/xferlog_file=\/var\/log\/vsftpd.log/g' /etc/vsftpd.conf
    sed -i 's/^#local_enable=YES/local_enable=YES/g' /etc/vsftpd.conf
    sed -i 's/^#chroot_local_user=YES/chroot_local_user=YES/g' /etc/vsftpd.conf
    sed -i 's/^#write_enable=YES/write_enable=YES/g' /etc/vsftpd.conf
  fi
debug "Set up vsftpd"
return 0
} 

######################################################################
# 作用: 安装 Dovecot
# 用法: Install_Dovecot
# 注意：
######################################################################

setup_php5 ()
{
  install_apt libapache2-mod-php7.0 php7.0 php7.0-mysql php7.0-gd
  #safe_mode and register_globals have been removed from php 5.5

debug "Set up php5"
return 0
} # ----------  end of function setup_php5  ----------


######################################################################
# 作用: 安装 Dovecot
# 用法: Install_Dovecot
# 注意：
######################################################################
setup_apache2 ()
{
  install_apt apache2 libapache2-mpm-itk apache2-utils apache2-data libapr1 libaprutil1 libaprutil1-dbd-sqlite3 libaprutil1-ldap
  MODS_ENABLE="rewrite ssl"
  PORTS_ENABLE="80 443"
  for ENTRY in $MODS_ENABLE; do
    /usr/sbin/a2enmod $ENTRY &> /dev/null
  done
  echo "" > /etc/apache2/ports.conf
  for PORT in $PORTS_ENABLE; do
    echo "Listen $PORT" >> /etc/apache2/ports.conf
  done
  /usr/sbin/a2ensite default-ssl

debug "Set up apache2 with SSL-Support and mpm-worker"
return 0
}






setup_wordpress ()
{
debug "Start Wordpress Application"

debug "Install package dependencies"
debconf-set-selections <<< "mysql-server mysql-server/root_password password ${PLAIN_ROOT_PW}"
debconf-set-selections <<< "mysql-server mysql-server/root_password_again password ${PLAIN_ROOT_PW}"
install_apt mysql-server pwgen zip
setup_apache2
setup_php5
setup_vsftpd
a2enmod rewrite > /dev/null && a2enmod vhost_alias > /dev/null

debug "configure apache"
cat > /etc/apache2/sites-enabled/000-default.conf << EOF
<VirtualHost *:80>
        ServerAdmin root@${HOSTNAME}.${DOMAIN_NAME}
        DocumentRoot /var/www/wordpress
        <Directory />
                Options FollowSymLinks
                AllowOverride None
        </Directory>
        <Directory /var/www/wordpress/>
                Options Indexes FollowSymLinks MultiViews
                AllowOverride All
                Order allow,deny
                allow from all
        </Directory>
        ScriptAlias /cgi-bin/ /usr/lib/cgi-bin/
        <Directory "/usr/lib/cgi-bin">
                AllowOverride None
                Options +ExecCGI -MultiViews +SymLinksIfOwnerMatch
                Order allow,deny
                Allow from all
        </Directory>
        ErrorLog /var/log/apache2/error.log
        # Possible values include: debug, info, notice, warn, error, crit,
        # alert, emerg.
        LogLevel warn
        CustomLog /var/log/apache2/access.log combined
</VirtualHost>
EOF

cat > /etc/apache2/sites-enabled/default-ssl.conf << EOF
<IfModule mod_ssl.c>
<VirtualHost _default_:443>
        ServerAdmin root@${HOSTNAME}.${DOMAIN_NAME}
        DocumentRoot /var/www/wordpress
        <Directory />
                Options FollowSymLinks
                AllowOverride None
        </Directory>
        <Directory /var/www/wordpress/>
                Options Indexes FollowSymLinks MultiViews
                AllowOverride All
                Order allow,deny
                allow from all
        </Directory>
        ScriptAlias /cgi-bin/ /usr/lib/cgi-bin/
        <Directory "/usr/lib/cgi-bin">
                AllowOverride None
                Options +ExecCGI -MultiViews +SymLinksIfOwnerMatch
                Order allow,deny
                Allow from all
        </Directory>
        ErrorLog /var/log/apache2/error.log
        LogLevel warn
        CustomLog /var/log/apache2/ssl_access.log combined
        SSLEngine on
        SSLCertificateFile    /etc/ssl/certs/ssl-cert-snakeoil.pem
        SSLCertificateKeyFile /etc/ssl/private/ssl-cert-snakeoil.key
        <FilesMatch "\.(cgi|shtml|phtml|php)$">
                SSLOptions +StdEnvVars
        </FilesMatch>
        <Directory /usr/lib/cgi-bin>
                SSLOptions +StdEnvVars
        </Directory>
        BrowserMatch "MSIE [2-6]" \
                nokeepalive ssl-unclean-shutdown \
                downgrade-1.0 force-response-1.0
        BrowserMatch "MSIE [17-9]" ssl-unclean-shutdown
</VirtualHost>
</IfModule>
EOF

debug "Check install language"
if [[ $LANGID == 0407 ]]
then
  debug "Install German WP"
  WPLANG="de_DE"
  wget -q https://downloads.wordpress.org/release/de_DE/latest.tar.gz -O /tmp/latest.tar.gz
else
  debug "Install English WP"
  WPLANG="en_US"
  wget -q http://wordpress.org/latest.tar.gz -O /tmp/latest.tar.gz
fi
tar xfz /tmp/latest.tar.gz -C /var/www/
chown -R www-data:www-data /var/www/

debug "Configure Wordpress"
DBNAME='wordpress'
DBPASSWD=$(pwgen -N 1 -n 24)
SECRETKEY=$(pwgen -N 1 -n 50)

cat > /var/www/wordpress/wp-config.php << EOF
<?php
define('DB_NAME', '$DBNAME');
define('DB_USER', '$DBNAME');
define('DB_PASSWORD', '$DBPASSWD');
define('DB_HOST', 'localhost');
define('DB_CHARSET', 'utf8');
define('DB_COLLATE', '');
\$table_prefix  = 'wp_';
define('SECRET_KEY', '$SECRETKEY');
define('WPLANG', '$WPLANG');
define('WP_CORE_UPDATE', false);
define('WP_DEBUG', false);
define('FS_METHOD', 'direct');
if ( !defined('ABSPATH') )
  define('ABSPATH', dirname(__FILE__) . '/');
  require_once(ABSPATH . 'wp-settings.php');
?>
EOF

chown www-data:www-data /var/www/wordpress/wp-config.php

cat << EOC > /usr/local/bin/setup_wordpress.sh
#!/bin/bash -x
mysql --defaults-extra-file=/etc/mysql/debian.cnf << EOF
echo "Configure DB"
CREATE DATABASE $DBNAME;
GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,DROP,ALTER
ON $DBNAME.*
TO $DBNAME@localhost
IDENTIFIED BY '$DBPASSWD';
FLUSH PRIVILEGES;
EOF
echo "Setup wordpress"
curl --data "weblog_title=Default Blog&user_name=admin&admin_password=${ADMIN_PW}&admin_password2=${ADMIN_PW}&admin_email=root@${HOSTNAME}.${DOMAIN_NAME}&blog_public=1&Submit=Install WordPress" "http://${HOSTNAME}.${DOMAIN_NAME}/wp-admin/install.php?step=2"


curl -L "http://${INSTALLER_IP-"install.intergenia.de:81"}/response.php?action=setprogress&percent=100&comment=Finished%20Wordpress-Installation"


#rm /usr/local/bin/setup_wordpress.sh
exit 0

EOC

chmod +x /usr/local/bin/setup_wordpress.sh
cat << EOC > /etc/rc.local
#!/bin/bash
/usr/local/bin/setup_wordpress.sh > /var/log/wordpress.log
EOC

return 0
}






setup_owncloud5 ()
{

setup_apache2

BASE_PATH="/var/www/owncloud"
echo 'deb http://download.opensuse.org/repositories/isv:/ownCloud:/community/xUbuntu_14.04/ /' >> /etc/apt/sources.list.d/owncloud.list
wget http://download.opensuse.org/repositories/isv:ownCloud:community/xUbuntu_14.04/Release.key
apt-key add - < Release.key && rm Release.key
apt-get -qq update &>/dev/null
install_apt owncloud sqlite3 clamav

cat << __EOF__ > ${BASE_PATH}/config/autoconfig.php
<?php
\$AUTOCONFIG = array(
    "dbtype" => 'sqlite',
    "directory" => "/var/www/owncloud/data",
    "adminlogin" => "admin",
    "adminpass" => "${PLAIN_ROOT_PW}"
);
?>
__EOF__

sed -i 's/post_max_size.*$/post_max_size = 513M/g' /etc/php5/apache2/php.ini
sed -i 's/upload_max_filesize.*$/upload_max_filesize = 513M/g' /etc/php5/apache2/php.ini
chown www-data:www-data ${BASE_PATH}/config/autoconfig.php
service apache2 restart

if ! type curl
then
  install_apt curl
fi

if curl http://${HOSTNAME}.${DOMAIN_NAME}/owncloud/index.php &> /dev/null
then
  debug "Successfully installed and configured ownCloud"
else
  debug "Error while configuring ownCloud - try browsing http://${HOSTNAME}.${DOMAIN_NAME}/owncloud/index.php manually"
fi

# configure language if not english
if [[ $LANGID == 0407 ]]
then
  sqlite3 ${BASE_PATH}/data/owncloud.db << __EOF__
INSERT INTO "oc_preferences" VALUES('admin','core','lang','de_DE');
__EOF__
elif [[ $LANGID == 040c ]]
then
  sqlite3 ${BASE_PATH}/data/owncloud.db << __EOF__
INSERT INTO "oc_preferences" VALUES('admin','core','lang','fr');
__EOF__
fi


# configure clamav
VERSION=$(cat ${BASE_PATH}/apps/files_antivirus/appinfo/version)
if [[ -n $VERSION ]]
then
  sqlite3 ${BASE_PATH}/data/owncloud.db << __EOF__
INSERT INTO "oc_appconfig" VALUES('files_antivirus','installed_version','${VERSION}');
INSERT INTO "oc_appconfig" VALUES('files_antivirus','types','filesystem');
INSERT INTO "oc_appconfig" VALUES('files_antivirus','enabled','yes');
__EOF__
fi

sqlite3 ${BASE_PATH}/data/owncloud.db << __EOF__
INSERT INTO "oc_preferences" VALUES('admin','settings','email','root@${HOSTNAME}.${DOMAIN_NAME}');
__EOF__

cat << __EOF__ > /etc/apache2/sites-available/000-default.conf
<VirtualHost *:80>
  ServerAdmin webmaster@${HOSTNAME}.${DOMAIN_NAME}

  DocumentRoot /var/www
  <Directory />
    Options FollowSymLinks
    AllowOverride None
  </Directory>
  <Directory /var/www/>
    Options Indexes FollowSymLinks MultiViews
    AllowOverride None
    Order allow,deny
    allow from all
  </Directory>

  # Possible values include: debug, info, notice, warn, error, crit,
  # alert, emerg.
  LogLevel warn

  CustomLog \${APACHE_LOG_DIR}/access.log combined
  ErrorLog \${APACHE_LOG_DIR}/error.log

  RewriteEngine On
  RewriteRule ^(.*)$  /owncloud/\$1
</VirtualHost>
__EOF__

cat << __EOF__ > /etc/apache2/sites-available/default-ssl.conf
<IfModule mod_ssl.c>
<VirtualHost _default_:443>
  ServerAdmin webmaster@localhost

  DocumentRoot /var/www
  <Directory />
    Options FollowSymLinks
    AllowOverride None
  </Directory>
  <Directory /var/www/>
    Options Indexes FollowSymLinks MultiViews
    AllowOverride None
    Order allow,deny
    allow from all
  </Directory>


  # Possible values include: debug, info, notice, warn, error, crit,
  # alert, emerg.
  LogLevel warn

  CustomLog \${APACHE_LOG_DIR}/ssl_access.log combined
  ErrorLog \${APACHE_LOG_DIR}/error.log

  #   SSL Engine Switch:
  #   Enable/Disable SSL for this virtual host.
  SSLEngine on

  #   A self-signed (snakeoil) certificate can be created by installing
  #   the ssl-cert package. See
  #   /usr/share/doc/apache2.2-common/README.Debian.gz for more info.
  #   If both key and certificate are stored in the same file, only the
  #   SSLCertificateFile directive is needed.
  SSLCertificateFile    /etc/ssl/certs/ssl-cert-snakeoil.pem
  SSLCertificateKeyFile /etc/ssl/private/ssl-cert-snakeoil.key

  <FilesMatch "\.(cgi|shtml|phtml|php)$">
    SSLOptions +StdEnvVars
  </FilesMatch>
  <Directory /usr/lib/cgi-bin>
    SSLOptions +StdEnvVars
  </Directory>

  BrowserMatch "MSIE [2-6]" \
    nokeepalive ssl-unclean-shutdown \
    downgrade-1.0 force-response-1.0
  # MSIE 7 and newer should be able to use keepalive
  BrowserMatch "MSIE [17-9]" ssl-unclean-shutdown
  RewriteEngine On
  RewriteRule ^(.*)$  /owncloud/\$1
</VirtualHost>
</IfModule>
__EOF__

  curl -L "http://${INSTALLER_IP-"install.intergenia.de:81"}/response.php?action=setprogress&percent=100&comment=Finished%OwnCloud-Installation"

return 0
}