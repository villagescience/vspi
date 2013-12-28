#!/bin/bash

########################################################################
##
##   VS-Pi Install Script
##   ====================
##   This shell script installs and configures the software
##   and dependencies to run the VS-Pi Wordpress on Raspbian.
##
##   Visit http://github.com/villagescience for more information.
##
##   Originally from https://github.com/lowendbox/lowendscript
##   Modified by Nick Wynja on 2013-10-07 under GPLv3
##
########################################################################


##
## HELPER FUNCTIONS
##

function check_install {
    if [ -z "`which "$1" 2>/dev/null`" ]
    then
        executable=$1
        shift
        while [ -n "$1" ]
        do
            DEBIAN_FRONTEND=noninteractive apt-get -qq -y install "$1"
            print_info "$1 installed for $executable"
            shift
        done
    else
        print_warn "$2 already installed"
    fi
}

function check_remove {
    if [ -n "`which "$1" 2>/dev/null`" ]
    then
        DEBIAN_FRONTEND=noninteractive apt-get -q -y remove --purge "$2"
        print_info "$2 removed"
    else
        print_warn "$2 is not installed"
    fi
}

function check_sanity {
    # Do some sanity checking.
    if [ $(/usr/bin/id -u) != "0" ]
    then
        die 'Must be run by root user'
    fi

    if [ ! -f /etc/debian_version ]
    then
        die "Distribution is not supported"
    fi
}

function die {
    echo "ERROR: $1" > /dev/null 1>&2
    exit 1
}

function get_domain_name() {
    # Getting rid of the lowest part.
    domain=${1%.*}
    lowest=`expr "$domain" : '.*\.\([a-z][a-z]*\)'`
    case "$lowest" in
    com|net|org|gov|edu|co)
        domain=${domain%.*}
        ;;
    esac
    lowest=`expr "$domain" : '.*\.\([a-z][a-z]*\)'`
    [ -z "$lowest" ] && echo "$domain" || echo "$lowest"
}

function get_password() {
    # Check whether our local salt is present.
    SALT=/var/lib/radom_salt
    if [ ! -f "$SALT" ]
    then
        head -c 512 /dev/urandom > "$SALT"
        chmod 400 "$SALT"
    fi
    password=`(cat "$SALT"; echo $1) | md5sum | base64`
    echo ${password:0:13}
}

function print_info {
    echo -n -e '\e[1;36m'
    echo -n $1
    echo -e '\e[0m'
}

function print_warn {
    echo -n -e '\e[1;33m'
    echo -n $1
    echo -e '\e[0m'
}

function update_upgrade {
    # Run through the apt-get update/upgrade first. This should be done before
    # we try to install any package
    print_info "Updating packages"
    apt-get -qq -y update
    apt-get -qq -y upgrade
}

function remove_unneeded {
    # Some Debian have portmap installed. We don't need that.
    check_remove /sbin/portmap portmap

    # Remove rsyslogd, which allocates ~30MB privvmpages on an OpenVZ system,
    # which might make some low-end VPS inoperatable. We will do this even
    # before running apt-get update.
    check_remove /usr/sbin/rsyslogd rsyslog

    # Other packages that seem to be pretty common in standard OpenVZ
    # templates.
    check_remove /usr/sbin/apache2 'apache2*'
    check_remove /usr/sbin/named bind9
    check_remove /usr/sbin/smbd 'samba*'
    check_remove /usr/sbin/nscd nscd

    # Need to stop sendmail as removing the package does not seem to stop it.
    if [ -f /usr/lib/sm.bin/smtpd ]
    then
        invoke-rc.d sendmail stop
        check_remove /usr/lib/sm.bin/smtpd 'sendmail*'
    fi
}


##
## INSTALL AND CONFIGURE
##


function install_vspi {
  print_info "Installing and configuring VS-Pi"
  sudo mv vspi /etc/vspi
  sudo chmod a+x /etc/vspi/vspi
  sudo ln -s /etc/vspi/vspi /usr/local/bin/
  sudo chmod -R 777 /etc/vspi
  echo -e "1.0" > /etc/vspi/version
  sudo chmod 777 /etc/vspi/version
}

function install_mysql {
    # Install the MySQL packages

    sudo debconf-set-selections <<< 'mysql-server-5.5 mysql-server/root_password password raspberry'
    sudo debconf-set-selections <<< 'mysql-server-5.5 mysql-server/root_password_again password raspberry'
    check_install mysqld mysql-server-5.5

    # Install a low-end copy of the my.cnf to disable InnoDB, and then delete
    # all the related files.

    mkdir -p /etc/mysql/conf.d/
    echo -e "[mysqld] \
      key_buffer = 8M \
      query_cache_size = 0 \
      skip-innodb" > /etc/mysql/conf.d/lowendbox.cnf

    echo -e "[client] \n user = root \n password = raspberry" > ~/.my.cnf
    chmod 600 ~/.my.cnf
}

function install_nginx {
    check_install nginx nginx

    # Need to increase the bucket size for Debian 5.
    cat > /etc/nginx/conf.d/lowendbox.conf <<END
server_names_hash_bucket_size 64;
END

    invoke-rc.d nginx restart
}

function install_php {
    sudo apt-get -y -qq install php5 php5-fpm php-pear php5-mysql
}

function install_syslogd {
    # We just need a simple vanilla syslogd. Also there is no need to log to
    # so many files (waste of fd). Just dump them into
    # /var/log/(cron/mail/messages)
    check_install /usr/sbin/syslogd inetutils-syslogd
    invoke-rc.d inetutils-syslogd stop

    for file in /var/log/*.log /var/log/mail.* /var/log/debug /var/log/syslog
    do
        [ -f "$file" ] && rm -f "$file"
    done
    for dir in fsck news
    do
        [ -d "/var/log/$dir" ] && rm -rf "/var/log/$dir"
    done

    cat > /etc/syslog.conf <<END
*.*;mail.none;cron.none -/var/log/messages
cron.*                  -/var/log/cron
mail.*                  -/var/log/mail
END

    [ -d /etc/logrotate.d ] || mkdir -p /etc/logrotate.d
    cat > /etc/logrotate.d/inetutils-syslogd <<END
/var/log/cron
/var/log/mail
/var/log/messages {
   rotate 4
   weekly
   missingok
   notifempty
   compress
   sharedscripts
   postrotate
      /etc/init.d/inetutils-syslogd reload >/dev/null
   endscript
}
END

    invoke-rc.d inetutils-syslogd start
}

function install_redis {
    #redis is used to cache Wordpress pages to speed up response time
    sudo apt-get -qq -y install redis-server
}

function install_fonts {
    sudo apt-get -qq -y install fonts-lao
}

function install_wordpress {
    check_install wget wget

    sudo git clone https://github.com/villagescience/wordpress.git /var/www/$1
    sudo chown root:root -R "/var/www/$1"
    sudo chmod 777 -R "/var/www/$1/wp-content"
    sudo chmod 666 "/var/www/$1/.htaccess"
    sudo chmod 666 "/var/www/$1/wp-config.php"

    # Setting up the MySQL database
    dbname=`echo $1 | tr . _`
    userid=`get_domain_name $1`
    # MySQL userid cannot be more than 15 characters long
    userid="${userid:0:15}"
    passwd=`get_password "$userid@mysql"`
    sed -i "s/database_name_here/$dbname/; s/username_here/$userid/; s/password_here/$passwd/" \
        "/var/www/$1/wp-config.php"
    mysqladmin create "$dbname"
    echo "GRANT ALL PRIVILEGES ON \`$dbname\`.* TO \`$userid\`@localhost IDENTIFIED BY '$passwd';" | \
        mysql

    rm -r /etc/nginx/sites-available/default

    # Setting up Nginx mapping
    cat > "/etc/nginx/sites-enabled/$1.conf" <<END
server {
    listen       80 default_server;
    server_name  vspi.local;
    root         /var/www/$1;

    location /index.php {
        alias /var/www/$1/wp-index-redis.php;
    }

    location / {
        index wp-index-redis.php;
        try_files \$uri \$uri/ /wp-index-redis.php?\$args;
    }

    location /wp-admin/ {
        index index.php;
        try_files \$uri \$uri/ /index.php\$args;
    }

    # Add trailing slash to /wp-admin requests
    rewrite /wp-admin\$ \$scheme::/\$host\$uri/ permanent;

    gzip off;

    # Directives to send expires headers and turn off 404 error logging.
    location ~* \.(js|css|png|jpg|jpeg|gif|ico)$ {
        expires 24h;
        log_not_found off;
    }

    # this prevents hidden files (beginning with a period) from being served
          location ~ /\.          { access_log off; log_not_found off; deny all; }

    location ~ \.php$ {
        client_max_body_size 25M;
        try_files      \$uri =404;
        fastcgi_pass   unix:/var/run/php5-fpm.sock;
        fastcgi_index  index.php;
        include        /etc/nginx/fastcgi_params;
    }
}
END
    invoke-rc.d nginx reload
    curl -d "weblog_title=VSPi&user_name=admin&admin_password=raspberry&admin_password2=raspberry&admin_email=vspi@villagescience.org" http://127.0.0.1/wp-admin/install.php?step=2 >/dev/null 2>&1
}

function config_network {
    print_info "Installing network packages"
    sudo apt-get -qq -y install bridge-utils hostapd avahi-daemon udhcpd dnsmasq

    print_info "Configuring network setup"
    wget http://www.daveconroy.com/wp3/wp-content/uploads/2013/07/hostapd.zip
    unzip hostapd.zip
    sudo rm  /usr/sbin/hostapd
    sudo mv hostapd /usr/sbin/hostapd.edimax
    sudo ln -sf /usr/sbin/hostapd.edimax /usr/sbin/hostapd
    sudo chown root.root /usr/sbin/hostapd
    sudo chmod 755 /usr/sbin/hostapd

    cat > "/etc/network/interfaces" <<END
auto lo

iface lo inet loopback
iface eth0 inet dhcp

iface wlan0 inet static
address 10.0.10.1
netmask 255.255.255.0

up iptables-restore < /etc/iptables.ipv4.nat
END

    cat > "/etc/hostapd/hostapd.conf" <<END
# Open network setup

interface=wlan0
driver=rtl871xdrv
ssid=VS-Pi Connect

#sets the mode of wifi, depends upon the devices you will be using. It can be a,b,g,n. Setting to g ensures backward compatiblity.
hw_mode=g

# Set the wi-fi channel:
channel=6

#Sets authentication algorithm
#1 - only open system authentication
auth_algs=1

wmm_enabled=0
END

    cat > "/etc/udhcpd.conf" <<END
start		10.0.10.10
end		10.0.10.200
interface	wlan0
remaining	yes
opt	dns	8.8.8.8 8.8.4.4 # Google Public DNS servers
option	subnet	255.255.255.0
opt	router	10.0.10.1
option	domain	local
option	lease	864000
END

    # configure ip forwading/masquerade from wlan clients to the upstream eth0
    # network, so the vspi serves as a wireless router, i.e. clients can
    # connect to the outside internet as well as the vspi pages.
    cat > "/etc/iptables.ipv4.nat" <<END
*filter
:INPUT ACCEPT [149:13529]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [22:2208]
-A FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -i wlan0 -o eth0 -j ACCEPT
COMMIT
*nat
:PREROUTING ACCEPT [75:5274]
:INPUT ACCEPT [75:5274]
:OUTPUT ACCEPT [3:268]
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -o eth0 -j MASQUERADE
COMMIT
END

    # for the above to work, we need to enable ipv4 forwarding in the kernel
    echo "# allow vspi to act as a router" >> /etc/sysctl.conf
    echo "net.ipv4.ip_forward=1"           >> /etc/sysctl.conf

    sudo rm /etc/dnsmasq.conf
    cat > "/etc/dnsmasq.conf" <<END
interface=wlan0
dhcp-range=10.0.10.10,10.0.10.200,12h
END

  sudo rm /etc/default/udhcpd
  echo -e "DHCPD_OPTS='-S'" > /etc/default/udhcpd
  sudo update-rc.d udhcpd enable
  echo -e "DAEMON_CONF='/etc/hostapd/hostapd.conf'" >> /etc/default/hostapd
  sudo update-rc.d hostapd enable

echo -e "vspi" > /etc/hostname
echo -e "127.0.0.1    vspi" > /etc/hosts
sudo /etc/init.d/hostname.sh

}

########################################################################
# START OF PROGRAM
########################################################################
export PATH=/bin:/usr/bin:/sbin:/usr/sbin

check_sanity
update_upgrade
install_vspi
install_mysql
install_nginx
install_php
remove_unneeded
install_syslogd
install_redis
install_fonts
install_wordpress vspi.local
config_network
sudo reboot
