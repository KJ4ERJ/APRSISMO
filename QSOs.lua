local QSOs = {}

----------------------------------------------------------------------------------
--
-- QSOs.lua
--
----------------------------------------------------------------------------------

print('QSOs:Loading!')

function QSOs:refresh(QSO)
	print('refresh:closing Scene')
	SceneManager:closeScene({animation = "popDown", },
			function ()
				print('refresh:QSOs:re-openingScene...')
				if QSO == nil then
						SceneManager:openScene("QSOs_scene", {animation="popIn"})
				else SceneManager:openScene("QSO_scene", { animation="popIn", QSO = QSO })
				end
			end)
	--performWithDelay(100,function()
--[[
							if QSO == nil then
									SceneManager:openScene("QSOs_scene")
							else SceneManager:openScene("QSO_scene", { QSO = QSO })
							end
]]
	--					end)
end

function QSOs:iterate()
	local t = QSOs
	local f = nil	-- Comparison function?
	local a = {}
	for n in pairs(t) do table.insert(a, n) end
	table.sort(a, f)
	local i = 0      -- iterator variable
	local iter = function ()   -- iterator function
		repeat i = i + 1
		until type(t[a[i]]) ~= 'function'	-- Skip functions in class
		if a[i] == nil then return nil
		else return a[i], t[a[i]]
		end
	end
	return iter
end

function QSOs:getCount()
	local c = 0
	for k,v in QSOs:iterate() do
		c = c + 1
	end
	return c
end

function QSOs:getQSO(from, to, additional)
	additional = additional or ''
	if #additional > 0 then additional = ':'..additional end
	if not QSOs then QSOs = {} end
	local fromTo = tostring(from)..'<>'..tostring(to)..additional
	if QSOs[fromTo] then return QSOs[fromTo], fromTo end
	local toFrom = tostring(to)..'<>'..tostring(from)..additional
	if QSOs[toFrom] then return QSOs[toFrom], toFrom end
	if QSOs[from..additional] then return QSOs[from..additional], from..additional end
	if QSOs[to..additional] then return QSOs[to..additional], to..additional end
	--if from == 'ME' then fromTo = to end
	-- if to == 'ME' then fromTo = from end
	if to == 'ME' then fromTo = toFrom end
	local QSO = {}
	QSOs[fromTo] = QSO
	QSO.id = fromTo
	if from == 'ME' then
		QSO.from, QSO.to = from, to
	elseif to == 'ME' then
		QSO.from, QSO.to = to, from
	else
		QSO.from, QSO.to = from, to
	end
	if #additional > 0 then
		QSOs[fromTo].additional = additional:sub(2)	-- remove the :
	end
	return QSOs[fromTo], fromTo
end

function QSOs:newQSO(to, additional)
	local QSO = QSOs:getQSO("ME", to, additional)
	performWithDelay(100,function() SceneManager:openScene("QSO_scene", { animation="popIn", QSO = QSO }) end)
end

function QSOs:getMessageCount(QSO)	-- Returns New and Total message counts for one or all (nil) QSOs
	local n, t, q = 0, 0, 0
	if not QSO then
		for k,v in QSOs:iterate() do
			local n1, t1 = QSOs:getMessageCount(v)
			n = n + n1
			t = t + t1
			if n1 > 0 then q = q + 1 end
		end
	else
		for i,m in ipairs(QSO) do
			if type(i) == 'number' then	-- ignore the extra pairs
				t = t + 1
				if not m.read then n = n + 1; q = 1 end
			end
		end
	end
	return n, t, q
end

function QSOs:newQSOMessage(QSO, from, to, text, when)
	when = when or os.time()
	if #text > 3 and #text <= 8 and (text:sub(1,3) == 'ack' or text:sub(1,3) == 'rej') then	-- ack<1-5>
		local ack = text:sub(4)
print("Msg:gotAnAck/Rej("..ack..") from:"..from.." to:"..to.." #QSO="..tostring(#QSO))
		for i = #QSO, 1, -1 do
			local QSOi = QSO[i]
			print(printableTable("QSOi",QSOi," "))
			if QSOi.ack	then -- We must be expecting an ack!
			if (QSOi.ack==ack or (ack:sub(3,3)=='}' and QSOi.ack:sub(1,3)==ack:sub(1,3))) then
			if QSOi.from==to and QSOi.to==from then	-- Reverse direction!
				print("Msg:GotAnAck:for "..text.." ack:"..ack)
				if not QSOi.acked then
					QSOi.acked = {}
					print("Msg:Have "..#QSOi.acked.." acks for "..QSOi.text)
				else print("Msg:Had "..#QSOi.acked.." acks for "..QSOi.text)
				end
				QSOi.acked[#QSOi.acked+1] = when
				if text:sub(1,3) == 'rej' then
					QSOi.rejected = true
				end
				print("Msg:Have "..#QSOi.acked.." acks for "..QSOi.text)
				return QSO, QSOi
			else print("Msg:Ack("..ack..") from:"..from.."v"..QSOi.from.." to:"..to.."v"..QSOi.to.." for "..QSOi.text)
			end
			else print("Msg:Ack("..ack..") ~= Expected("..tostring(QSOi.ack)..") from:"..from.."v"..QSOi.from.." to:"..to.."v"..QSOi.to.." for "..QSOi.text)
			end
			else print("Msg:Ack("..ack..") ~= Expected("..tostring(QSOi.ack)..")NIL? from:"..from.."v"..QSOi.from.." to:"..to.."v"..QSOi.to.." for "..QSOi.text)
			end
		end
print("Msg:nfdAck("..ack..") from:"..from.." to:"..to)
	else print("Msg:NotAnAck:"..text)
	end

	if text:sub(1,4) == 'Seq:' then
		local otp = require('otp')
		local v1, v2 = string.match(text, "^Seq:([+-]?%d+):([+-]?%d+)$")
		if v1 and v2 and tonumber(v1) and tonumber(v2) then
			v1, v2 = otp:tea_decode(tonumber(v1),tonumber(v2),otp.secret)
			if v2 > 2147483647 then v2 = v2 - 4294967296 end	-- Put it to signed 32 bits
			if v1 == -v2 then
				text = 'Seq: '..tostring(v1)
				if v1 ~= config.OTP.Sequence then
					text = text.." *RESET from "..tostring(config.OTP.Sequence).."*"
					config.OTP.Sequence = v1
					config:save("OTPSequence")
				else text = text.." MATCHED!"
				end
			end
		end
	end
	
	local QSOi = {}
	QSO[#QSO+1] = QSOi
	QSOi.fromTo = from..'<>'..to
	if QSO.additional then QSOi.fromTo = QSOi.fromTo..':'..QSO.additional end
	QSOi.from = from
	QSOi.to = to
	QSOi.text = text
	QSOi.when = when
	return QSO, QSOi
end

function QSOs:newMessage(from, to, text, when)
	print("newMessage:from:"..from.." to:"..to.." text:"..text);
	if to == 'ME' then
		local s, e, group = string.find(text, "^N:(.-)%s")
		if group then
			local newText = '('..from..') '..text:sub(#group+3)
			local QSO = QSOs:getQSO("ANSRVR", "ME", group)
			print(printableTable("GroupQSO", QSO, " "));
			QSOs:newQSOMessage(QSO, from, to, newText)
		end
	end
	local found = QSOs:getQSO(from, to)
	print(printableTable("newMsgQSO", found, " "));
	return QSOs:newQSOMessage(found, from, to, text, when)
end

function QSOs:replyAck(from, to, ack)
	if #ack == 5 and ack:sub(3,3) == '}' then	-- if this one contains a ReplyAck
		local replyAck = ack:sub(4)..'}'
		local QSO = QSOs:getQSO(from, to)
		for i = #QSO, 1, -1 do
			local QSOi = QSO[i]
			if QSOi.ack and QSOi.ack:sub(1,3)==replyAck and QSOi.from==from and QSOi.to==to then	-- Same direction!
				print("Msg:GotReplyAck:for "..QSOi.text.." ack:"..ack)
				if not QSOi.acked then
					QSOi.acked = {}
					print("Msg:Have "..#QSOi.acked.." (reply)acks for "..QSOi.text)
				else print("Msg:Had "..#QSOi.acked.." (reply)acks for "..QSOi.text)
				end
				QSOi.acked[#QSOi.acked+1] = os.time()
				print("Msg:Have "..#QSOi.acked.." (reply)acks for "..QSOi.text)
				return QSO, QSOi
			else print("Msg:ReplyAck("..ack..") ~= Expected("..tostring(QSOi.ack)..") from:"..from.."v"..QSOi.from.." to:"..to.."v"..QSOi.to.." for "..QSOi.text)
			end
		end
	end
end

return QSOs
