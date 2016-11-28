apt_package 'sensu' do
  action :install
  options "--force-yes"
end

# ip = node['network']['interfaces']['enp0s8']['addresses'].detect{|k,v| v['family'] == "inet" }.first
ip = node['network']['interfaces']['eth1']['addresses'].detect{|k,v| v['family'] == "inet" }.first

# cookbook_file '/etc/sensu/conf.d/client.json' do
#   source 'client.json'
#   owner 'root'
#   group 'root'
#   mode 00644
#   notifies :restart, 'service[sensu-client]', :immediately
# end

# cookbook_file '/etc/sensu/conf.d/transport.json' do
#   source 'transport.json'
#   owner 'root'
#   group 'root'
#   mode 00644
#   notifies :restart, 'service[sensu-client]', :immediately
# end
#
# cookbook_file '/etc/sensu/conf.d/rabbitmq.json' do
#   source 'rabbitmq.json'
#   owner 'root'
#   group 'root'
#   mode 00644
#   notifies :restart, 'service[sensu-client]', :immediately
# end

template '/etc/sensu/config.json' do
  source 'client0.json.erb'
  owner 'root'
  group 'root'
  mode 00644
  variables({
          "client_ip" => ip
         })
  notifies :restart, 'service[sensu-client]', :immediately
end

service 'sensu-client' do
  supports :status => true
  action [ :enable, :start ]
  ignore_failure true
end

apt_package 'nagios-plugins' do
  action :install
  options "--force-yes"
end

cookbook_file '/etc/sensu/plugins/check_file.sh' do
  source 'check_file.sh'
  owner 'root'
  group 'root'
  mode 00755
end
