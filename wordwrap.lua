function WordWrap(aMsg, MaxWidth, PreLen)	-- returns table of wrapped lines

	local len = #aMsg
	
	if not MaxWidth then MaxWidth = len + 16 end	-- for good measure
	if not PreLen then PreLen = 0 end
	if len <= PreLen then PreLen = 0 end
	
	local p = 1
	local n = len/(MaxWidth/2-PreLen) + 1
	local r = {}
	
	local Next, Last

	Next = PreLen+1	-- Index to first checkable character
	while p <= n and Next <= len do

		while Next < len and aMsg:sub(Next,Next) == ' ' do Next = Next + 1 end	-- Remove leading spaces

		if PreLen > 0 then r[p] = aMsg:sub(1,PreLen) else r[p] = '' end	-- Initialize new line

		if len-Next > MaxWidth-PreLen then
			Last = Next + MaxWidth-PreLen-1;
-- Need to watch for next line starting with ? tripping up remote queries
-- Lines should also not start with ack, no matter how long they are
			while aMsg:sub(Last,Last) ~= ' ' and Last > Next+MaxWidth/2 do Last = Last - 1 end	-- Find previous white
			if aMsg:sub(Last,Last) == ' ' then
				while Last>Next and aMsg:sub(Last-1,Last-1) == ' ' do Last = Last - 1 end	-- Skip back over all spaces
			else Last = Next + MaxWidth-PreLen-1	-- No spaces, just chop the word
			end
		else Last = len+1;
		end

		r[p] = r[p]..aMsg:sub(Next,Last-1)

		local Check4More = Last
		while Check4More <= len and aMsg:sub(Check4More,Check4More) == ' ' do Check4More = Check4More + 1 end
		if Check4More <= len then r[p] = r[p]..'+' end	-- flag more to follow

		if #r[p] > PreLen then p = p + 1 end	-- Go to next line if data after prefix

		Next = Last
	end
	return r;
end

