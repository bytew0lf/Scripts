#!/bin/bash

MIN_LEN=12
echo "Please enter a strong password ( >= $MIN_LEN chars ) for the database."
read -sp 'Password: ' DB_PASS

if [ ${#DB_PASS} -lt $MIN_LEN ];
then
    echo "ABORT: Password is too short."
    exit;
fi

# Get the IP for later display
IP_ADDR=`ip a | grep inet | grep -v inet6 | grep -v 127 | awk '{ print $2 }' | cut -d/ -f1`

apt-get update
apt-get -y install subversion mariadb-server libmariadbclient-dev apache2 apache2-dev libapr1-dev libaprutil1-dev libcurl4-gnutls-dev libmagickwand-dev imagemagick build-essential dirmngr curl rails ruby2.5 ruby-dev libssl-dev

cd /opt/
mkdir redmine
cd redmine/

svn co https://svn.redmine.org/redmine/branches/4.1-stable current

cd current/

mkdir -p tmp tmp/pdf public/plugin_assets
chown -R www-data:www-data files log tmp public/plugin_assets
chmod -R 755 files log tmp public/plugin_assets
mkdir -p /opt/redmine/repos/svn /opt/redmine/repos/git
chown -R www-data:www-data /opt/redmine/repos
cp config/configuration.yml.example config/configuration.yml
cp config/database.yml.example config/database.yml


echo -e "CREATE DATABASE redmine CHARACTER SET utf8mb4;
CREATE USER 'redmine'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON redmine.* TO 'redmine'@'localhost';
" > db.txt

mysql -uroot < db.txt
rm db.txt

# Set the password for the database
sed -e 's/password: \"\"/password: \"'$DB_PASS'\"/g' config/database.yml > tmp1.yml

# Modify the user of the database
sed -e "s/username: root/username: redmine/g" tmp1.yml > tmp2.yml

rm tmp1.yml # temporary file
mv tmp2.yml config/database.yml

#nano config/database.yml

gem install bundler passenger
passenger-install-apache2-module --auto --languages ruby
passenger-install-apache2-module --snippet > /etc/apache2/conf-available/passenger.conf
/usr/sbin/a2enconf passenger

# LoadModule passenger_module /var/lib/gems/2.5.0/gems/passenger-6.0.6/buildout/apache2/mod_passenger.so
#   <IfModule mod_passenger.c>
#     PassengerRoot /var/lib/gems/2.5.0/gems/passenger-6.0.6
#     PassengerDefaultRuby /usr/bin/ruby2.5
#   </IfModule>

cd /opt/redmine/current

bundle config set without 'development test'
bundle install
bundle exec rake generate_secret_token
RAILS_ENV=production REDMINE_LANG=en bundle exec rake db:migrate
RAILS_ENV=production REDMINE_LANG=en bundle exec rake redmine:load_default_data

echo -e "
#ServerName redmine.domain.com

<VirtualHost *:80>
    ServerAdmin admin@domain.com
    ServerName localhost

    DocumentRoot /opt/redmine/current/public/

    ## Passenger Configuration
    ## Details at http://www.modrails.com/documentation/Users%20guide%20Apache.html

    PassengerMinInstances 2
    PassengerMaxPoolSize 6
    RailsBaseURI /
    PassengerAppRoot /opt/redmine/current

    # Speeds up spawn time tremendously -- if your app is compatible.
    # RMagick seems to be incompatible with smart spawning
    RailsSpawnMethod smart

    # Keep the application instances alive longer. Default is 300 (seconds)
    PassengerPoolIdleTime 1000

    # Keep the spawners alive, which speeds up spawning a new Application
    # listener after a period of inactivity at the expense of memory.
    RailsAppSpawnerIdleTime 3600

    # Additionally keep a copy of the Rails framework in memory. If you're
    # using multiple apps on the same version of Rails, this will speed up
    # the creation of new RailsAppSpawners. This isn't necessary if you're
    # only running one or 2 applications, or if your applications use
    # different versions of Rails.
    PassengerMaxPreloaderIdleTime 0

    # Just in case you're leaking memory, restart a listener
    # after processing 500 requests
    PassengerMaxRequests 500

    # only check for restart.txt et al up to once every 5 seconds,
    # instead of once per processed request
    PassengerStatThrottleRate 5

    # If user switching support is enabled, then Phusion Passenger will by default run the web application as the owner if the file config/environment.rb (for Rails apps) or config.ru (for Rack apps). This option allows you to override that behavior and explicitly set a user to run the web application as, regardless of the ownership of environment.rb/config.ru.
    PassengerUser www-data
    PassengerGroup www-data

    # By default, Phusion Passenger does not start any application instances until said web application is first accessed. The result is that the first visitor of said web application might experience a small delay as Phusion Passenger is starting the web application on demand. If that is undesirable, then this directive can be used to pre-started application instances during Apache startup.
    PassengerPreStart http://localhost


    <Directory /opt/redmine/current/public/>
       Options FollowSymLinks
       Require all granted
    </Directory>


    AddOutputFilter DEFLATE text/html text/plain text/xml application/xml application/xhtml+xml text/javascript text/css
    BrowserMatch ^Mozilla/4 gzip-only-text/html
    BrowserMatch ^Mozilla/4.0[678] no-gzip
    BrowserMatch \bMSIE !no-gzip !gzip-only-text/html


    ErrorLog ${APACHE_LOG_DIR}/redmine.error.log
    LogLevel warn
    CustomLog ${APACHE_LOG_DIR}/redmine.access.log combined
    ServerSignature Off

</VirtualHost>
" > /etc/apache2/sites-available/redmine.conf

chown -R www-data:www-data /opt/redmine/current/log /opt/redmine/current/Gemfile.lock

/usr/sbin/a2enmod rewrite
/usr/sbin/a2enmod headers
/usr/sbin/a2dissite 000-default
/usr/sbin/a2ensite redmine

systemctl restart mysqld.service
systemctl restart apache2.service

echo -e "\n\nYou can access redmine via: http://$IP_ADDR\nCredentials: USER: admin PASSWORD: admin"