#
# Cookbook Name:: DMZIHSLiberty
# Recipe:: default
#
# Copyright 2014, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#
include_recipe "iim"

directory "/opt/IBM" do
  group node[:im][:group]
  owner node[:im][:user]
  mode "0755"
  recursive true
end

iim_iim 'websphere' do 
   response_file node[:DMZIHSLiberty][:frontEnd][:IHS][:install][:responseFile]
   secure_storage_file node[:DMZIHSLiberty][:frontEnd][:IHS][:install][:secureStorageFile]
   action :install
end

