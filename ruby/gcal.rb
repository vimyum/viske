require 'rubygems'
require 'google/api_client'
require 'yaml'
require "optparse"
require "parsedate"

typeHash = {"1"=>"1", "2"=>"1", "3"=>"2", "4"=>"3", \
	"5"=>"3",  "6"=>"3",  "7"=>"4",  "8"=>"4", \
	"9"=>"4", "10"=>"5", "11"=>"5", "12"=>"5" }
colorHash = {"0"=>"1", "1"=>"2", "2"=>"3", "3"=>"5", "4"=>"7", "5"=>"10", "6"=>"11"}
vEventList = Array.new

ch = Hash.new

#Set default config
ch[:month]   = Time::now.month
ch[:year]    = Time::now.year
ch[:dir] = ENV['HOME'] + "/Schedule/"
ch[:tzone]   = "+0800"
ch[:afile]   = ENV['HOME'] + '/.google-api.yaml'
ch[:ofile]   = ch[:dir] + '/viskeGoogleCalendar'
ch[:lfile]   = ch[:dir] + '/.viskeGoogleCalendar.log'

#Set parameter analyzing
opts = OptionParser.new
opts.on("--insert") {|v| ch[:event] = "insert" } 
opts.on("--delete") {|v| ch[:event] = "delete" } 
opts.on("--list")   {|v| ch[:event] = "list" } 
opts.on("--month VAL")  {|v| 
	ch[:month] = v
} 
opts.on("--year  VAL")  {|v| 
	ch[:year] = v
} 
opts.on("--dir VAL")  {|v| 
	ch[:dir] = v
}
opts.on("--id VAL")  {|v| 
	ch[:id] = v
}
opts.on("--tzone VAL")  {|v| 
	ch[:tzone] = v
}
opts.on("--afile VAL")  {|v| 
	ch[:afile] = v
}
opts.on("--ofile VAL")  {|v| 
	ch[:ofile] = v
}
opts.on("--log VAL")  {|v| 
	ch[:lfile] = v
}
opts.on("--dlist VAL")  {|v| 
	ch[:dlist] = v
}

opts.parse!(ARGV)     

lfile = open(ch[:lfile], "a")
lfile.puts ch[:event] + Time.now.strftime(" start (%Y-%m-%d %H:%M) ")

if ch[:id] == nil
	lfile.puts "calendar ID is required."
	lfile.close
	return -1
end

if FileTest.exist?(ch[:afile]) == false
	lfile.puts "failed to find authorization file."
	lfile.put  ">google-api oauth-2-login --scope=https://www.googleapis.com/auth/calendar"
	lfile.puts "--client-id={ID} --client-secret={SEC}"
	lfile.close
	return -1
end

oauth_yaml = YAML.load_file(ch[:afile])
client = Google::APIClient.new
client.authorization.client_id = oauth_yaml["client_id"]
client.authorization.client_secret = oauth_yaml["client_secret"]
client.authorization.scope = oauth_yaml["scope"]
client.authorization.refresh_token = oauth_yaml["refresh_token"]
client.authorization.access_token = oauth_yaml["access_token"]

#if client.authorization.refresh_token && client.authorization.expired?
#	puts "refresh authorization file"
#	client.authorization.fetch_access_token!
#end

client.authorization.fetch_access_token!
service = client.discovered_api('calendar', 'v3')

if ch[:event] == "insert"
	id_Year   = 0
	id_Mon    = 1
	id_Day    = 2
	id_Start  = 3
	id_End    = 4
	id_Flag   = 5
	id_Msg    = 6
	id_RStart = 7
	id_REnd   = 8
	id_Id     = 9
	id_Desc   = 10

	puts "insert event start.."
	lines = fields = 0

	nbuff = []
	fname = ch[:dir] + ch[:year] + "_" + ch[:month] + ".dat"
	open(fname) {|file|
		while l = file.gets
			field = l.split('$$')
	 		
			if field[id_Id] != "0" 
				nbuff.push(l.strip)
				next
			end
			summary  = field[id_Msg]
			location = field[id_Msg].sub(/^.*@/,"")
			desc  = field[id_Desc]
			if desc == nil
				desc = ""
			end
			kind  = colorHash[field[id_Flag]]
			if field[id_Flag] == "6"
				stime = field[id_Year] + "-" + sprintf("%.2d",field[id_Mon].to_i) + "-" + sprintf("%.2d", field[id_Day].to_i)
				event = {
					'summary' => summary,
					'description' => desc,
					'location' => location,
					'start' => {'date' => stime },
					'end'   => {'date' => stime },
				}
			else
				stime = field[id_Year] + "-" + sprintf("%.2d",field[id_Mon].to_i) + "-" + 
					sprintf("%.2d", field[id_Day].to_i) + "T" + field[id_RStart] + ":00.000" + ch[:tzone]
				etime = field[id_Year] + "-" + sprintf("%.2d",field[id_Mon].to_i) + "-" + 
					sprintf("%.2d", field[id_Day].to_i) + "T" + field[id_REnd] + ":00.000" + ch[:tzone]
				event = {
					'summary' => summary,
					'colorId' => kind,
					'description' => desc,
					'location' => location,
					'start' => { 'dateTime' => stime },
					'end' => { 'dateTime' => etime },
				}
			end
			result = client.execute(:api_method => service.events.insert,
									:parameters => {'calendarId' => ch[:id]},
									:body => JSON.dump(event),
									:headers => {'Content-Type' => 'application/json'})
			newId = result.data.id
			if newId == nil
				lfile.puts "failed to update:" + summary
				p result
				p result.data
				newId = "0"
			end
			nl = l.scan(/(^(.*?\$\$){9})/)[0][0] + newId + "$$" + desc.strip
			nbuff.push(nl)
		end
	}
	f = open(fname, "w")
	nbuff.each {|e|
		f.puts e
	}
	f.close
end

if ch[:event] == "get"
	result = client.execute(:api_method => service.events.get,
							:parameters => {'calendarId' => 'XXX', 'eventId' => 'XXX'})
	print result.data.summary
end

if ch[:event] == "delete"
	if ch[:dlist] == nil
		lfile.puts "No task to be deleted."
		lfile.close
		return 0
	end
	dList = ch[:dlist].split(/\s*,\s*/)
	dList.each {|e|
		lfile.puts "delete '" + e +"'"
		result = client.execute(:api_method => service.events.delete,
								:parameters => {'calendarId' => ch[:id], 'eventId' => e})
	}
end

if ch[:event] == "list"
	lfile.puts "list events start.."
	minTime = ch[:year] + "-" +  ch[:month] + '-01T00:00:00.000-07:00'
	maxTime = ch[:year] + "-" +  ch[:month] + '-01T00:00:00.000-07:00'

	page_token = nil
	result = client.execute(:api_method => service.events.list,
							:parameters => { 'calendarId' => ch[:id], 'timeMin' => minTime})
	while true
		events = result.data.items
		events.each do |e|
			vEvent  = Hash.new
			lfile.puts e
			vEvent["id"]       = e.id ? e.id : "0"
			vEvent["summary"]  = e.summary ? e.summary : "NoTitle"
			vEvent["kind"]     = e.color_id ? typeHash[e.color_id] : 1
			vEvent["desc"]     = e.description ? e.description : ""
			vEvent["location"] = e.location ? "@" + e.location : ""

			if e.start.date != nil # whole day event
				sDateStr  = String::new(e.start.date) # String Class
				sary = ParseDate::parsedate(sDateStr)
				sTime = Time::local(*sary[0..-3]) 
				vEvent["sDay"]  = sTime.strftime("%d")  
				vEvent["sTime"] = sTime.strftime("00:00") 
				vEvent["kind"] = 6
			else 
				sTime = e.start.dateTime
				vEvent["sDay"]  = sTime.strftime("%d")  
				vEvent["sTime"] = sTime.strftime("%H:%M") 
			end
			if e.end.date != nil # whole day event
				vEvent["eDay"]  = vEvent["sDay"]
				vEvent["eTime"] = vEvent["sTime"]
			else
				eTime = e.end.dateTime
				vEvent["eDay"]  = eTime.strftime("%d")  
				vEvent["eTime"] = eTime.strftime("%H:%M") 
			end

			vEventList.push(vEvent)
		end
		if !(page_token = result.data.next_page_token)
			break
		end
		result = client.execute(:api_method => service.events.list, 
								:parameters => {'calendarId' => ch[:id], 'pageToken' => page_token})
	end
	f = open(ch[:ofile], "w")
	vEventList.each {|e|
		f.print ch[:year] + '$$' + ch[:month] + '$$' + e["sDay"] + '$$'
		f.print '0.0$$0.0$$' + e["kind"].to_s + '$$' + e["summary"] + '$$'
		f.print e["sTime"] + '$$' + e["eTime"] + '$$' + e["id"] + '$$'
		f.print e["desc"].strip + "\n"
	}
	f.close
end

lfile.close
