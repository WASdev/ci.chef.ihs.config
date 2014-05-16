module MergeXML

class UriGroup
  attr_reader :oldName, :childURIs, :name, :included

  def initialize(node)
    @included = false 

    @oldName = node["Name"]
 
    @childURIs = Array.new
    uris = node.xpath("./Uri")
    uris.each do |u|
      uri = Uri.new(u)
      @childURIs << uri
    end
    

    tmp = ::Array.new
    @childURIs.each do |u|
      tmp << u.name.gsub(/[^0-9a-zA-Z]/i, '_')
    end
    @name = tmp.sort!.join(' ')

    tmp2 = node.attributes() 
    tmp2.delete("Name")
    @attrs = tmp2
  end

  def is_included?
    return @included
  end

  def include!
    @included = true
  end

  def is_different?(otherUriGroup)

    if not @childURIs.length == otherUriGroup.childURIs.length then return true end

    childrenOne = ::Array.new
    childrenTwo = ::Array.new

    @childURIs.each do |c| 
      childrenOne << c.name
    end
    childrenOne.sort!
 
    otherUriGroup.childURIs.each do |c| 
      childrenTwo << c.name
    end
    childrenTwo.sort!

    if childrenOne.eql?(childrenTwo) then return false else return true end
    
  end
  
  def to_xml_string 
    xmlAttrs = @attrs.map{|k,v| "#{k}=\"#{v}\""}
    xmlAttrs2 = xmlAttrs.join(' ')


    childNodes = ::Array.new
    @childURIs.each{|child| childNodes << child.to_xml_string}
    childNodes2 = childNodes.join(' ')
    xml = "<UriGroup Name=\"#{@name}\" #{xmlAttrs2} > \n"+
          "#{childNodes2} \n"+
          "</UriGroup>"
    return xml
  end
end

class Uri
  attr_reader :name

  def initialize(node)
    @name = node["Name"]
    tmp = node.attributes() 
    tmp.delete("Name")
    @attrs = tmp
  end
  
  def to_xml_string 
    xmlAttrs = @attrs.map{|k,v| "#{k}=\"#{v}\""}
    xmlAttrs2 = xmlAttrs.join(' ')
    xml = "<Uri Name=\"#{@name}\" #{xmlAttrs2} />"
    return xml
  end
end

class Route
   attr_reader :oldServerCluster, :oldUriGroup, :oldVirtualHostGroup
   attr_accessor :serverCluster, :uriGroup, :virtualHostGroup

   def initialize(node, serverCluster, uriGroup)
     @oldServerCluster = node["ServerCluster"]
     @oldUriGroup = node["UriGroup"]
     @oldVirtualHostGroup = node["VirtualHostGroup"]

     @serverCluster = serverCluster
     @uriGroup = uriGroup
     @virtualHostGroup = "default_host"
   end

   def to_xml_string 
      xml = "<Route ServerCluster=\"#{@serverCluster.name}\" UriGroup=\"#{@uriGroup.name}\" VirtualHostGroup=\"#{@virtualHostGroup}\"  />"
      return xml
   end
end

class ServerCluster
  attr_reader :name, :oldName, :included, :apps
  attr_accessor :servers

  def initialize(node)
    @included = false
    @apps = ::Set.new
 
    @oldName = node["Name"]
    tmp = node.attributes() 
    tmp.delete("Name")
    @attrs = tmp  
    
    serverList = Array.new
    servers = node.xpath("./Server")
    servers.each do |s|
       ser = Server.new(s)
       serverList << ser
    end
    @servers = serverList   

    self.update_name!
  end

  def update_name!
    servers = ::Array.new
    @servers.each do |s|
      servers << s.name
    end
    servers.sort!

    apps = ::Array.new 
    @apps.each do |a|
      apps << a.gsub(/[^0-9a-zA-Z]/i, '')
    end
    apps.sort!

    @name = servers.join('_') + "_" + apps.join('_')
  end

  def is_different?(otherServerCluster)
    myAppNames = ::Set.new
    otherAppNames = ::Set.new

    @apps.each do |app|
      myAppNames << app
    end
   
    otherServerCluster.apps.each do |app|
      otherAppNames << app
    end


    if myAppNames == otherAppNames
      return false
    else
      return true
    end
  end

  def add_app!(app)
    @apps << app
    update_name!
  end

  def merge!(otherServerCluster)
  
    otherServerCluster.servers.each do |newServer|
      found = false
      @servers.each do |inServer|
        if newServer.name == inServer.name then found = true end
      end
      if not found then servers << newServer end
    end
    self.update_name!
  end

  def is_included?
    return @included
  end

  def include!
    @included = true
  end

  def to_xml_string 
    xmlAttrs = @attrs.map{|k,v| "#{k}=\"#{v}\""}
    xmlAttrs2 = xmlAttrs.join(' ')
    childNodes = ::Array.new 
    childNodes << ""
    @servers.each{|child| childNodes << child.to_xml_string}
    childNodes2 = childNodes.join(' ')
    xml = "<ServerCluster Name=\"#{@name}\" #{xmlAttrs2}> \n"+
          "#{childNodes2}"+
          "\n </ServerCluster>"
    return xml
  end
end

class Server
  attr_reader :name

  def initialize(node)
    @oldName = node["Name"]
    
    tmp = node.attributes() 
    tmp.delete("Name")
    @attrs = tmp      

    tmp2 = ::Array.new
    trans = node.xpath("./Transport")
    trans.each do |t|
      tmp2 << t["Hostname"]
    end
    @name = tmp2.sort!.join(' ')
    @children = trans 
  end

  def to_xml_string 
  xmlAttrs = @attrs.map{|k,v| "#{k}=\"#{v}\""}
  xmlAttrs2 = xmlAttrs.join(' ')
  
  childNodes = ::Array.new
  childNodes << ""
  @children.each do |c|
    childNodes << c.to_s
  end

  xml = "<Server Name=\"#{@name}\" #{xmlAttrs2}> \n"+
        "#{childNodes.join(' ')}"+
        "</Server>"
    return xml
  end
end

def self.mergeXML(filepath1, filepath2, outputFile, chefNode)
    require 'nokogiri'
    require 'tempfile'
    file1 = File.open(filepath1)
    docOne = Nokogiri::XML(file1)
    file1.close 

    file2 = File.open(filepath2)
    docTwo = Nokogiri::XML(file2)
    file2.close 


   #Build the server objects
   
 
   serverClustersOne = ::Array.new
   serverClusters = docOne.xpath("/Config/ServerCluster")
   serverClusters.each do |sc|
     newSC = ServerCluster.new(sc)
     serverClustersOne << newSC
   end
   
   serverClustersTwo = ::Array.new
   serverClusters = docTwo.xpath("/Config/ServerCluster")
   serverClusters.each do |sc|
     newSC = ServerCluster.new(sc)
     serverClustersTwo << newSC
   end


   #Build the URI Group objects

   uriGroupsOne = ::Array.new
   uriGroups = docOne.xpath("/Config/UriGroup")
   uriGroups.each do |ug|
     newUG = UriGroup.new(ug)
     uriGroupsOne << newUG unless newUG.childURIs.empty?
   end
   
   uriGroupsTwo = ::Array.new
   uriGroups = docTwo.xpath("/Config/UriGroup")
   uriGroups.each do |ug|
     newUG = UriGroup.new(ug)
     uriGroupsTwo << newUG unless newUG.childURIs.empty?
   end

   #build the routes
   routesOne = ::Array.new
   routesDocOne = docOne.xpath("/Config/Route")
   routesDocOne.each do |route|

     newRouteUriGroup = nil
     newRouteserverCluster = nil
     
     uriGroupsOne.each do |ug|
       done = false
       tmp = route["UriGroup"]
       if tmp == ug.oldName and not done
         newRouteUriGroup = ug
         done = true
       end
     end
     
     serverClustersOne.each do |sc|
       done = false
       tmp = route["ServerCluster"]
       if tmp == sc.oldName and not done
         newRouteserverCluster = sc
         done = true
       end
     end
   
     if not newRouteserverCluster.nil? and not newRouteUriGroup.nil?
       newRoute = Route.new(route, newRouteserverCluster, newRouteUriGroup)
       routesOne << newRoute
     end
   end



   routesTwo = ::Array.new
   routesDocTwo = docTwo.xpath("/Config/Route")
   routesDocTwo.each do |route|

     newRouteUriGroup = nil
     newRouteserverCluster = nil
    
     uriGroupsTwo.each do |ug|
       done = false
       tmp = route["UriGroup"]
       if tmp == ug.oldName and not done
         newRouteUriGroup = ug
         done = true
       end
     end

     serverClustersTwo.each do |sc|
       done = false
       tmp = route["ServerCluster"]
       if tmp == sc.oldName and not done
         newRouteserverCluster = sc
         done = true
       end
     end
     
     if not newRouteserverCluster.nil? and not newRouteUriGroup.nil?
       newRoute = Route.new(route, newRouteserverCluster, newRouteUriGroup)
       routesTwo << newRoute 
     end
   end

   #ServerClusters will be merged if they have the same apps, so the routes shall be used to record apps in the server object.

   routesOne.each do |route|
     route.uriGroup.childURIs.each do |uri|
       route.serverCluster.add_app!(uri.name)
     end
   end

   routesTwo.each do |route|
     route.uriGroup.childURIs.each do |uri|
       route.serverCluster.add_app!(uri.name)
     end
   end
 

   ################# 
   #Now start the merging. 

   #Start with the servers
   #Server clusters will be merged if the names are the same, and the name is a sorted combination of all the hostnames in the cluster
   #As always the first file shall dominate. 
   serverClustersCombined = ::Array.new
   

   serverClustersOne.each do |newSC|
     found = false

     if serverClustersCombined.empty?
       serverClustersCombined << newSC
       newSC.include!
       next
     end

     serverClustersCombined.each do |inSC|
       if not newSC.is_different?(inSC) 
         found = true
         inSC.merge!(newSC)
       end 
     end
     if not found
      serverClustersCombined << newSC 
      newSC.include! 
     end
   end
   
   serverClustersTwo.each do |newSC|
     found = false

     if serverClustersCombined.empty?
       serverClustersCombined << newSC
       newSC.include!
       next
     end

     serverClustersCombined.each do |inSC|
       if not newSC.is_different?(inSC) 
         found = true
         inSC.merge!(newSC)
       end
     end
     if not found
      serverClustersCombined << newSC 
      newSC.include! 
     end
   end
   #######

   #next do the URIGroups
   #URIGroups will be merged if the names of all child URI's are the same.
   #As always the first file shall dominate. 

   uriGroupsCombined = ::Array.new
   
   uriGroupsOne.each do |newURI|
     if uriGroupsCombined.empty?
       uriGroupsCombined << newURI
       newURI.include!
       next
     end

     found = false
     uriGroupsCombined.each do |inURI|
       if not newURI.is_different?(inURI)
         found = true
       end
     end

     if not found     
       uriGroupsCombined << newURI
       newURI.include!
     end
   end

   uriGroupsTwo.each do |newURI|
     if uriGroupsCombined.empty?
       uriGroupsCombined << newURI
       newURI.include!
       next
     end

     found = false
     uriGroupsCombined.each do |inURI|
       if not newURI.is_different?(inURI)
         found = true
       end
     end

     if not found     
       uriGroupsCombined << newURI
       newURI.include!
     end
   end

   

   ##############
   # Merge the route objects. 
   # Rout objects will be the same if all three peramaters are the same. 

   routesCombined = ::Array.new

   routesOne.each do |newR|
     found = false
 
     if routesCombined.empty?
       routesCombined << newR
       next
     end

     routesCombined.each do |inR|
       if newR.uriGroup.name == inR.uriGroup.name and newR.serverCluster.name == inR.serverCluster.name
         found = true 
       end
     end
     if not found and newR.uriGroup.included and newR.serverCluster.included
       routesCombined << newR 
     end
   end

   routesTwo.each do |newR|
     found = false

     if routesCombined.empty?
       routesCombined << newR
       next
     end

     routesCombined.each do |inR|
       if newR.uriGroup.name == inR.uriGroup.name and newR.serverCluster.name == inR.serverCluster.name
         found = true 
       end
     end
     if not found and newR.uriGroup.included and newR.serverCluster.included
       routesCombined << newR 
     end
   end


############### Build the XML


    builder = Nokogiri::XML::Builder.new do
      Config {
      }
    end

    docCombined = Nokogiri::XML(builder.to_xml) do |config|
      config.default_xml.noblanks
    end

    rootAttr = docOne.xpath("/Config").first.attributes
    xmlNode = docCombined.at("Config")
    rootAttr.each do |name, value| 
      xmlNode[name] = value
    end

    #Copy the <Log> element from any of the two merging files, and modify the Path/Name, if required. 
    
    logAttr = docOne.xpath("/Config/Log").first
    docCombined.at("Config").add_child(logAttr)

    if not chefNode[:logPath].nil?
      docCombined.xpath("/Config/Log").first["Name"] = chefNode[:logPath]
    end

    #Copy properties like esiEnable and esiMaxCacheSize from any of the two merging files.

    propertyList = docOne.xpath("/Config/Property")
    propertyList.each do |prop|
      docCombined.at("Config").add_child(prop)
    end    

    #For this cookbook we will have all the servers in one virtual host group. In practice this means that the DMZ can only serve one domain. 

    ports = chefNode[:ports]
 

    virtualHostFragment = '<VirtualHostGroup Name="default_host"> '
    ports.each do |port|
      vhost = '<VirtualHost Name="' + chefNode[:hostname]+':'+port+'"/>'
      virtualHostFragment << vhost
    end
    

    virtualHostFragment << '</VirtualHostGroup>' 
    
    newNodes = ::Array.new
 
    newNodes << virtualHostFragment    

    serverClustersCombined.each do |newNode| 
      newNodes <<  newNode.to_xml_string
    end

    uriGroupsCombined.each do |newNode| 
      newNodes << newNode.to_xml_string
    end

    routesCombined.each do |newNode|
      newNodes <<  newNode.to_xml_string
    end

    newNodes.each do |newNode|
       docCombined.at("Config").add_child(newNode)
    end

   tmp = Tempfile.new('mergedFile') #I'm sure there's a better way to pretty print XML, but hanven't been able to find it.

    
   File.open(tmp,'w') do |file|
     file.truncate(0) 
     file.puts(docCombined.to_xml(:indent => 2))
   end 

   tempXML = ""
   File.open(tmp,'r') do |file|
     tempXML = file.read
   end 

   finalXML = Nokogiri.XML(tempXML) do |config|
      config.default_xml.noblanks
   end

   
   File.open(outputFile,'w') do |file|
     file.truncate(0) 
     file.puts(finalXML.to_xml(:indent => 2))
   end 

end

  

end
