#!/bin/bash
function HELP {
    echo "
        -i                  Install packages for PDNS with MySQL
        -4                  Configure PDNS Service with IPv4, if you don't want to configure IPv6 do not use -4
        -6                  Configure PDNS Service with IPv6, if you don't want to configure IPv6 do not use -6
        -b                  Configure PDNS BACKEND and creating the DB, if you don't want to configure the BACKEND do not use -b
        -t  [MASTER|SLAVE]  Configure Server as master or slave
        -z  [0|4|6|46]      Create no zone, Create a minimal IPv4 zone , Create a minimal IPv6 zone, Create a minimal IPv4/6 zone
        -h  Display this help
    "
}

function package-install {
    # Install expect needed for interaction between script an UIs
    apt update && apt -y install expect

    # Install packages 
    # Automatically yes to installation and no to the pdns-mysql-backend configurator 
    export DEBIAN_FRONTEND=noninteractive
    apt-get -yq install mariadb-client mariadb-server pdns-server pdns-backend-mysql
    export DEBIAN_FRONTEND=""
    
    # Setup mariadb
    # Set root password
    SECURE_MYSQL=$(expect -c "
    set timeout 10
    spawn mysql_secure_installation
    expect \"Enter current password for root (enter for none):\"
    send \"$MYSQL\r\"
    expect \"Change the root password?\"
    send \"n\r\"
    expect \"Remove anonymous users?\"
    send \"y\r\"
    expect \"Disallow root login remotely?\"
    send \"y\r\"
    expect \"Remove test database and access to it?\"
    send \"y\r\"
    expect \"Reload privilege tables now?\"
    send \"y\r\"
    expect eof
    ")
    echo "$SECURE_MYSQL"
    # Remove expect and its dependencies
    apt -y purge expect
    apt -y autoremove 
}

function create-configs {
    # Move original config to backup
    mv /etc/powerdns/pdns.conf /etc/powerdns/_orgi.pdns.conf
    # Create config files
    cp ./pdns.conf /etc/powerdns/pdns.conf
    cp ./pdns.gmysql.conf /etc/powerdns/pdns.d/pdns.gmysql.conf
}

function configure-servicev4 {
    while [ $1 !=  "0" ]
    do
        if [ $1 = "MASTER" ]; then 
            # Create master configuration for IPv4
            sed -i -e "s/1.1.1.1/$2/g" /etc/powerdns/pdns.conf
            sed -i -e "s/slave=yes/slave=no/g" /etc/powerdns/pdns.conf
        elif [ $1 = "SLAVE" ]; then
            # Create slave configuration for IPv4
            sed -i -e "s/1.1.1.1/127.0.0.1/g" /etc/powerdns/pdns.conf
            sed -i -e "s/master=yes/master=no/g" /etc/powerdns/pdns.conf
        else
            echo "Wronge server TYPE (`0` for aborting server configuration) or"
            read -p "Pleas enter the the server typre [MASTER|SLAVE]: " 1
        fi
    done
}

function configure-servicev6 {
    while [ $1 !=  "0" ]
    do
        if [ $1 = "MASTER" ]; then 
            # Create master configuration for IPv6
            sed -i -e "s/2606:4700:4700::1111/$2/g" /etc/powerdns/pdns.conf
            sed -i -e "s/slave=yes/slave=no/g" /etc/powerdns/pdns.conf
        elif [ $1 = "SLAVE" ]; then 
            # Create slave configuration for IPv6
            sed -i -e "s/2606:4700:4700::1111/::1/g" /etc/powerdns/pdns.conf
            sed -i -e "s/master=yes/master=no/g" /etc/powerdns/pdns.conf
        else
            echo "Wronge server TYPE (`0` for aborting server configuration) or"
            read -p "Pleas enter the the server typre [MASTER|SLAVE]: " 1
        fi
    done
}

function configure-BACKEND {
    #Replace placeholder with DB credentials
    sed -i -e "s/powerdns_user/$1/g" /etc/powerdns/pdns.conf
    sed -i -e "s/powerdns_user_password/$2/g" /etc/powerdns/pdns.conf
    sed -i -e "s/powerdns_user/$1/g" ./schema.sql
    sed -i -e "s/powerdns_user_password/$2/g" ./schema.sql
    # Create database
    mysql -u root < ./schema.sql
}

function create-ipv4-zone {
    # Create zone
    if [ $1 = "master" ]
    then
        # Edit Zone
        sed -i -e "s/example.com/$2/g" ./masterv4.sql
        sed -i -e "s/placeNS0.com/$3/g" ./masterv4.sql
        sed -i -e "s/placeNS1.com/$4/g" ./masterv4.sql
        sed -i -e "s/placeA/$5/g" ./masterv4.sql
        # Create Zone
        mysql -u root < ./masterv4.sql
        echo "Mster zone IPv4 created for $2"
        # Reset Zone
        sed -i -e "s/$2/example.com/g" ./masterv4.sql
        sed -i -e "s/$3/placeNS0.com/g" ./masterv4.sql
        sed -i -e "s/$4/placeNS1.com/g" ./masterv4.sql
        sed -i -e "s/$5/placeA/g" ./masterv4.sql
    elif [ $1 = "slave" ]
    then
        # Edit Zone
        sed -i -e "s/example.com/$2/g" ./slavev4.sql
        sed -i -e "s/placeNS0.com/$3/g" ./slavev4.sql
        # Create Zone
        mysql -u root < ./slavev4.sql
        echo "Slave zone IPv4 created for $2"
        # Reset Zone
        sed -i -e "s/$2/example.com/g" ./slavev4.sql
        sed -i -e "s/$3/placeNS0.com/g" ./slavev4.sql
    fi
}

function create-ipv6-zone {
    # Create zone
    if [ $1 = "master" ]
    then
        # Edit Zone
        sed -i -e "s/example.com/$2/g" ./masterv6.sql
        sed -i -e "s/placeNS0v6.com/$3/g" ./masterv6.sql
        sed -i -e "s/placeNS1v6.com/$4/g" ./masterv6.sql
        sed -i -e "s/placeAAAA/$5/g" ./masterv6.sql
        # Create Zone
        mysql -u root < ./masterv6.sql
        echo "Mster zone IPv4 created for $2"
        # Reset Zone
        sed -i -e "s/$2/example.com/g" ./masterv6.sql
        sed -i -e "s/$3/placeNS0v6.com/g" ./masterv6.sql
        sed -i -e "s/$4/placeNS1v6.com/g" ./masterv6.sql
        sed -i -e "s/$5/placeAAAA/g" ./masterv6.sql
    elif [ $1 = "slave" ]
    then
        # Edit Zone
        sed -i -e "s/example.com/$2/g" ./slavev6.sql
        sed -i -e "s/placeNS0v6.com/$3/g" ./slavev6.sql
        # Create Zone
        mysql -u root < ./slavev6.sql
        echo "Slave zone IPv4 created for $2"
        # Reset Zone
        sed -i -e "s/$2/example.com/g" ./slavev6.sql
        sed -i -e "s/$3/placeNS0v6.com/g" ./slavev6.sql
    fi
}
# Define Variable
INSTALL="N/A"
IPv4="N/A"
IPv6="N/A"
BACKEND="N/A"
TYPE="N/A"

while getopts "i46bt:z:" opt; do
    case $opt in
        i) INSTALL="YES"
        ;;
        4)  IPv4="YES"
            read -p "Pleas enter the master IPv4: " masteripv4
            read -p "Pleas enter the slave IPv4: " slaveipv4
        ;;
        6)  IPv6="YES"
            read -p "Pleas enter the master IPv6: " masteripv6
            read -p "Pleas enter the slave IPv6: " slaveipv6
        ;;
        b)  BACKEND="YES"
            read -p "Pleas enter the your new DB user: " MYSQL_DB_USER
            read -p "Pleas enter the the new password for the DB user: " -r -s MYSQL_DB_PASSWORD && echo ""
        ;;
        t)  TYPE="$OPTARG"
        ;; 
        z)  zone="$OPTARG"
        ;;       
        h)  HELP >&2
        ;;
        \?) HELP >&2
        ;;
        ?)  echo "Invalid option -$OPTARG -h for Help" >&2
        ;;
    esac
done
# Install Package if requested 
if [ $INSTALL = "YES" ]; then package-install; fi
# Configure PDNS with IPv4 and IPv6
if [ $IPv4 = "YES" ] && [ $IPv6 = "YES" ]; then  
    create-configs 
    configure-servicev4 $TYPE $slaveipv4 
    configure-servicev6 $TYPE $slaveipv6 
    IPv4 = "NO"
    IPv6 = "NO"
fi  
# Configure PDNS with IPv4 
if [ $IPv4 = "YES" ]; then create-configs;configure-servicev4 $TYPE $slaveipv4; fi 
# Configure PDNS with IPv6
if [ $IPv6 = "YES" ]; then create-configs; configure-servicev6 $TYPE $slaveipv6; fi
# Configure MySQL BACKEND and creating DB
if [ BACKEND = "YES" ]; then configure-BACKEND $MYSQL_DB_USER $MYSQL_DB_PASSWORD; fi
# Create zone
case $zone in
    4)
        read -p "Pleas enter the domain: " domain
        read -p "Pleas enter the A Records IP: " ARecord
        # If the masteripv4 slaveipv4 haven't been read before 
        if [ $IPv4 != "YES" ];then
            read -p "Pleas enter the master IPv4: " masteripv4
            read -p "Pleas enter the slave IPv4: " slaveipv4        
        fi
        create-ipv4-zone $TYPE $domain $masteripv4 $slaveipv4 $ARecord
    ;;
    6)
        read -p "Pleas enter the domain: " domain
        read -p "Pleas enter the AAAA Records IP: " AAAARecord
        # If the masteripv6 slaveipv6 haven't been read before 
        if [ $IPv6 != "YES" ];then
            read -p "Pleas enter the master IPv6: " masteripv6
            read -p "Pleas enter the slave IPv6: " slaveipv6
        fi
        create-ipv6-zone $TYPE $domain $masterIPv6 $slaveIPv6 $AAAARecord 
    ;;
    46)
        read -p "Pleas enter the domain: " domain
        read -p "Pleas enter the A Records IP: " ARecord
        read -p "Pleas enter the AAAA Records IP: " AAAARecord
        if [ $IPv6 != "YES" ];then
            read -p "Pleas enter the master IPv6: " masteripv6
            read -p "Pleas enter the slave IPv6: " slaveipv6
        fi
        create-ipv4-zone $TYPE $domain $masteripv4 $slaveipv4 $ARecord
        create-ipv6-zone $TYPE $domain $masterIPv6 $slaveIPv6 $AAAARecord 
    ;;
    ?)
    ;;
esac 
