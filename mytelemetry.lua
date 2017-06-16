local M = {version="0.0.1"}

local socket = require("socket")
local toast = require("toast");
local APRS = require("APRS")
local APRSIS = require("APRSIS")
local stationList = require("stationList")

-- This is my private APRS-IS connection for telemetry

local myAPRSIS = nil

local function myRead(incoming)
	local gotStuff, err, partial = incoming:receive(8192)
	if not gotStuff then
		if not partial or err ~= 'timeout' then
			print("readwrite: Error reading was "..tostring(err))
			return 0
		else gotStuff = partial
		end
	end
	if gotStuff ~= "" then
		print("myRead:Got("..tostring(gotStuff)..")")
	else
		toast.new("readwrite:NOOP")
	end
	if #gotStuff == 0 then toast.new("Read ZSERO bytes!") end
	return #gotStuff;
end

local function myRun(incoming)

	local sockets = { incoming }
	local readable, writeable, err = socket.select( sockets, nil, 0)
	
	--print("Readable:"..printableTable("Readable", readable).." Writeable:"..printableTable("Writeable", writeable));

	if not err then
		if readable[incoming] then
			--print("incoming readable")
			local bytes = myRead(incoming)
			if bytes == 0 then err = "Incoming Error" end
		end
	end

	if err and err ~= 'timeout' then
		incoming:close()
		return 'cancel'	-- kills the recurring timer
	end
end

local function sendTelemetry(packet)
	if not myAPRSIS then
		local outgoing, err = socket.connect("192.168.10.8", 14580)
		if outgoing then
			myAPRSIS = outgoing
			outgoing:settimeout(0)	-- Need no blocking
			local logon = string.format('user %s pass %s vers LightningTelemetry 0.1',
										config.StationID, config.PassCode)
	print(logon)
			n, err = outgoing:send(logon..'\r\n')
	print("logon sent:"..type(n)..' '..tostring(n).." "..logon)
			serviceWithDelay("proxyRun", 100, function()
								local status = myRun(outgoing)
								if status == 'cancel' then myAPRSIS = nil end
								return status
							end, 0)
		else
			print("Outgoing Connection Failed With "..tostring(err))
			err = "Outgoing Failed"
		end
	end
	if myAPRSIS then
		local n, err = myAPRSIS:send(packet..'\r\n')
		print("packet sent:"..type(n)..' '..tostring(n).." "..packet)
		if type(n) ~= 'number' or n == 0 then
			closeConnection('sendPacket Error:'..tostring(err))
			myAPRSIS:close()
			return err
		end
		return nil
	else return 'No Connection'
	end
end

M.points = {}
M.bits = {}

function M:getNextDef(which)
	local i	-- expose it outside the loops
	local p, pi = "", 0
	local function addPiece(w,c)
		if p == "" then p = tostring(w)
		else
			if pi == 0 then
				p = p.."."
			elseif not c then	-- c specifies concatenation (for BITS)
				p = p..","
			end
			p = p .. tostring(w)
			pi = pi + 1
		end
	end
	local function finishPacket(n,w,c)
		while pi < n do
			addPiece(w,c)
		end
		return p
	end
	if which == 1 then		-- PARM.Vdd,Heap,Temp1,Temp2,Temp3,GPIO0(3),GPIO4(2),GPIO5(1),GPIO12(6),GPIO13(7),GPIO2(4),GPIO14(5),NA
		addPiece('PARM')
		for i, w in pairs(self.points) do
			addPiece(w.label)
		end
		finishPacket(5,'NA')
		for i, b in pairs(self.bits) do
			addPiece(b.label)
		end
		return finishPacket(13,'NA')
	elseif which == 2 then	-- UNIT.Volts,kB,DegF,DegF,DegF,on,on,on,on,on,on,on,off
		addPiece('UNIT')
		for i, w in pairs(self.points) do
			addPiece(w.units)
		end
		finishPacket(5,'NA')
		for i, b in pairs(self.bits) do
			addPiece(b.units)
		end
		return finishPacket(13,'NA')
	elseif which == 3 then	-- EQNS.0,.01,0,0,0.1,0,0,.18,32,0,.18,32,0,.18,32
		addPiece('EQNS')
		for i, w in pairs(self.points) do
--			addPiece(string.format("%d,%d,%d",w.a,w.b,w.c))
			addPiece(tostring(w.a)..","..tostring(w.b)..","..tostring(w.c))
		end
		return finishPacket(0)	-- this one can be truncated?
	elseif which == 4 then	-- BITS.11111110,ESP Temperatures
		addPiece('BITS')
		for i, b in pairs(self.bits) do
			addPiece(b.sense,true)
		end
		return finishPacket(8,0,true)..","..self.name
	else
		print("telemetry:tDefs:Unsupported which="..tostring(which))
		return nil
	end
end

function M:sendDefinitions()
	if not self.tNextDef then self.tNextDef = 1 end
	local p = self:getNextDef(self.tNextDef)
	local status = sendTelemetry(string.format("%s:%-9s:%s", self.header, config.StationID, p))
	if status then
		print("APRSIS FAILED to send "..p)
		self.tNextDef = 1	-- start over to make sure they all go out
	else
		self.tNextDef = self.tNextDef + 1
	end
	if self.tNextDef > 4 then
		self.tNextDef = 1
		self.nextDefinitions = os.time() + 4*60*60	-- Every 4 hours for development
	else
		self.nextDefinitions = os.time() + 10	-- Every 10 seconds for development
	end
end

function M:sendTelemetry()
	if os.time() > self.nextDefinitions then
		self:sendDefinitions()
	end
	local p, pi = "", 0
	local function addPiece(w,c)
		if p == "" then p = tostring(w)	-- First "piece" doesn't count
		else
			if not c then	-- c specifies concatenation (for BITS)
				p = p..","
			end
			p = p .. tostring(w)
			pi = pi + 1
		end
	end
	local function finishPacket(n,w,c)
		while pi < n do
			addPiece(w,c)
		end
		return p
	end
	addPiece(self.sequence) self.sequence = self.sequence + 1 if self.sequence > 999 then self.sequence = 1 end
	for i, w in pairs(self.points) do
		local v = w.getValue()
		v = math.floor((v - w.c)/w.b+0.5)
		if v > 255 then print("Telemetry Value Overflow On "..w.label.." value="..tostring(v).." or "..tostring(v*w.b+w.c)) end
		addPiece(v)
	end
	finishPacket(5,0)	-- 5 values
	for i, b in pairs(self.bits) do
		local v = b.getValue()
		addPiece(v,i~=1)
	end
	finishPacket(6,0,false)	-- 5 values + first bit
	p = finishPacket(13,0,true)	-- 5 values + 8 bits
	print("telemetry:"..p)
	local status = sendTelemetry(string.format("%sT#%s", self.header, p))
	if status then
		print("APRSIS FAILED to send "..p)
	end
end

function M:init(name, interval, header)	-- interval is seconds
	self.name = name
	self.interval = interval
	self.header = header
	self.sequence = os.time()%999+1
	self.nextDefinitions = os.time() + 30	-- 30 second delay for testing
	performWithDelay( interval*1000, function() self:sendTelemetry() end, 0)
end

function M:definePoint(label, units, a,b,c, getValue)	-- a*v^2+bv+c
	table.insert(self.points, {label=label, units=units, a=a, b=b, c=c, getValue=getValue} )
end

function M:defineBit(label, units, sense, getValue)
	table.insert(self.bits, {label=label, units=units, sense=sense, getValue=getValue} )
end

return M
