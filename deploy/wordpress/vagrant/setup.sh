#!/bin/bash

# Make mysql-install non-interactive, so it doesn't prompt for password
export DEBIAN_FRONTEND=noninteractive
sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password password changeme'
sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password changeme'

# Install prerequisites
sudo apt-get update
sudo apt-get -y install git mysql-client mysql-server apache2 libapache2-mod-php5 pwgen python-setuptools vim-tiny php5-mysql php-apc php5-gd php5-curl php5-memcache memcached mc curl sendmail

sed -i "s/^bind-address/#bind-address/" /etc/mysql/my.cnf
echo "extension=php_pdo_mysql.dll" | sudo tee -a /etc/php5/apache2/php.ini

curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin
mv /usr/local/bin/composer.phar /usr/local/bin/composer

rm -rf /var/www/ ; cd /var; mkdir www; cd www; 

cd /srv
sudo git clone git://github.com/wp-cli/wp-cli.git
cd wp-cli
sudo composer install

# Generate random passwords 
MYSQL_PASSWORD=`pwgen -c -n -1 12`
WP_PASSWORD=`pwgen -c -n -1 12`

# This is so the passwords show up in logs. 
echo mysql root password: $MYSQL_PASSWORD
echo wp password: $WP_PASSWORD
echo $MYSQL_PASSWORD > /mysql-root-pw.txt
echo $WP_PASSWORD > /wp-db-pw.txt

# Set database password and prep for Drupal install
mysqladmin -u root --password=changeme password $MYSQL_PASSWORD 
mysql -uroot -p$MYSQL_PASSWORD -e "CREATE DATABASE wp; GRANT ALL PRIVILEGES ON wp.* TO 'wp'@'localhost' IDENTIFIED BY '$WP_PASSWORD'; FLUSH PRIVILEGES;"

sed -i 's/AllowOverride None/AllowOverride All/' /etc/apache2/sites-available/*default*
sed -i 's/DocumentRoot \/var\/www\/html/DocumentRoot \/var\/www/wordpress-default' /etc/apache2/sites-available/*default*

# Fix apache configuration
sudo cp /vagrant/000-default.conf.sample /etc/apache2/sites-available/000-default.conf
sudo service apache2 restart

a2enmod rewrite vhost_alias

# Install Wordpress
cd /var/www/
curl -O http://wordpress.org/latest.tar.gz
tar -xvf latest.tar.gz
mv wordpress wordpress-default
rm latest.tar.gz
cd /var/www/wordpress-default

/srv/wp-cli/bin/wp core config --allow-root --dbname=wp --dbuser=wp --dbpass=${WP_PASSWORD} --quiet --extra-php <<PHP
define( 'WP_DEBUG', true );
PHP
/srv/wp-cli/bin/wp core install --allow-root --url=local.wordpress.dev --quiet --title="Amber Wordpress" --admin_name=admin --admin_email="admin@local.dev" --admin_password="password"

# Get Amber code
cd /usr/local/src
git clone https://github.com/berkmancenter/robustness_wordpress.git
mv /usr/local/src/robustness_wordpress/amber /var/www/wordpress-default/wp-content/plugins

service apache2 restart
