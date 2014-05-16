#
# Cookbook Name:: DMZIHSLiberty
# Recipe:: default
#
# Copyright 2014, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#
require "open3"
require 'tempfile'
require 'fileutils'
chef_gem 'nokogiri'

class Chef::Recipe
  include MergeXML
end

if not node[:DMZIHSLiberty][:frontEnd][:IHS][:baseDir].nil? 
  baseDir = node[:DMZIHSLiberty][:frontEnd][:IHS][:baseDir]
elsif !node[:ihs].nil? and !node[:ihs][:paths].nil? and !node[:ihs][:paths][:install].nil? #As part of a different cookbook this might not exist at all, checking extensively to prevent errors 
  baseDir = node[:ihs][:paths][:install]
else
  raise "The base directory of IHS was not found. Please add it to the node.conf or a suitable alternative"
end


if not node[:DMZIHSLiberty][:frontEnd][:IHS][:webSpherePluginsDir].nil? 
  webSpherePluginsDir = node[:DMZIHSLiberty][:frontEnd][:IHS][:webSpherePluginsDir]
elsif !node[:ihs].nil? and !node[:ihs][:paths].nil? and !node[:ihs][:paths][:plugins].nil? #As part of a different cookbook this might not exist at all, checking extensively to prevent errors 
  webSpherePluginsDir = node[:ihs][:paths][:plugins]
else
  raise "The base directory of WebSphere plugins directory was not found. Please add it to the node.conf or a suitable alternative"
end


bits = %x(uname -m | grep -o "^[^_]*" | sed -e 's/i6/i3/g')

if bits.start_with?('x') #as in x86_64
  bits = '64'
elsif bits.start_with?('i') #as in i386 or i686
  bits = '32'
end

binDir = "#{baseDir}/bin"
confDir = "#{baseDir}/conf"
plugincfg = "#{confDir}/plugin-cfg.xml"
mergedFilePrime = Tempfile.new('mergedFile')
mergedFilePrime.write(".")#force file creation, it will be overwritten later. 
mergedFile = mergedFilePrime.path
mergedFilePrime.close()

ruby_block "create plugin-cfg.xml" do 
  block do
   unmergedFiles = []
   

   Dir.chdir("/tmp/plgin-cfgs")
   Dir.glob('**/*.xml').each do |item|
     next if item == '.' or item == '..'
       unmergedFiles << item
     end

   if unmergedFiles.length == 0 
     raise "No plgin-cfg.xml files were found."
   elsif unmergedFiles.length == 1
     %x(cp #{unmergedFiles[0]} #{mergedFile})
   else

     MergeXML.mergeXML(unmergedFiles[0], unmergedFiles[1], mergedFile, node[:DMZIHSLiberty][:frontEnd][:plugincfg])

     #next merge any additional files into the previous merged file. 
     i = 2
     while i <  unmergedFiles.length do
      MergeXML.mergeXML(mergedFile, unmergedFiles[i], mergedFile, node[:DMZIHSLiberty][:frontEnd][:plugincfg])
      i += 1
     end
   end
  end
end

bash "create empty plugin-cfg" do # Later on I compare to see if plugincfg needs to be updated, so I need something to compare against. 
  code <<-EOH
  cp -p #{confDir}/httpd.conf #{plugincfg}
  EOH
  not_if {::File.exists?(plugincfg)}
end


ruby_block "load websphere plugin" do
  block do

    lines = ::IO.readlines("#{confDir}/httpd.conf")
    index = lines.find_index { |line| line.start_with?("LoadModule")}
    lines.insert(index, "LoadModule was_ap22_module #{webSpherePluginsDir}/bin/#{bits}bits/mod_was_ap22_http.so")

    ::File.open("#{confDir}/httpd.conf", 'w') do |file|
      file.puts lines
    end
  end
  not_if {::File.open("#{confDir}/httpd.conf").lines.any?{|line| line.include?("LoadModule was_ap22_module")}}
end


updateRequired = false

if ::File.exists?(plugincfg)
  updateRequired = ::FileUtils.compare_file(plugincfg, mergedFile) #returns true if the files are identical
  updateRequired = !updateRequired #so reverse it 
else
  updateRequired = true
end


bash "stop HTTP Server" do
  cwd binDir 
  code <<-EOH
  ./apachectl stop
  ./adminctl stop
  EOH
  only_if {updateRequired}
end

#bash "stop HTTP Admin" do #by default HTTP Admin is not configured and not run
#  cwd binDir 
#  code <<-EOH
#  ./adminctl stop
#  EOH
#  only_if {updateRequired}
#  ignore_failure true# TODO It is valid to run without adminctl at all; can this be handled more elegantly than trying and ignoring failures?
#end

bash "append httpd.conf" do
  cwd confDir
  code <<-EOH
  sed -i '/WebSpherePluginConfig/d' httpd.conf
  echo 'WebSpherePluginConfig #{confDir}/plugin-cfg.xml' >> httpd.conf
  EOH
  only_if {updateRequired}
end

bash "place new plugin-cfg" do
  cwd confDir
  code <<-EOH 
  cp #{mergedFile} #{plugincfg}
  echo #{mergedFile} >> /tmp/cheflog
  echo #{plugincfg}  >> /tmp/cheflog
  EOH
  only_if {updateRequired}
end
 

bash "start HTTP Server" do
  cwd binDir
  code <<-EOH
  ./apachectl start
  EOH
  only_if {updateRequired}
end

#bash "start HTTP Admin" do
#  cwd binDir
#  code <<-EOH
#  ./adminctl start
#  EOH
#  only_if {updateRequired}
#  ignore_failure true# TODO It is valid to run without adminctl at all; can this be handled more elegantly than trying and ignoring failures?
#end



