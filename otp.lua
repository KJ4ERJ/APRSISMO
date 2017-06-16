local otp = {MOD_NAME="otp"}
local bit = bit
if type(bit) ~= 'table' then
	if type(bit32) == 'table' then
		print('otp:using internal bit32 module')
		bit = bit32
	else
		print('otp:using mybits type(bit)='..type(bit))
		bit = require("mybits")
		bit.lshift = bit.blshift
		bit.rshift = bit.blogic_rshift
	end
else print('otp:using internal bit module!')
end

-- v1, v2 are 2 longs, k(ey) is array of 4 longs
function otp:tea_encode(v1, v2, k)
	local sum, delta = 0, 0x9e3779b9
	if #k ~= 4 then
		print("tea_encode:Key Must Be 4 Longs, not "..tostring(#k))
		return nil
	end
	for n=1,32 do
		sum = (sum + delta)%4294967296
		v1 = (v1 + bit.bxor(bit.lshift(v2,4)+k[1], v2+sum, bit.rshift(v2,5)+k[2]))%4294967296
		v2 = (v2 + bit.bxor(bit.lshift(v1,4)+k[3], v1+sum, bit.rshift(v1,5)+k[4]))%4294967296
	end
	return v1, v2
end

-- v1, v2 are 2 longs, k(ey) is array of 4 longs
function otp:tea_decode(v1, v2, k)
	local delta = 0x9e3779b9
	local sum = bit.lshift(delta,5)
	for n=1,32 do
		v2 = (v2 - bit.bxor(bit.lshift(v1,4)+k[3], v1+sum, bit.rshift(v1,5)+k[4]))%4294967296
		v1 = (v1 - bit.bxor(bit.lshift(v2,4)+k[1], v2+sum, bit.rshift(v2,5)+k[2]))%4294967296
		sum = (sum - delta)%4294967296
	end
	return v1, v2
end

function otp:char2longs(s)
	local result = {}
	for i=1, #s-3, 4 do
		local a, b, c, d = s:byte(i, i+3)
		result[#result+1] = bit.bor(bit.lshift(d,24),bit.lshift(c,16),bit.lshift(b,8),a)
	end
	return result
end

function otp:setSecret(key)

	local newkey = {0x25b58745, 0x97119bc5, 0xb556ae25, 0xcaa24730}
	if (#key < 8) then
		print("Secret key must be 8+ characters")
		return nil
	end
	-- key = key..string.char(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)	-- Pad with 8+16 extra nulls
	while #key < 24 do key = key..key end
	for c=1,#key-23,16 do
		print('Encoding '..key:sub(c,c+15)..' or '..printableTable('longs',self:char2longs(key:sub(c,c+15))))
		newkey[1], newkey[2] = self:tea_encode(newkey[1], newkey[2], self:char2longs(key:sub(c,c+15)))
		print('Encoding '..key:sub(c+8,c+8+15)..' or '..printableTable('longs',self:char2longs(key:sub(c+8,c+8+15))))
		newkey[3], newkey[4] = self:tea_encode(newkey[3], newkey[4], self:char2longs(key:sub(c+8,c+8+15)))
	end
print('new key is '..printableTable('newkey',newkey))
	self.secret = newkey	-- This needs to be persisted
	self.sequence = 0		-- This needs to be persisted
	self:saveState()
end

function otp:getPassword(index)
	local otpcharset = "0123456789ABCDEFGHJKMNPRSTUVWXYZ"	-- Actually for one-time-password
	index = index or 0
	local nonce = {0x77a25667, bit.bxor(0x69436027,index)}
	local i, n = self:tea_encode(nonce[1], nonce[2], self.secret)
	local result = ''
	for c=1, 4 do
		local i = bit.band(n,0x1f)+1
		result = result..otpcharset:sub(i,i)
		n = bit.rshift(n,8)
	end
	return result
end

function otp:passList(count)
	count = count or 8
	local line = ""
	for c=0, count-1 do
		line = line..string.format("%4d:%s ", c+self.sequence, self:getPassword(c+self.sequence))
		if bit.band(c,7)==7 or c==count-1 then
			print(line)
			line = ""
		end	
	end
end

function otp:setSequence(sequence)
	self.sequence = sequence
	self:saveState()
end

function otp:checkPassword(p, n)	-- Check up to the next n passwords
	n = n or 1
	if #self.secret == 4 then
		for i = 0, n-1 do
			local pw = self:getPassword(self.sequence+i)
			if string.upper(p) == pw then
				self:setSequence(self.sequence+i+1)
				return true
			end
		end
		return false
	else return true	-- No secret set?  Anything matches!
	end
end

--function otp:restoreState()
--	if self.stateFile and #self.stateFile > 0 and file.open(self.stateFile) then
--		self.sequence = tonumber(file.readline())
--		self.secret = {}
--		self.secret[1] = tonumber(file.readline())
--		self.secret[2] = tonumber(file.readline())
--		self.secret[3] = tonumber(file.readline())
--		self.secret[4] = tonumber(file.readline())
--		file.close()
--		return true
--	end
--	return false
--end

function otp:saveState()
	print('otp:saveState via '..type(self.saveFunction))
	if type(self.saveFunction) == 'function' then
		self.saveFunction(self.secret, self.sequence)
	end
--	if self.stateFile and #self.stateFile > 0 and #self.secret == 4 then
--		file.open(self.stateFile, "w+")
--		file.writeline(tostring(self.sequence))
--		for k,v in ipairs(self.secret) do
--			file.writeline(tostring(v))
--		end
--		file.close()
--	end
end


function otp:init(secret, sequence, saveFunction)	-- saveFunction(secret, sequence)
	self.saveFunction = saveFunction
	self.secret = secret
	self.sequence = sequence
end

return otp
