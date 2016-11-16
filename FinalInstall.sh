#!/bin/sh

# Install Sensu, RabbitMQ, Redis
hostname SensuServer
apt-get install rabbitmq-server redis-server -y
cd /sbin
su - -c 'rabbitmq-plugins enable rabbitmq_management'
service rabbitmq-server restart
rabbitmqctl add_vhost /sensu
rabbitmqctl add_user sensu secret
rabbitmqctl set_permissions -p /sensu sensu ".*" ".*" ".*"
wget -q http://repos.sensuapp.org/apt/pubkey.gpg
apt-key add pubkey.gpg
echo "deb     http://repos.sensuapp.org/apt sensu main" | sudo tee /etc/apt/sources.list.d/sensu.list
apt-get update
apt-get install sensu -y
cat <<EOT > /etc/sensu/config.json
{
  "rabbitmq": {
    "host": "localhost",
    "vhost": "/sensu",
    "user": "sensu",
    "password": "secret"
  },
  "redis": {
    "host": "localhost"
  },
  "api": {
      "host": "localhost",
      "port": 4567
  }
}
EOT

/etc/init.d/sensu-server start
/etc/init.d/sensu-api start

# Configure Sensu Client
IP=$(hostname -I)
cat <<EOT >> /etc/sensu/conf.d/client.json
{
  "client": {
    "name": "SensuServer",
    "address": "$IP",
    "subscriptions": [
      "Production"
    ],
    "environment": "Production"
  }
}
EOT
service sensu-client start

# Configure Uchiwa
wget http://dl.bintray.com/palourde/uchiwa/uchiwa_0.10.3-1_amd64.deb
dpkg -i uchiwa_0.10.3-1_amd64.deb
cat <<EOT > /etc/sensu/uchiwa.json
{
  "sensu": [
    {
      "name": "SensuServer",
      "host": "localhost",
      "port": 4567,
      "ssl": false,
      "path": "",
      "user": "sensu",
      "pass": "sensu",
      "timeout": 5
    }
  ],
  "uchiwa": {
    "host": "0.0.0.0",
    "port": 3000,
    "interval": 5
  }
}
EOT

service uchiwa start
#####################
#Configure Checks
#####################

# The check_file definition
cat <<EOT > /etc/sensu/conf.d/check_file.json
  
EOT

# The check_file check
cat <<EOT > /etc/sensu/plugins/check_file.sh
#!/bin/sh
if [ -f "/tmp/file" ]
then
  echo "file exists!"
  exit 0
else
  echo "file is missing!"
  exit 2
fi
EOT

# Make check_file.sh executable
chmod +x /etc/sensu/plugins/check_file.sh

# Create testfile
touch /tmp/file

# Install Nagios Plugins
apt-get install Nagios-plugins -y

# Add check definition for Nagios check_disk check.
cat <<EOT > /etc/sensu/conf.d/check_disk.json
{
  "checks": {
    "check_disk": {
      "command": "/usr/lib/nagios/plugins/check_disk -w 25% -c 10%",
      "subscribers": [
        "Production"
      ],
      "interval": 5
    }
  }
}
EOT

apt-get install ruby ruby-dev make -y
gem install sensu-plugins-pagerduty
cat <<EOT >> /etc/sensu/conf.d/handler_tcp.json
{
  "handlers": {
    "handler_tcp": {
      "type": "tcp",
      "mutator": "mutator_pretty",
      "socket": {
        "host": "localhost",
        "port": 6000
      }
    }
  }
}
EOT

cat <<EOT >> /etc/sensu/conf.d/handler_pagerduty.json
{
  "pagerduty": {
    "api_key": "1703026fefbe4579a7225507f094c416"
  },
  "handlers": {
    "handler_pagerduty": {
      "type": "pipe",
      "command": "handler-pagerduty.rb",
      "severities": [
        "critical",
        "ok"
      ],
      "filter": "filter_production"
    }
  }
}
EOT

cat <<EOT > /etc/sensu/conf.d/check_file.json
{
  "checks": {
    "check_file": {
      "command": "/etc/sensu/plugins/check_file.sh",
      "subscribers": [
        "Production"
      ],
      "interval": 5,
      "handler": "handler_tcp",
      "occurrences": 1,
      "refresh": 1
    }
  }
}
EOT

# Set up Filters
cat <<EOT > /etc/sensu/conf.d/filter_production.json
{
  "filters": {
    "filter_production": {
      "attributes": {
        "client": {
          "environment": "Production"
        }
      }
    }
  }
}
EOT

# Set up Mutator
cat <<EOT > /etc/sensu/conf.d/mutator_pretty.json
{
  "mutator_pretty": {
    "command": "/etc/sensu/mutators/prettymutator.rb"
  }
}
EOT

cat <<EOT > /etc/sensu/mutators/prettymutator.rb
#!/usr/bin/env ruby

require 'rubygems'
require 'json'

puts JSON.pretty_generate(JSON.parse(STDIN.read))
EOT

# Set up Graphite
apt-get update
apt-get install graphite-web -y
DEBIAN_FRONTEND=noninteractive apt-get -q -y --force-yes install graphite-carbon
graphite-manage syncdb --noinput

cat <<EOT > /etc/default/graphite-carbon
# Change to true, to enable carbon-cache on boot
CARBON_CACHE_ENABLED=true
EOT

cat <<EOT > /etc/carbon/storage-schemas.conf
# Schema definitions for Whisper files. Entries are scanned in order,
# and first match wins. This file is scanned for changes every 60 seconds.
#
#  [name]
#  pattern = regex
#  retentions = timePerPoint:timeToStore, timePerPoint:timeToStore, ...

# Carbon's internal metrics. This entry should match what is specified in
# CARBON_METRIC_PREFIX and CARBON_METRIC_INTERVAL settings
[carbon]
pattern = ^carbon\.
retentions = 60:90d

[default_1min_for_1day]
pattern = .*
retentions = 5s:1d,1m:30d
EOT

service carbon-cache start
apt-get install apache2 libapache2-mod-wsgi -y
# Configure Apache
cp /usr/share/graphite-web/apache2-graphite.conf /etc/apache2/sites-available
a2ensite apache2-graphite
a2dissite 000-default
chmod 666 /var/lib/graphite/graphite.db
chmod 755 /usr/share/graphite-web/graphite.wsgi
service apache2 restart

# Install some metrics plugins
gem install sensu-plugins-load-checks
gem install sensu-plugins-network-checks

# Configure Check metrics
cat <<EOT > /etc/sensu/conf.d/check_metrics.json
{
  "checks": {
    "load_metrics": {
      "type": "metric",
      "command": "metrics-load.rb",
      "interval": 5,
      "subscribers": ["Production"],
      "handlers": ["handler_graphite"]
    },
    "net_metrics": {
      "type": "metric",
      "command": "metrics-net.rb",
      "interval": 5,
      "subscribers": ["Production"],
      "handlers": ["handler_graphite"]
    }
  }
}
EOT

# Configure Graphite TCP Handler
cat <<EOT > /etc/sensu/conf.d/handler_graphite.json
{
  "handlers": {
    "handler_graphite": {
      "type": "tcp",
      "mutator": "only_check_output",
      "socket": {
        "host": "localhost",
        "port": 2003
      }
    }
  }
}
EOT

# Install Grafana
wget https://grafanarel.s3.amazonaws.com/builds/grafana_2.1.3_amd64.deb
dpkg -i grafana_2.1.3_amd64.deb

cat <<EOT > /etc/grafana/grafana.ini
[paths]
[server]
http_port = 8080
[database]
[session]
[analytics]
[security]
[users]
[auth.anonymous]
[auth.github]
[auth.google]
[auth.proxy]
[auth.basic]
[auth.ldap]
[smtp]
[emails]
[log]
[log.console]
[log.file]
[event_publisher]
[dashboards.json]
EOT

update-rc.d grafana-server defaults 95 10
service grafana-server
service sensu-client restart && service sensu-api restart && service sensu-server restart
