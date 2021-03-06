#
# Cookbook Name:: sensu
# Recipe:: default
#
# Copyright (c) 2016 The Authors, All Rights Reserved.


# ip = node['network']['interfaces']['eth1']['addresses'].detect{|k,v| v['family'] == "inet" }.first

ip = node['network']['interfaces']['enp0s8']['addresses'].detect{|k,v| v['family'] == "inet" }.first
#
cookbook_file '/etc/apt/sources.list.d/apt_repo.list' do
  source 'apt_repo.list'
  owner 'root'
  group 'root'
  mode 00644
end

cookbook_file '/etc/apt/sources.list' do
  source 'sources.list'
  owner 'root'
  group 'root'
  mode 00644
end

execute 'update_apt' do
  command 'apt-get update'
  action :run
end

apt_package 'build-essential' do
  action :install
end

apt_package 'ruby-dev' do
  action :install
end

apt_package 'ruby' do
  action :install
end

apt_package 'redis-server' do
  action :install
  options "--force-yes"
end

service 'redis-server' do
  supports :status => true
  action [ :enable, :start ]
  ignore_failure true
end

apt_package 'rabbitmq-server' do
  action :install
  options "--force-yes"
  notifies :run, 'execute[rabbitmq-vhost]', :immediately
end
service 'rabbitmq-server' do
  supports :status => true
  action [ :enable, :start ]
  ignore_failure true
end

execute 'rabbitmq-vhost' do
  command 'rabbitmqctl add_vhost /sensu'
  action :nothing
  notifies :run, 'execute[rabbit-user]', :immediately
end

execute 'rabbit-user' do
  command 'rabbitmqctl add_user sensu monitor'
  action :nothing
  notifies :run, 'execute[rabbit-permissions]', :immediately
end

execute 'rabbit-permissions' do
  command 'rabbitmqctl set_permissions -p /sensu sensu ".*" ".*" ".*"'
  action :nothing
  notifies :run, 'execute[add-rabbit-web-ui]', :immediately
end

execute 'add-rabbit-web-ui' do
  command 'rabbitmq-plugins enable rabbitmq_management'
  action :nothing
end

apt_package 'apache2' do
  action :install
  options "--force-yes"
end

service 'apache2' do
  supports :status => true
  action [ :enable, :start ]
  ignore_failure true
end

apt_package 'sensu' do
  action :install
  options "--force-yes"
end

apt_package 'nagios-plugins' do
  action :install
  options "--force-yes"
end

# cookbook_file '/etc/sensu/config.json' do
#   source 'config.json'
template '/etc/sensu/config.json' do
  source 'config.json.erb'
  owner 'root'
  group 'root'
  mode 00644
  variables({
          "client_ip" => ip
         })
  notifies :restart, 'service[sensu-server]', :immediately
end

cookbook_file '/etc/sensu/plugins/check_file.sh' do
  source 'check_file.sh'
  owner 'root'
  group 'root'
  mode 00755
end

directory '/etc/sensu/conf.d/checks' do
  owner 'root'
  group 'root'
  mode 00755
  recursive true
  action :create
end

cookbook_file '/etc/sensu/conf.d/check_file.json' do
  source 'check_file.json'
  owner 'root'
  group 'root'
  mode 00644
  notifies :restart, 'service[sensu-server]', :immediately
end
#
# cookbook_file '/etc/sensu/conf.d/check_disk.json' do
#   source 'check_disk.json'
#   owner 'root'
#   group 'root'
#   mode 00644
#   notifies :restart, 'service[sensu-server]', :immediately
# end

# cookbook_file '/etc/sensu/conf.d/checks/load_check_15_min.json' do
#   source 'server/checks/load_check_15_min.json'
#   owner 'root'
#   group 'root'
#   mode 00644
#   notifies :restart, 'service[sensu-server]', :immediately
# end

cookbook_file '/etc/sensu/handlers/metric_to_file.sh' do
  source 'server/handlers/metric_to_file.sh'
  owner 'root'
  group 'root'
  mode 00755
  notifies :restart, 'service[sensu-server]', :immediately
end

cookbook_file '/etc/sensu/handlers/JSON.sh' do
  source 'server/handlers/JSON.sh'
  owner 'root'
  group 'root'
  mode 00755
  notifies :restart, 'service[sensu-server]', :immediately
end

cookbook_file '/etc/sensu/conf.d/handler_tcp.json' do
  source 'server/handlers/handler_tcp.json'
  owner 'root'
  group 'root'
  mode 00755
  notifies :restart, 'service[sensu-server]', :immediately
end

# cookbook_file '/etc/sensu/conf.d/mac_check_disk.json' do
#   source 'mac_check_disk.json'
#   owner 'root'
#   group 'root'
#   mode 00644
#   notifies :restart, 'service[sensu-server]', :immediately
# end

template '/etc/sensu/conf.d/client.json' do
  source 'server_client.json.erb'
  owner 'root'
  group 'root'
  mode 00644
  variables({
          "client_ip" => ip
         })
  notifies :restart, 'service[sensu-client]', :immediately
end

# cookbook_file '/etc/sensu/conf.d/filter_production.json' do
#   source 'filter_production.json'
#   owner 'root'
#   group 'root'
#   mode 00755
#   notifies :restart, 'service[sensu-server]', :immediately
# end
#
# cookbook_file '/etc/sensu/mutators/prettymutator.rb' do
#   source 'server/mutators/prettymutator.rb'
#   owner 'root'
#   group 'root'
#   mode 00755
# end
#
# cookbook_file '/etc/sensu/conf.d/mutator_pretty.json' do
#   source 'server/mutators/mutator_pretty.json'
#   owner 'root'
#   group 'root'
#   mode 00755
#   notifies :restart, 'service[sensu-server]', :immediately
# end

#################################### end sensu configs
service 'sensu-server' do
  supports :status => true
  action [ :enable, :start ]
  ignore_failure true
  notifies :restart, 'service[sensu-api]', :immediately
end
service 'sensu-api' do
  supports :status => true
  action [ :enable, :start ]
  ignore_failure true
  notifies :restart, 'service[sensu-client]', :immediately
end

service 'sensu-client' do
  supports :status => true
  action [ :enable, :start ]
  ignore_failure true
end

apt_package 'redis-server' do
  action :install
  options "--force-yes"
end



apt_package 'uchiwa' do
  action :install
  options "--force-yes"
end

cookbook_file '/etc/sensu/uchiwa.json' do
  source 'uchiwa.json'
  owner 'root'
  group 'root'
  mode 00644
end

service 'uchiwa' do
  supports :status => true
  action [ :enable, :start ]
  ignore_failure true
end

gem_package 'rest-client' do
  action :install
end

# gem_package 'sensu-check-rabbitmq-alive' do
#   version '2.0.0'
# end
