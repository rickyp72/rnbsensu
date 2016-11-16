apt_package 'sensu' do
  action :install
  options "--force-yes"
end



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

cookbook_file '/etc/sensu/config.json' do
  source 'client0.json'
  owner 'root'
  group 'root'
  mode 00644
  notifies :restart, 'service[sensu-client]', :immediately
end

service 'sensu-client' do
  supports :status => true
  action [ :enable, :start ]
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
