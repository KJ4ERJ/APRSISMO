-- http://habitat.habhub.org/habitat/_design/payload_telemetry/_view/flight_payload_time?startkey=[%22833d6b76cc575e2ce2f109012b8e2423%22,%22833d6b76cc575e2ce2f109012b8bc71b%22,[]]&endkey=[%22833d6b76cc575e2ce2f109012b8e2423%22,%22833d6b76cc575e2ce2f109012b8bc71b%22]&include_docs=True&descending=True&limit=1

local M = {}

local json = require("json")
local toast = require("toast");
local APRS = require("APRS")
local APRSIS = require("APRSIS")
local osmTiles = require("osmTiles")
local stationList = require("stationList")

local verbose = false

local myConfig = nil
local myConfigChanged = nil

local balloons = {}
balloons['B-13'] = true
balloons['BUZZ'] = true
balloons['CHAV'] = true
balloons['PIE'] = true
balloons['SPEARS'] = true
balloons['ZURG'] = true

local chasers = {}
chasers["G7ALW"] = true
chasers["M6RPI"] = true
chasers["lohan"] = true
chasers["M6edf"] = true

local function notifyAPRS(what)
	if myConfig.StationID == 'KJ4ERJ-HB' then
		sendAPRSMessage("KJ4ERJ-12", what)
		sendAPRSMessage("G6UIM", what)
	end
end

local ignoring = {}
local function Ignore(who, why)
	if not ignoring[who] then
		local text = "Ignoring "..who.." "..tostring(why)

		if not myConfig.habitat then myConfig.habitat = {} end
		if not myConfig.habitat.notified then myConfig.habitat.notified = {} end
		for k,v in pairs(myConfig.habitat.notified) do
			if v == text then return end
		end

		myConfigChanged = text
		table.insert(myConfig.habitat.notified,text)

		toast.new(text)
		notifyAPRS(text)
		ignoring[who] = why
	end
end

local nonCurrents = {}

local function monitor(URL)
	print(os.date("%H:%M:%S").." Monitoring:"..URL.." config:"..type(myConfig))
	
	if nonCurrents[URL] then
		toast.new("Cancelling non-Current "..nonCurrents[URL])
		return "cancel"
	end

local function monitorListener( task, responseCode )
	if responseCode ~= 200 then
		print ( os.date("%H:%M:%S").." monitorListener:Network error:"..responseCode)
	else
		local body = task:getString()
		print(os.date("%H:%M:%S").." monitorListener:got:"..tostring(body))
		
		local success, values = pcall(json.decode, json, body)
		if not success then
			print('monitorListener:json.decode('..values..') on:'..body)
		elseif type(values) == 'table' then
			--print(printableTable('habitat', values))
			if type(values.rows) == 'table' then
				--print(printableTable('habitat.rows', values.rows, '\r\n'))
				if type(values.rows[1]) == 'table' then
					--print(printableTable('habitat.rows.1', values.rows[1], '\r\n'))
					if type(values.rows[1].key) == 'table' then
						--print(printableTable('habitat.rows.1.key', values.rows[1].key, '\r\n'))
					end
					if type(values.rows[1].doc) == 'table' then
						local doc = values.rows[1].doc
						--print(printableTable('habitat.rows.1.doc', doc, '\r\n'))
						if type(doc.data) == 'table' then
							local data = doc.data
							--print(printableTable('habitat.rows.1.doc.data', data, ' '))
							local parsed = nil
							local receivers = nil
							if type(data._parsed) == 'table' then
								--print(printableTable('habitat.rows.1.doc.data._parsed', data._parsed, ' '))
								parsed = data._parsed.time_parsed
							end
							if type(doc.receivers) == 'table' then
								--print(printableTable('receivers', doc.receivers, ' '))
								for k,v in pairs(doc.receivers) do
									print("Adding receiver:"..tostring(k))
									if receivers then receivers = receivers.." "..k else receivers = "via "..k end
									if type(v) == 'table' then
										--print(printableTable('receivers['..k..']', v, ' '))
										if type(v.rig_info) == 'table' then
											print(printableTable('receivers['..k..'].rig_info', v.rig_info, ' '))
										end
									end
								end
							else print("Type(receivers) is "..type(doc.receivers))
							end
							if not receivers then receivers = "from habitat.habhub.org" end
--[[
Table[habitat] = offset=144976.000 rows=table: 20D61350 total_rows=286306.000

Table[habitat.rows] =
1=table: 20D63920

Table[habitat.rows.1] =
doc=table: 20D5E3D0
id=126b869c213127bed6fe034d206f1b6174a2eff8ff59672d3e9de0f0da1cec48
key=table: 20D610D0

Table[habitat.rows.1.doc] =
_id=126b869c213127bed6fe034d206f1b6174a2eff8ff59672d3e9de0f0da1cec48
_rev=2-8d690d901a1948e09537a7d6e36dfdb4
data=table: 20D61620
receivers=table: 20D613A0
type=payload_telemetry

Table[habitat.rows.1.key] =
1=833d6b76cc575e2ce2f109012b8e2423
2=833d6b76cc575e2ce2f109012b8bc71b
3=1378996217.000

Table[habitat.rows.1.doc.data] =
_parsed=table: 20D61580
_protocol=UKHAS
_raw=JCRORzBYLDMzLDE0OjI5OjU5LDQ3MjAuMjQsLTA2NTAxLjAxLDE4ODIsMTIsOC42NiwzMSo2RQo=
_sentence=$$NG0X,33,14:29:59,4720.24,-06501.01,1882,12,8.66,31*6E

altitude=1882.000
battery=8.660
latitude=47.337
longitude=-65.017
payload=NG0X
satellites=12.000
sentence_id=33.000
temperature=31.000
time=14:29:59

toast.new:14:29:59[33]:NG0X at 47 20.2398N 065  1.0098W alt:1882
batt:8.66 sats:12 temp:31

Table[habitat.rows.1.doc.data._parsed] =
configuration_sentence_index=0.000
flight=833d6b76cc575e2ce2f109012b8e2423
payload_configuration=833d6b76cc575e2ce2f109012b8bc71b
time_parsed=2013-09-12T14:30:17Z

Table[habitat.rows.1.doc.receivers] =
WB8ELK-FARM=table: 20D617B0
Table[habitat.rows.1.doc.receivers[WB8ELK-FARM] ] =
latest_listener_information=437a48da4c305eb6d98ef0dd08619b01
rig_info=table: 20D61800
time_created=2013-09-12T09:30:17-05:00
time_server=2013-09-12T14:30:17Z
time_uploaded=2013-09-12T09:30:17-05:00
]]
							if parsed and parsed:sub(1,9) == '2013-09-1' then
								local latlon = FormatLatLon(tonumber(data.latitude), tonumber(data.longitude), 2, 0)
								local text = parsed:sub(6,-1).."["..tostring(data.sentence_id).."]:"..tostring(data.payload).." at "..latlon.." alt:"..tostring(data.altitude)
								text = text .."\r\nbatt:"..tostring(data.battery).." sats:"..tostring(data.satellites).." temp:"..tostring(data.temperature).." "..tostring(receivers)
								toast.new(text, 5000)
--[[
Table[habitat.rows.1.doc] =
_id=126b869c213127bed6fe034d206f1b6174a2eff8ff59672d3e9de0f0da1cec48
_rev=2-8d690d901a1948e09537a7d6e36dfdb4
data=table: 0B3906F0
receivers=table: 0B3918C0
type=payload_telemetry
Table[habitat.rows.1.doc.data] =
_parsed=table: 0B3909C0
_protocol=UKHAS
_raw=JCRORzBYLDMzLDE0OjI5OjU5LDQ3MjAuMjQsLTA2NTAxLjAxLDE4ODIsMTIsOC42Niwz
_sentence=$$NG0X,33,14:29:59,4720.24,-06501.01,1882,12,8.66,31*6E

altitude=1882.000
battery=8.660
latitude=47.337
longitude=-65.017
payload=NG0X
satellites=12.000
sentence_id=33.000
temperature=31.000
time=14:29:59

Table[habitat.rows.1.doc.data._parsed] =
configuration_sentence_index=0.000
flight=833d6b76cc575e2ce2f109012b8e2423
payload_configuration=833d6b76cc575e2ce2f109012b8bc71b
time_parsed=2013-09-12T14:30:17Z
]]
		
	local day = data._parsed.time_parsed:sub(9,10)
	local hour = data.time:sub(1,2)
	local minute = data.time:sub(4,5)

	local header = 'KJ4ERJ-15>APZLUA,TCPIP*:'
	local theader = data.payload:sub(1,6)..'>APZLUA,TCPIP*:'
	local packet = header..APRS:Object('HB-'..data.payload:sub(1,6), day, hour, minute, {lat=tonumber(data.latitude), lon=tonumber(data.longitude), alt=tonumber(data.altitude),
																	symbol='/O', comment=receivers})
	print (packet)
	if not myConfig.balloons then myConfig.balloons = {} end
	if not myConfig.balloons[data.payload] then myConfig.balloons[data.payload] = {} end
	if myConfig.balloons[data.payload].lastPacket ~= packet then
		if myConfig.StationID == 'KJ4ERJ-HB' then
			local status = APRSIS:sendPacket(packet)
			if status then toast.new("Transmit Failed with "..status)
			else toast.new("Transmitted: "..packet, 10000)
			end
		end
		stationList.packetReceived(packet)	-- put it on our local map
		myConfig.balloons[data.payload].lastPacket = packet
		myConfigChanged = data.payload
		osmTiles:moveTo(tonumber(data.latitude), tonumber(data.longitude))
	end
							else
								local payloadID
								if type(data._parsed) == 'table' then payloadID = data._parsed.payload_configuration else payloadID = "*unknown*" end
								print("Non-current data parsed "..tostring(parsed).." from "..tostring(payloadID))
								toast.new(tostring(data.payload).." non-current data parsed "..tostring(parsed).." from "..tostring(payloadID), 10000)
								nonCurrents[URL] = payloadID
							end
						end
					end
				end
			end
		else print('json.decode returned type('..type(values)..') for:'..body)
		end
	end
	if myConfigChanged then
		myConfig:save(myConfigChanged)
		myConfigChanged = nil
	end
end
	local task = MOAIHttpTask.new ()
	task:setVerb ( MOAIHttpTask.HTTP_GET )
	task:setUrl ( URL )
	task:setTimeout ( 15 )
	task:setCallback ( monitorListener )
	task:setUserAgent ( string.format('Habitat/APRS Gateway by KJ4ERJ') )
	task:setVerbose ( verbose )
	task:performAsync ()
end

local function flightListener( task, responseCode )
	if responseCode ~= 200 then
		print ( "flightListener:Network error:"..responseCode)
	else
		local body = task:getString()
		print("flightListener:got:"..tostring(#body).." bytes")
		
		local success, values = pcall(json.decode, json, body)
		if not success then
			print('flightListener:json.decode('..values..') on:'..body)
		elseif type(values) == 'table' then
			print(printableTable('habitat', values))
--[[
{"id":"93d58085b7075c11926419e9e48c7fab",
 "key":[1344596400,"93d58085b7075c11926419e9e48c7fab",0],
 "value":["c738aaaead0783259f149856f9af07ec"],
 "doc":
 {"_id":"93d58085b7075c11926419e9e48c7fab",
  "_rev":"2-ea992e1e3d732b80644379366a92689d",
  "type":"flight",
  "approved":true,
  "name":"Nova 23",
  "start":"2012-08-10T00:00:00+01:00",
  "end":"2012-08-10T23:59:59+01:00",
  "launch":
  {"time":"2012-08-10T12:00:00+01:00",
  
{"id":"93d58085b7075c11926419e9e48c7fab",
 "key":[1344596400,"93d58085b7075c11926419e9e48c7fab",1],
 "value":
 {"_id":"c738aaaead0783259f149856f9af07ec"},
  "doc":
  {"_id":"c738aaaead0783259f149856f9af07ec",
   "_rev":"1-d0c3fed5c2778ee6915b8fd498343ead",
   "type":"payload_configuration",
   "name":"JOEY v1",
   "time_created":"2012-08-08T21:30:36+01:00",
  
]]
			local flights = {}
			local payloads = {}
			local monitoring = {}
			if type(values.rows) == 'table' then
				--print(printableTable('habitat.rows', values.rows, '\r\n'))
				for k, row in ipairs(values.rows) do
				if type(row) == 'table' then
					if type(row.doc) == 'table' then
						local doc = row.doc
						--print(printableTable('doc', doc, '\r\n'))
						if doc.type == 'flight' then
							flights[doc._id] = doc
							print("Flight:"..tostring(doc.name).." Launch:"..tostring(doc.launch.time).." "..tostring(doc.start).." thru "..tostring(doc["end"]).." ID:"..tostring(doc._id))
						elseif doc.type == 'payload_configuration' then
							if type(payloads[row.id]) == 'nil' then payloads[row.id] = {} end
							payloads[row.id][doc._id] = doc
							print("Payload:"..tostring(flights[row.id].name)..":"..tostring(doc.name).." Created:"..tostring(doc.time_created).." IDs:"..tostring(row.id)..":"..tostring(doc._id))
							if balloons[doc.name] then
								if not monitoring[doc._id] then
									monitoring[doc._id] = true
									toast.new("Monitoring "..doc.name.." as "..doc._id)
									--local URL = 'http://habitat.habhub.org/habitat/_design/payload_telemetry/_view/flight_payload_time?startkey=[%22'..row.id..'%22,%22'..doc._id..'%22,[]]&endkey=[%22'..row.id..'%22,%22'..doc._id..'%22]&include_docs=True&descending=True&limit=1'
									local URL = 'http://habitat.habhub.org/habitat/_design/payload_telemetry/_view/payload_time?startkey=[%22'..doc._id..'%22,[]]&endkey=[%22'..doc._id..'%22]&include_docs=True&descending=True&limit=1'
									performWithDelay(30000, function () return monitor(URL) end, 0)
								end
							end
						else
							print("Unrecognized doc.type("..tostring(doc.type).."):"..printableTable('doc', doc, '\r\n'))
						end
					else print("No doc in "..printableTable('row['..tostring(k)..']', row, '\r\n'))
					end
				end
				end
			end
			if not monitoring["7d97e2fb70c7db945e22867a00a4e1f1"] then
				local forceid = "7d97e2fb70c7db945e22867a00a4e1f1"
				toast.new("Forcing "..forceid)
				local URL = 'http://habitat.habhub.org/habitat/_design/payload_telemetry/_view/payload_time?startkey=[%22'..forceid..'%22,[]]&endkey=[%22'..forceid..'%22]&include_docs=True&descending=True&limit=1'
				performWithDelay(30000, function () return monitor(URL) end, 0)
			end
		end
	end
end


local last_payload_key = 1379300000	-- Decent starting point
local function habitat()
	if myConfig and myConfig.habitat and myConfig.habitat.lastPayloadKey then
		last_payload_key = myConfig.habitat.lastPayloadKey
	end
	print(os.date("%H:%M:%S").." habitat Fetching From "..last_payload_key)
	local URL = "http://habitat.habhub.org/habitat/_design/payload_telemetry/_view/time?include_docs=True&limit=128&startkey="..tostring(last_payload_key)
	local function habitatListener( task, responseCode )
		local got_payload_key = nil
		if responseCode ~= 200 then
			print (os.date("%H:%M:%S").." habitat:Network error:"..responseCode)
		else
			local body = task:getString()
			print(os.date("%H:%M:%S").." habitat:got:"..tostring(#body).." bytes")
			local success, values = pcall(json.decode, json, body)
			if not success then
				print('habitat:json.decode('..values..') on:'..body)
			elseif type(values) == 'table' then

				if type(values.rows) == 'table' then
					local pending = {}
					--print(printableTable('habitat.rows', values.rows, '\r\n'))
					for k,row in pairs(values.rows) do
						if type(row) == 'table' then
							--print(printableTable('habitat.rows.'..tostring(k), row, '\r\n'))
							if type(row.key) ~= 'nil' then
								last_payload_key = row.key
								got_payload_key = row.key
								--print(printableTable('row.key', row.key, '\r\n'))
							end
							if type(row.doc) == 'table' then
								local doc = row.doc
								--print(printableTable('rows['..tostring(k)..'].doc', doc, '\r\n'))
								if type(doc.data) == 'table' then
									local data = doc.data
									local balloon = data.payload
									if #balloon > 1 and #balloon <= 6 then

									if not myConfig.balloons then myConfig.balloons = {} end
									if type(myConfig.balloons[balloon]) == 'nil' then
										myConfig.balloons[balloon] = {}
										myConfig.balloons[balloon].enabled = true
										text = "Auto-Tracking "..balloon
										toast.new(text)
										notifyAPRS(text)
									end
									if type(myConfig.balloons[balloon].enabled) == 'nil' then
										myConfig.balloons[balloon].enabled = true
										text = "Auto-Tracking "..balloon
										toast.new(text)
										notifyAPRS(text)
									end
									if myConfig.balloons[balloon].enabled then
										--print(printableTable('row.doc.data', data, ' '))
										local parsed = nil
										local receivers = nil
										if type(data._parsed) == 'table' then
											--print(printableTable('rows['..tostring(k)..'].doc.data._parsed', data._parsed, ' '))
											parsed = data._parsed.time_parsed
										end
										if type(doc.receivers) == 'table' then
											--print(printableTable('receivers', doc.receivers, ' '))
											for k,v in pairs(doc.receivers) do
												if type(v) == 'table' and type(v.rig_info) == 'table' then
													print("Adding receiver:"..tostring(k)..' freq:'..tostring(v.rig_info.frequency)..' audio:'..tostring(v.rig_info.audio_frequency)..' rev:'..tostring(v.rig_info.reversed))
												else print("Adding receiver:"..tostring(k))
												end
												if receivers then receivers = receivers.." "..k else receivers = "via "..k end
												if type(v) == 'table' then
													--print(printableTable('receivers['..k..']', v, ' '))
													if type(v.rig_info) == 'table' then
														--print(printableTable('receivers['..k..'].rig_info', v.rig_info, ' '))
													end
												end
											end
										else print("Type(receivers) is "..type(doc.receivers))
										end
										if not receivers then receivers = "from habitat.habhub.org" end
										if parsed and parsed:sub(1,5) >= '2013-' then	-- Don't go too far in the past!
											local latlon = FormatLatLon(tonumber(data.latitude), tonumber(data.longitude), 2, 0)
											local text = parsed:sub(6,-1).."["..tostring(data.sentence_id).."]:"..tostring(data.payload).." at "..latlon.." alt:"..tostring(data.altitude)
											text = text .."\r\nbatt:"..tostring(data.battery).." sats:"..tostring(data.satellites).." temp:"..tostring(data.temperature).." "..tostring(receivers)
											toast.new(text, 5000)
		
if tonumber(data.latitude) ~= 0 or tonumber(data.longitude) ~= 0 then
	local day = data._parsed.time_parsed:sub(9,10)
	local hour = data.time:sub(1,2)
	local minute = data.time:sub(4,5)

	local text
	if type(data.battery) ~= 'nil' then
		text = data.battery.."v "..receivers
	else text = receivers
	end
	local header = 'KJ4ERJ-15>APZLUA,TCPIP*:'
	local theader = balloon..'>APZLUA,TCPIP*:'
	local packet = header..APRS:Object('HB-'..balloon, day, hour, minute, {lat=tonumber(data.latitude), lon=tonumber(data.longitude), alt=tonumber(data.altitude),
																	symbol='/O', comment=text})
	pending[balloon] = packet
	print (packet)
	osmTiles:moveTo(tonumber(data.latitude), tonumber(data.longitude))
end

										else
											local payloadID
											if type(data._parsed) == 'table' then payloadID = data._parsed.payload_configuration else payloadID = "*unknown*" end
											print("Non-current data parsed "..tostring(parsed).." from "..tostring(payloadID))
											toast.new(tostring(data.payload).." non-current data parsed "..tostring(parsed).." from "..tostring(payloadID), 10000)
											nonCurrents[URL] = payloadID
										end
									else Ignore(balloon, "Non-Tracking Balloon")
									end
									else Ignore(balloon, "Balloon Name Too Long")
									end
								end
							end
						end
					end
					if myConfig then
						if not myConfig.habitat then myConfig.habitat = {} end
						if tostring(myConfig.habitat.lastPayloadKey) ~= tostring(last_payload_key) then
							print("habitat.lastPayloadKey changed from "..type(myConfig.habitat.lastPayloadKey).."("..tostring(myConfig.habitat.lastPayloadKey)..") to "..type(last_payload_key).."("..tostring(last_payload_key)..")")
							myConfig.habitat.lastPayloadKey = last_payload_key
							myConfigChanged = 'habitat.payloadkey'
						end
						--if values and type(values.rows) == 'table' and #values.rows == 1 then	-- Got just one
						if got_payload_key then	-- Got at least one
							if tostring(myConfig.habitat.lastPayloadKey) == tostring(got_payload_key) then	-- And it's the one we asked for
								if tonumber(got_payload_key) then	-- Must be numeric to add 1
									print("habitat.lastPayloadKey incrementing from "..type(myConfig.habitat.lastPayloadKey).."("..tostring(myConfig.habitat.lastPayloadKey)..") to "..type(got_payload_key).."("..tostring(tonumber(got_payload_key)+1)..")")
									myConfig.habitat.lastPayloadKey = tonumber(got_payload_key)+1
									myConfigChanged = 'habitat.payloadkey+1'
								else print("habitat's got_payload_key is "..type(got_payload_key).."("..tostring(got_payload_key)..")")
								end
							else print("habitat.lastPayloadKey is "..type(myConfig.habitat.lastPayloadKey).."("..tostring(myConfig.habitat.lastPayloadKey)..") now "..type(got_payload_key).."("..tostring(got_payload_key)..")")
							end
						end
					end

					for balloon, packet in pairs(pending) do
	if not myConfig.balloons then myConfig.balloons = {} end
	if not myConfig.balloons[balloon] then myConfig.balloons[balloon] = {} end
	if myConfig.balloons[balloon].lastPacket ~= packet then
		if myConfig.StationID == 'KJ4ERJ-HB' then
			local status = APRSIS:sendPacket(packet)
			if status then toast.new("Transmit Failed with "..status)
			else toast.new("Transmitted: "..packet, 10000)
			end
		end
		stationList.packetReceived(packet)	-- put it on our local map
		myConfig.balloons[balloon].lastPacket = packet
		myConfigChanged = 'Balloon('..balloon..')'
	end
					end

				end
			end
		end
		if myConfigChanged then
			myConfig:save(myConfigChanged)
			myConfigChanged = nil
		end
	end
	local task = MOAIHttpTask.new ()
	task:setVerb ( MOAIHttpTask.HTTP_GET )
	task:setUrl ( URL )
	task:setTimeout ( 15 )
	task:setCallback ( habitatListener )
	task:setUserAgent ( string.format('Habitat/APRS Gateway by KJ4ERJ') )
	task:setVerbose ( verbose )
	task:performAsync ()
end

local last_position_id = 0
local function spaceNearUS()
	if myConfig and myConfig.spaceNearUS and myConfig.spaceNearUS.lastPositionID then
		last_position_id = myConfig.spaceNearUS.lastPositionID
	end
	print(os.date("%H:%M:%S").." spaceNearUS Fetching From "..last_position_id)
	local URL = "http://spacenear.us/tracker/data.php?vehicles=&format=json&position_id="..tostring(last_position_id).."&max_positions=0"
	local function spaceNearUSListener( task, responseCode )
		if responseCode ~= 200 then
			print (os.date("%H:%M:%S").." spaceNearUSListener:Network error:"..responseCode)
		else
			local body = task:getString()
			print(os.date("%H:%M:%S").." spaceNearUSListener:got:"..tostring(#body).." bytes")
			local success, values = pcall(json.decode, json, body)
			if not success then
				print('spaceNearUSListener:json.decode('..values..') on:'..body)
			elseif type(values) == 'table' then
				if type(values.positions) == 'table' then
					if type(values.positions.position) == 'table' then
						local pending = {}
						for k,position in pairs(values.positions.position) do
							--print(printableTable('position['..tostring(k)..']', position))
--[[
Table[position[3287] ] = callsign= data= gps_alt=1697 gps_heading=344 gps_lat=40.466533 gps_lon=-4.966428 gps_speed=0 gps_time=2013-09-16 18:24:07 mission_id=0 picture= position_id=3268293 sequence= server_time=2013-09-16 18:24:09.568589 temp_inside= vehicle=M6RPI_chase
Table[position[3288] ] = callsign= data= gps_alt=1693 gps_heading=332 gps_lat=40.466382 gps_lon=-4.966328 gps_speed=0.2 gps_time=2013-09-16 18:24:13 mission_id=0 picture= position_id=3268294 sequence= server_time=2013-09-16 18:24:14.855447 temp_inside= vehicle=G7ALW_Chase
]]
							if position.vehicle:sub(-6,-1):lower() == "_chase" then
								print(printableTable('chase['..tostring(k)..']', position))
	local chaser = position.vehicle:sub(1,-7)
								if #chaser > 1 and #chaser <= 6 then
									if chasers[chaser] then
	local day = position.server_time:sub(9,10)
	local hour = position.server_time:sub(12,13)
	local minute = position.server_time:sub(15,16)
	local header = 'KJ4ERJ-15>APZLUA,TCPIP*:'
	local theader = chaser..'>APZLUA,TCPIP*:'
	local packet = header..APRS:Object('HC-'..chaser, day, hour, minute, {lat=tonumber(position.gps_lat), lon=tonumber(position.gps_lon), alt=tonumber(position.gps_alt),
																	symbol='/(', comment="via spacenear.us"})
	pending[chaser] = packet
	print (packet)
	osmTiles:moveTo(tonumber(position.gps_lat), tonumber(position.gps_lon))
									else Ignore(position.vehicle, "Non-Tracking Chaser")
									end
								else Ignore(position.vehicle, "Chaser Name Too Long")
								end
							else Ignore(position.vehicle, "Non-Chaser vehicle")
							end
							last_position_id = position.position_id
						end
						if myConfig then
							if not myConfig.spaceNearUS then myConfig.spaceNearUS = {} end
							if tostring(myConfig.spaceNearUS.lastPositionID) ~= tostring(last_position_id) then
								print("spaceNearUS.positionid changed from "..type(myConfig.spaceNearUS.lastPositionID).."("..tostring(myConfig.spaceNearUS.lastPositionID)..") to "..type(last_position_id).."("..tostring(last_position_id)..")")
								myConfig.spaceNearUS.lastPositionID = tostring(last_position_id)
								myConfigChanged = 'spaceNearUS.positionid'
							end
						end
						for chaser, packet in pairs(pending) do
	if not myConfig.chasers then myConfig.chasers = {} end
	if not myConfig.chasers[chaser] then myConfig.chasers[chaser] = {} end
	if myConfig.chasers[chaser].lastPacket ~= packet then
		if myConfig.StationID == 'KJ4ERJ-HB' then
			local status = APRSIS:sendPacket(packet)
			if status then toast.new("Transmit Failed with "..status)
			else toast.new("Transmitted: "..packet, 10000)
			end
		else print ("Pending:"..packet)
		end
		stationList.packetReceived(packet)	-- put it on our local map
		myConfig.chasers[chaser].lastPacket = packet
		myConfigChanged = 'Chaser('..chaser..')'
	end
						end
					end
				end
			end
		end
		if myConfigChanged then
			myConfig:save(myConfigChanged)
			myConfigChanged = nil
		end
	end
	local task = MOAIHttpTask.new ()
	task:setVerb ( MOAIHttpTask.HTTP_GET )
	task:setUrl ( URL )
	task:setTimeout ( 15 )
	task:setCallback ( spaceNearUSListener )
	task:setUserAgent ( string.format('Habitat/APRS Gateway by KJ4ERJ') )
	task:setVerbose ( verbose )
	task:performAsync ()
end
				
function M:start(config)
	myConfig = config
	print("habitat:Starting monitor! ("..type(myConfig)..")")
	
	if not myConfig.habitat then myConfig.habitat = {} end

	if not myConfig.balloons then myConfig.balloons = {} end
print("M:start:balloons = "..type(balloons).."("..tostring(balloons)..")")
	print(printableTable('myConfig.balloons(before)', myConfig.balloons))
	for k,v in pairs(balloons) do
		if not myConfig.balloons[k] then
			myConfig.balloons[k] = {}
			myConfig.balloons[k].enabled = true
		end
	end
	print(printableTable('myConfig.balloons(after)', myConfig.balloons))

--[[
	if not myConfig.habitat.balloons then myConfig.habitat.balloons = {} end
	if not myConfig.habitat.chasers then myConfig.habitat.chasers = {} end
	if not myConfig.habitat.notify then myConfig.habitat.notify = {} end
	table.insert(myConfig.habitat.notify,'G6UIM')
	table.insert(myConfig.habitat.balloons,'B-13')
	table.insert(myConfig.habitat.balloons,'BUZZ')
	table.insert(myConfig.habitat.balloons,'CHAV')
	table.insert(myConfig.habitat.balloons,'PIE')
	table.insert(myConfig.habitat.balloons,'SPEARS')
	table.insert(myConfig.habitat.balloons,'ZURG')
	table.insert(myConfig.habitat.chasers,'G7ALW')
	table.insert(myConfig.habitat.chasers,'M6RPI')
	table.insert(myConfig.habitat.chasers,'lohan')
]]
	--table.insert(myConfig.habitat.balloons, {name="B-12", enabled="true", last=0})
--	print(printableTable('habitat.balloons', myConfig.habitat.balloons))
--	print(printableTable('balloons[7]', myConfig.habitat.balloons[7]))
--	print(printableTable('chasers', myConfig.habitat.chasers))
--	print(printableTable('notify', myConfig.habitat.notify))
--	myConfig:save('Testing...')
	
--	local URL = 'http://habitat.habhub.org/habitat/_design/payload_telemetry/_view/flight_payload_time?startkey=[%22833d6b76cc575e2ce2f109012b8e2423%22,%22833d6b76cc575e2ce2f109012b8bc71b%22,[]]&endkey=[%22833d6b76cc575e2ce2f109012b8e2423%22,%22833d6b76cc575e2ce2f109012b8bc71b%22]&include_docs=True&descending=True&limit=1'
--	performWithDelay(30000, function () return monitor(URL) end, 0)
--	monitor(URL)

--[[
	URL = 'http://habitat.habhub.org/habitat/_design/flight/_view/launch_time_including_payloads?include_docs=True&limit=1000'
	local task = MOAIHttpTask.new ()
	task:setVerb ( MOAIHttpTask.HTTP_GET )
	task:setUrl ( URL )
	task:setTimeout ( 15 )
	task:setCallback ( flightListener )
	task:setUserAgent ( string.format('Habitat/APRS Gateway by KJ4ERJ') )
	task:setVerbose ( verbose )
	task:performAsync ()
]]
	
	performWithDelay(10000, habitat, 0)
	performWithDelay(10000, spaceNearUS, 0)
end

return M
