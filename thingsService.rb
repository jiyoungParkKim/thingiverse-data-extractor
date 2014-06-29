require 'logger'
require 'open-uri'
require 'open_uri_redirections'
require 'fileutils'
require 'mongo'
include Mongo

class ThingsService
  
  attr_accessor :db, :logger, :tv, :localPath 
  
  # Create the object
  def initialize(tv)
    dbName = "thingiverse"
    @localPath = "scade_files"
    mongoClient = MongoClient.new("localhost", 27017)
    @db = mongoClient.db(dbName)
    @logger = Logger.new(STDOUT)
    @logger.level = Logger::WARN
    @tv = tv
  end
  
  def insertThingsByTag(tag)
    
    index = 1
    totalPages = tag.things.total_pages
    puts "E : Exist thing, N : New thing, ! : Error, fe : file exist, nf : new file, ns : no scad file attached"
    for curPage in 1..totalPages
      
      things = tag.things(:page => curPage)
      print "[ page : #{curPage} = " 
      things.each{ |curThing| curThingId = curThing.id
       
        if thingExist?(curThingId)
          print " #{index}:E, "
        else
          if insertThing(curThingId)
            print " #{index}:N, "
          else
            print " #{index}:!, "
          end
        end   
        index = index + 1  
        
      }# end of each
      print " ]\n" 
    end
  end
  
  
  
  def insertThing(thingId)
    begin
      sleep 5
        thing = tv.things.find(thingId)
        insert(thing.attributes(),"things")
        t = insertAttrs("tags", thingId, thing.tags)
        c = insertAttrs("categories", thingId, thing.categories)
        f = insertAttrs("files", thingId, thing.files)
        i = insertAttrs("images", thingId, thing.images)
        downloadScadFiles(thing)
        if t && c && f && i
          return true
        else
          addFailedThing(thingId,"insertThing","error")
          return false
        end
    rescue Exception => e
      addFailedThing(thingId,"insertThing",e.message)
    end
  end
  
  #==================== dao =====================
  
  def thingExist?(thingId)
    coll = db.collection("things")
    coll.find("id" => thingId.to_i).count > 0
  end
  
  def imageExist?(thingId)
    coll = db.collection("images")
    coll.find("thing_id" => thingId.to_i).count > 0
  end
  
  # insert JSON object(Hash type) in the collection
  def insert(doc, tbName)
    coll = db.collection(tbName)
    return coll.insert(doc)
  end
  
  def delete(tbName, fieldName, value)
    coll = db.collection(tbName)
    coll.remove( fieldName => value )
  end
  
  def insertAttrs(tbName, thingid, dynamicAttrs)
    cnt = 0
    dynamicAttrs.each{|attr|
       attr.attributes["thing_id"] = thingid
       insert(attr.attributes, tbName)
       cnt = cnt + 1
    }
    if cnt == dynamicAttrs.size
      logger.debug(" all dynamicAttrs are stored for this thing!!! ")
    else
      addFailedThing(thingid,"insertAttrs",tbName)
      delete(tbName, "thing_id", thingid)
    end 
    return cnt == dynamicAttrs.size
  end
  
  def addFailedThing(thingid, type, desc)
    failedThings = db.collection("failedThings")
    failedThings.insert({ thing_id: thingid, type: type, desc: desc })
  end
 
  # =============== utils =====================
  
  def downloadScadFiles(thing)
    # create local path with thingid if not exist
    targetDir = "#{localPath}/#{thing.id}"
    # create local path with thingid
    FileUtils::mkdir_p targetDir
    if thing.files.size == 0
      print "ns" #no scade file exists
    end
    thing.files.each{ |f| 
      if f.name.end_with? 'scad'
        targetName = targetDir + "/" + f.name
        if !File.exist?(targetName)
          downloadFile(targetName, thing.id, f, 1)
          print "nf" #new file
        else
          print "fe" #file exists
        end
      end
    }
  end
  
  def downloadFile(targetName, thingid, f, tryCnt)
    begin
      @logger.debug( "try to download target #{f.name} : #{tryCnt} times")
      File.open(targetName, "wb") do |saved_file|
        open(f.public_url, :allow_redirections => :safe) do |read_file|
          saved_file.write(read_file.read)
        end
      end
      
    rescue Exception => e
      if tryCnt <= 5
        sleep(5)
        downloadFile(targetName, thingid,  f, tryCnt+1)
      else
        print " :!!: ", thingid , ":!!: ";
        addFailedThing(thingid,"downloadFile",e.message)
#        @logger.warn("#{thingid} : #{e.message}")
#        @logger.warn(e.backtrace.inspect)
      end
    end
  end
  
end
  
if __FILE__ == $0
  require 'thingiverse'
  tv = Thingiverse::Connection.new
  tv.access_token = 'your access token here'
  
  service = ThingsService.new(tv)
  
  tag = tv.tags().find("customizer")
  service.insertThingsByTag(tag)
  
end