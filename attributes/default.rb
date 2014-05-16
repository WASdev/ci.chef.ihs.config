# Cookbook Name:: DMZIHSLiberty
# Attributes:: default
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and

#<> Where to find the front end IBM HTTP Server. If left to nil then this will fall back to [:ihs][:paths][:install]. If you wish to run configihs One of the two variables __must__ be set. 
default[:DMZIHSLiberty][:frontEnd][:IHS][:baseDir] = nil

#<> Where to find the Web Server Plug-ins for IBM WebSphere Application Server V8.5. If left to nil then this will fall back to [:ihs][:paths][:plugins]. If you wish to run configihs one of the two variables __must__ be set. 
default[:DMZIHSLiberty][:frontEnd][:IHS][:pluginBaseDir] = nil

#<> The location of tools.jar on the liberty servers, this is needed to generate plugin-cfg.xml. As an alternative you can put a copy of tools.jar into the DMZIHSLiberty/files/defualt directory and leave this peramater as nil. 
default[:DMZIHSLiberty][:backEnd][:java][:toolsPath] = nil

#<> How the liberty servers should search for the front end IBM HTTP Server. This must be set on the back end. TODO, examples would be good here
default[:DMZIHSLiberty]["backEnd"]["findGateway"]["pattern"] = nil
default[:DMZIHSLiberty]["backEnd"]["findGateway"]["networkInterface"] = "eth0"

#<> The reponse file and optionally a secure storage file for install manager to install IHS

default[:DMZIHSLiberty][:frontEnd][:IHS][:install][:responseFile] = nil
default[:DMZIHSLiberty][:frontEnd][:IHS][:install][:secureStorageFile] = nil

#<> The back end liberty servers require the ability to SSH to the front end. !Warning, this recipy can use SSH usernames and passwords, this is NOT recommended. 

default[:DMZIHSLiberty][:backEnd][:SSH][:username] = nil
default[:DMZIHSLiberty][:backEnd][:SSH][:password] = nil
default[:DMZIHSLiberty][:backEnd][:SSH][:supressUnkownHostsWarning] = "true"

default[:DMZIHSLiberty][:backEnd][:SSH][:override] = nil # if not nil, a custom SSH string will be used.


#<> Peramaters to override settings in the final config-xml these should be set on the front end server
default[:DMZIHSLiberty][:frontEnd][:plugincfg][:logPath] = nil
default[:DMZIHSLiberty][:frontEnd][:plugincfg][:hostname] = "*"
default[:DMZIHSLiberty][:frontEnd][:plugincfg][:ports] = ["80", "443"]











