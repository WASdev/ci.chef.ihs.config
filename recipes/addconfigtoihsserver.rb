#
# Cookbook Name:: DMZIHSLiberty
# Recipe:: default
#
# Copyright 2014, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

require 'tmpdir'
require 'socket'
require 'tempfile'

class Chef::Recipe
  include MergeXML
end
  
  chef_gem 'nokogiri'

  jardir = Dir.mktmpdir
  cfgdir = Dir.mktmpdir

  include_recipe "java"

  cookbook_file "tools.jar" do
  path "#{jardir}/tools.jar"
  owner "root"
  group "root"
  action :create
  only_if {node[:DMZIHSLiberty][:backEnd][:java][:toolsPath].nil?}
  ignore_failure true
  end

  #I found that the previous block was creating 0k tools.jar if it wasn't in the cookbook. Since that's a valid setup, remove anything smaller than 2k. 
  bash "cleanup" do
  cwd jardir
  code <<-EOH 
  find . -size -2k -delete    
  EOH
  end
  
  cookbook_file "ws-generatepluginconfig.jar" do 
  path "#{jardir}/ws-generatepluginconfig.jar"
  owner "root"
  group "root"
  action :create
  end

  #For reasons I cannot explain, this will not work with the command syntax
  ruby_block "create plugin-cfg.xml" do 
    block do
    
      toolsPath = ""

      #Find tools.jar
      if not node[:DMZIHSLiberty][:backEnd][:java][:toolsPath].nil?
        toolsPath = node[:DMZIHSLiberty][:java][:toolsPath]
      elsif File.file?("#{jardir}/tools.jar")
        toolsPath = "#{jardir}/tools.jar"
      elsif
        commonToolsLocations = ["/usr/lib/jvm/java-6-ibm-i386/lib/tools.jar","/usr/lib/jvm/java-6-ibm-x86/lib/tools.jar","/usr/lib/jvm/java-6-ibm-amd64/lib/tools.jar"]#If precidence matters, put the best paths last
        commonToolsLocations.each do |filePath|
          if File.file?(filePath)
            toolsPath = filePath
          end
        end
      end
      
      if toolsPath.to_s == ""
         raise "Couldn't find tools.jar, you can specify it's location in the node.conf or place a copy in the files directory of this cookbook" 
      end

     jcommand = "java -cp #{jardir}/ws-generatepluginconfig.jar:#{toolsPath} com.logicali.wlp.tools.plugincfg.Main --outputDir=#{cfgdir}"
     stdin, stdout, stderr, wait_thr = ::Open3.popen3(jcommand)
     raise "failed to create plugin-cfg.xml: #{stderr.read}" unless wait_thr.value == 0 
      
    end
  end 

  apt_package "sshpass" do 
  action :install 
  not_if {node[:DMZIHSLiberty][:backEnd][:SSH][:password].nil?}
  end

  
  ruby_block "transfer plugin-cfg files to front end server" do
    block do
      #Merge I decided to do all the merging on the front end server

      #mergedFilePrime = Tempfile.new('mergedFile')
      #mergedFilePrime.write(".")#force file creation, it will be overwritten later. 
      #mergedFile = mergedFilePrime.path
      #mergedFilePrime.close()
      #unmergedFiles = []


      #Dir.chdir(cfgdir)
      #Dir.glob('**/*.xml').each do |item|
      #  next if item == '.' or item == '..'
      #    unmergedFiles << item
      #  end


      #merge the files
      #First merge the first two files. #TODO handle the case where there are 0 or 1 files
      #MergeXML.mergeXML(unmergedFiles[0], unmergedFiles[1], "server1", "server2", mergedFile, node[:DMZIHSLiberty][:frontEnd][:plugincfg])

      #next merge any additional files into the previous merged file. 
      #i = 2
      #while i <  unmergedFiles.length do
      #   serverNo = i+1 
      #   MergeXML.mergeXML(mergedFile, unmergedFiles[i], nil, "server#{serverNo.to_s}", mergedFile, node[:DMZIHSLiberty][:frontEnd][:plugincfg])
      #   i += 1
      #end  
 
      #Transfer the result

      cfgCount = 0
      cfgFiles = []

      Dir.chdir(cfgdir)
      Dir.glob('**/*.xml').each do |item|
        next if item == '.' or item == '..'
          cfgFiles << item
        end

      frontEndIPs = []

      frontEndSearchPattern = node[:DMZIHSLiberty][:backEnd][:findGateway][:pattern]
      frontEndInterface = node[:DMZIHSLiberty][:backEnd][:findGateway][:networkInterface]
      frontEndServers = search(:node, frontEndSearchPattern)


      frontEndServers.each do |frontEndServer|              #this one should not start with a :
         frontEndIPs <<  frontEndServer["network"]["interfaces"][frontEndInterface]["addresses"].select{|address, data| data["family"] == "inet"}.keys[0]    
      end

      frontEndIPs.each do |ip|
    
        if not node[:DMZIHSLiberty][:backEnd][:SSH][:override].nil? 
          sshSnippet = node[:DMZIHSLiberty][:backEnd][:SSH][:override]

     	  %x(#{sshSnippet} #{ip} 'sudo mkdir -p /tmp/plgin-cfgs')
          cfgFiles.each do |cfgFile|     
	    %x(cat #{cfgFile} | #{sshSnippet} #{ip} 'sudo tee /tmp/plgin-cfgs/#{node['fqdn']}_#{cfgCount.to_s}.xml')
            cfgCount += 1
          end

        elsif not node[:DMZIHSLiberty][:backEnd][:SSH][:password].nil? 
	  usernameSnippet = ""
	  passwordSnippet = node[:DMZIHSLiberty][:backEnd][:SSH][:password]
	  supressionSnippet = ""

	  if not node[:DMZIHSLiberty][:backEnd][:SSH][:username].nil? 
	    usernameSnippet = "#{node[:DMZIHSLiberty][:backEnd][:SSH][:username]}@"
	  end

	  if node[:DMZIHSLiberty][:backEnd][:SSH][:supressUnkownHostsWarning] 
	    supressionSnippet = "-o StrictHostKeyChecking=no"
	  end

	  %x(sshpass -p #{passwordSnippet} ssh #{usernameSnippet}#{ip} #{supressionSnippet} 'sudo mkdir -p /tmp/plgin-cfgs')
	  cfgFiles.each do |cfgFile|     
            %x(cat #{cfgFile} | sshpass -p #{passwordSnippet} ssh #{supressionSnippet} #{usernameSnippet}#{ip} 'sudo tee /tmp/plgin-cfgs/#{node['fqdn']}_#{cfgCount.to_s}.xml' )
            cfgCount +=1
          end

        else 
	  usernameSnippet = ""
	  supressionSnippet = ""

	  if not node[:DMZIHSLiberty][:backEnd][:SSH][:username].nil? 
	    usernameSnippet = "#{node[:DMZIHSLiberty][:backEnd][:SSH][:username]}@"
	  end

	  if node[:DMZIHSLiberty][:backEnd][:SSH][:supressUnkownHostsWarning] 
	    supressionSnippet = "-o StrictHostKeyChecking=no"
	  end

	  %x(ssh #{usernameSnippet}#{ip} #{supressionSnippet} 'sudo mkdir -p /tmp/plgin-cfgs')
          cfgFiles.each do |cfgFile|
	    %x(cat #{cfgFile} | ssh #{supressionSnippet} #{usernameSnippet}#{ip} 'sudo tee /tmp/plgin-cfgs/#{node['fqdn']}_#{cfgCount.to_s}.xml' )
            cfgCount +=1
          end
	end
      end
    end 
  end


