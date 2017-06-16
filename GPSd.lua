local GPSd = { VERSION = "0.0.1" }

local toast = require("toast");

--	Forward references for callbacks

local config

local locationCounter = 0
local connectRunning = false

function GPSd:start(useConfig)
	print('GPSd:start('..tostring(useConfig)..')')
	config = useConfig
	performWithDelay(500,function() GPSd:connect() end)
	if not connectRunning then performWithDelay(60000,function() GPSd:connect() end,0) end
end

function GPSd:stop()
	GPSd:close()
end

local GPSdSocket, NMEAs = nil, {}
--local ltn12 = require("ltn12")
local json = require("json")

function GPSd:close()
	if GPSdSocket then
		GPSdSocket:close()
		GPSdSocket = nil
	end
end

local function flushGPSd()
	if GPSdSocket then
		repeat
			local line, err = GPSdSocket:receive('*l')
			if line then
--print ('GPSd:'..line)
				if line:sub(1,1) == '$' then	-- NMEA data
					local s, e, NMEA = line:find('^$(.-),')
					if NMEA then
						if not NMEAs[NMEA] then
							print('GPSd:NMEA('..NMEA..') Received')
							NMEAs[NMEA] = 0
						end
						NMEAs[NMEA] = NMEAs[NMEA] + 1
					--print("GPSd:NMEA:"..line)
					else print("GPSd:NMEA:"..line)
					end
				else
					local success, values = pcall(json.decode, json, line)
					if not success then
						print('GPSd:json.decode('..values..') on:'..line)
					--local values = json:decode(line)
					elseif type(values) == 'table' then
						--print(printableTable('GPSd', values))
						if values.class == 'SKY' then
--Table[GPSd] = time=2013-06-28T18:38:16.100Z device=/dev/ttyUSB0 class=SKY satellites=table: 0FAD6348 tag=MID4
--Table[GPSd:SKY:satellites] = 1=table: 1623BA30 2=table: 16234078 3=table: 16232890 4=table: 16240418 5=table: 1623ED70 6=table: 16237CA0 7=table: 1623E5F0 8=table: 16235608 9=table: 1623BAF8
							--print(printableTable('GPSd:SKY:satellites', values.satellites))
							for i,v in ipairs(values.satellites) do
								if v.used then
									--print(printableTable('GPSd:SKY:satellites['..i..']', v))
								end
							end
						elseif values.class == 'TPV' then
--Table[GPSd] = lon=-3.564 device=/dev/ttyUSB0 class=TPV track=0.000 time=2013-06-28T18:38:16.100Z ept=0.005 speed=0.000 mode=2.000 lat=50.409 tag=MID2
							--print('GPSd:TPV:lat='..tostring(values.lat)..' lon='..tostring(values.lon)..' time='..tostring(values.time)..'\r\ncourse='..tostring(values.track)..' speed='..tostring(values.speed)..'mps alt='..tostring(values.alt)..' mode='..tostring(values.mode)..' epx,epy='..tostring(values.epx)..','..tostring(values.epy)..'m'..' '..tostring(values.device))
							if values.time then
								local s,e, y,m,d,h,m,s = string.find(values.time, '^(%d%d%d%d)-(%d%d)-(%d%d)T(%d%d)%:(%d%d)%:(%d%d).+Z$')
								if s then
									local timet = {year=y,month=m,day=d,hour=h,min=m,sec=s}
									local timeGPSd = os.time(timet)
									--print('GPSd:'..os.date("%a %H:%M:%S", timeGPSd))
								--else print('GPSd:'..tostring(values.time))
								end
							--else print('GPSd:Time:'..tostring(values.time))
							end
							if type(values.epx) == 'number' and type(values.epy) == 'number' then
								values.acc = math.sqrt(values.epx*values.epx + values.epy*values.epy)
							end
							if values.lat and values.lon then
								locationCounter = locationCounter + 1
								if type(values.speed) == 'number' and values.speed > 0 then
									values.speed = kphToKnots(values.speed * 3.6)	-- convert meters per second to kilometers per hour and then to knots
								end
	local tWhy = "gpsd"
	if type(values.acc) == 'number' then tWhy = tWhy..'~'..math.floor(values.acc) end
	addCrumb(values.lat, values.lon, values.alt, tWhy)
								moveME(values.lat, values.lon, values.alt, values.track, values.speed, values.acc)
	if gpstext then
		local text = string.format('GPSd:%s%s',
									values.tag and values.tag.." " or "",
									FormatLatLon(values.lat, values.lon, 1, 0))
		if values.alt and tonumber(values.alt) then
			text = text..string.format(' %im', values.alt)
		end
		if values.speed and tonumber(values.speed) and values.speed >= 0 then
			text = text..string.format(' %.1f', values.speed)
		end
		if values.track and tonumber(values.track) and values.track >= 0 then
			text = text..string.format('@%i', values.track)
		end
--print('GPSd:track:'..tostring(values.track)..printableTable(' values',values))
		if values.acc and tonumber(values.acc) and values.acc >= 0 then
			text = text..string.format(' %i', values.acc)
		end

		local x,y = gpstext:getLoc()
		gpstext:setString ( text )
		gpstext:fitSize()
		gpstext:setLoc(x,y)
	end
							else
								--latText.text = 'Lat:nil'
								--lonText.text = 'Lon:nil'
								--altText.text = 'Alt:nil'
								--accText.text = 'Acc:nil'
								--spdText.text = 'Spd:nil'
							end

						elseif values.class == 'VERSION' then
--Table[GPSd:VERSION] = rev=3.6 release=3.6 class=VERSION proto_major=3.000 proto_minor=7.000
							print('GPSd:VERSION:'..values.proto_major..'/'..values.proto_minor..' '..values.rev)
						elseif values.class == 'DEVICES' then
							print(printableTable('GPSd:DEVICES:devices', values.devices))
							print(printableTable('GPSd:DEVICES:devices.1', values.devices[1]))
							print(printableTable('GPSd:DEVICES:devices.2', values.devices[2]))
--Table[GPSd:DEVICES] = devices=table: 0F7010A8 class=DEVICES
						elseif values.class == 'WATCH' then
--Table[GPSd:WATCH] = raw=0.000 class=WATCH scaled=false enable=true json=true timing=false nmea=false
						else print(printableTable('GPSd:'..tostring(values.class), values))
						end
					else print('json.decode returned type('..type(values)..') for:'..line)
					end
				end
			else
				if err ~= 'timeout' then
					print('flushGPSd:error:'..err)
					GPSd:close()
					if config.Enables.GPS then
						performWithDelay( 30000, function() GPSd:connect() end)
					end
				end
			end
		until not line
		if config.Enables.GPS then
			performWithDelay( 100, flushGPSd)
		else GPSd:close()
		end
	else
		print ('No GPSd Connection')
	end
end

function GPSd:connect()
	print('GPSd:connect:Running!  '..(config.Enables.GPS and "Enabled" or "Disabled")..' Socket='..tostring(GPSdSocket))
	if config.Enables.GPS and not GPSdSocket then
		print('Connecting to GPSd')
		if config.gpsd.Server ~= '' and tonumber(config.gpsd.Port) then
			GPSdSocket = socket.connect(config.gpsd.Server, tonumber(config.gpsd.Port))
			if GPSdSocket then
				GPSdSocket:settimeout(0)	-- no timeouts for instant complete
				print("GPSd Connected!")
				--local n, err = GPSdSocket:send('?WATCH={"enable":true,"json":true,"nmea":true}\r\n')
				local n, err = GPSdSocket:send('?WATCH={"enable":true,"json":true}\r\n')
				if n == 0 then GPSd:close('sendWATCH Error:'..err) end
				performWithDelay( 100, flushGPSd)
			else
				print("GPSd Connection Failed!")
			end
		else	print('GPSd:Not properly Configured')
		end
	end
end

return GPSd
