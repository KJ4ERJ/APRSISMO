local myConfig = {} -- The "Class" 

--local widget = require("widget")

local xmlapi = require( "xml" ).newParser()

local function tableCount(t)
	local c = 0
	for _, _ in pairs(t) do
		c = c + 1
	end
	return c
end
local function ToXmlString(value)
	value = string.gsub (value, "&", "&amp;");         -- '&' -> "&"
	value = string.gsub (value, "<", "&lt;");               -- '<' -> "<"
	value = string.gsub (value, ">", "&gt;");               -- '>' -> ">"
	value = string.gsub (value, "\"", "&quot;");    -- '"' -> """
	value = string.gsub(value, "([^%w%&%;%p%\t% ])",
		function (c)
				return string.format("&#x%X;", string.byte(c))
		end);
	return value;
end
local function writeXmlTable(hFile, tag, values)
--print('writeXmlTable(tag:'..tostring(tag)..' values:'..tostring(values)..')')
	hFile:write('<'..tag..'>\n')
	local k,v
	for k,v in pairs(values) do
		if type(v) == 'string' or type(v) == 'number' or type(v) == 'boolean' then
			hFile:write('<'..k..'>', ToXmlString(tostring(v)), '</'..k..'>\n')
		elseif type(v) == 'table' then
			if k ~= '__special' then
				if #v == tableCount(v) then
					local i
					for i = 1, #v do
						if type(v[i]) == 'table' then
							writeXmlTable(hFile, k, v[i])
						elseif type(v[i]) == 'string' or type(v[i]) == 'number' or type(v[i]) == 'boolean' then
							hFile:write('<'..k..'>', ToXmlString(tostring(v[i])), '</'..k..'>\n')
						else	print('unsupport type('..k..')('..type(v)..')')
						end
					end
				else
					writeXmlTable(hFile, k, v)
				end
			end
		elseif type(v) == 'function' then	-- ignore these
		else	print('unsupport type('..k..')('..type(v)..')')
		end
	end
	hFile:write('</'..tag..'>\n')
end

system = {}
function system.pathForFile(f, d)
	return d..'/'..f
end

myConfig.new = function(file, dir)

	local self = {}
	local actualConfig = nil
	local safePath = system.pathForFile( file..'-Safe', dir )
	local realPath = system.pathForFile( file, dir )
	local configXML = xmlapi:loadFile( file, dir )
	local configChanged = false

self.touch = function (self, why)
	configChanged = true
end

self.save = function (self, why)

	local outputPath = system.pathForFile( file..'-Temp', dir )
	local hFile, err = io.open(outputPath, "w")

	actualConfig.LastSaveWhy = why
	actualConfig.LastSaved = os.date('!%Y-%m-%dT%H:%M:%S')

	if hFile and not err then
		local _,_,prefix = string.find(file, '(.+)%.')
		prefix = prefix or file	-- Just the outer XML element name
		writeXmlTable(hFile, prefix, actualConfig)
		io.close(hFile)
		print('Config('..tostring(why)..') Saved To '..file)
		local safePath = system.pathForFile( file..'-Safe', dir )
		os.remove(safePath)
		os.rename(realPath, safePath)
		os.rename(outputPath, realPath)
		return true
	else
		print('Failed to save Config to '..outputPath)
		print( err )
		return false
	end
	configChanged = false	-- reset the changed flag
end

local childScene = nil
local actions = nil
local groups = {}
local nilGroup = {}

self.fireActions = function (self)
	print('firing '..(actions and #actions or 0)..' pending actions')
	if actions then
		local action
		for _, action in pairs(actions) do
			print('fireActions:'..action.why..' invoking action '..tostring(action.action))
			action.action()
		end
		actions = nil
		self.save(self, 'Configured')
	end
end

self.setConfig = function ( self, id, newValue )
	if config[id] ~= newValue then
		print(id..' Changed from '..tostring(config[id])..' to '..tostring(newValue))
		config[id] = newValue	-- helps to actually SET the new value!
		if groups[id] and groups[id].action then
			local action = groups[id].action
			if not actions then actions = {} end
			if not actions[action] then actions[action] = {} end
			actions[action].action = action
			actions[action].why = id
print(id..' added pending action['..#actions..']:'..tostring(action))
		end
	end
end

self.unconfigure = function (self)
	if childScene then
		print('removing childScene:'..tostring(childScene)..' with '..(actions and #actions or 0)..' pending actions')
		SceneManager:closeScene({animation = "popOut"})
		childScene = nil
		return true
	end
	return false
end

self.configure = function (self, removeIt, yOffset)	-- true will only remove if visible
	if not self.unconfigure(self) and not removeIt then
		childScene = SceneManager:openScene("config_scene", {config=self, animation = "popIn", backAnimation = "popOut" })
	end
end

self.makeConfigScroller = function (self, scene, backAnim)

	local scroller, guiView
	local scrollY = 1
	
	local function buildScroller()

		local width = Application.viewWidth
		if Application.viewWidth > Application.viewHeight then --	landscape, shrink the width
			width = width * 0.75
		end
		local left = (Application.viewWidth-width)/2

		if scroller then
			scroller:removeChildren()
		end

		if not guiView then
			guiView = View {
				left = left,
				width = width,
				scene = scene,
			}
		end
		
		scroller = Scroller {
			parent = guiView,
			--hBounceEnabled = false,
			HScrollEnabled = false,
			layout = VBoxLayout {
				align = {"center", "center"},
				padding = {0,0,0,0},
				--gap = {0,0},
				--padding = {10, 10, 10, 10},
				--gap = {4, 4},
				gap = {1, 1},
			},
		}

		local titleGroup = Group {}

		local titleBackground = Graphics {width = width, height = 40*config.Screen.scale, left = 0, top = 0}
		--titleBackground:setPenColor(0.707, 0.8125, 0.8125, 0.75):fillRect()	-- 181,208,208 from OSM zoom 0 map
		titleBackground:setPenColor(0.25, 0.25, 0.25, 0.75):fillRect()	-- dark gray like Android
		--titleBackground:setPriority(2000000000)
		titleGroup:addChild(titleBackground)

		titleLabel = TextLabel {
			text = file.." Configuration",
			textSize=28*config.Screen.scale,
			size = {guiView:getWidth(), 40*config.Screen.scale},
			color = {1, 1, 1},
			parent = titleGroup,
			align = {"center", "center"},
		}
		titleLabel:fitSize()
		titleLabel:setAlignment ( MOAITextBox.CENTER_JUSTIFY )
		titleLabel:setLoc(width/2, 20*config.Screen.scale)
		--local x,y = titleText:getSize()
		--titleText:setLoc(width/2, 25*config.Screen.scale)

		if Application:isDesktop() then
			local button = Button {
				text = "Back", textSize=20, --13*config.Screen.scale,
				alpha = 0.8,
				--size = {100*config.Screen.scale, 40*config.Screen.scale},
				size = {100, 40},
				parent = titleGroup,
				onClick = function() self:unconfigure() end,
			}
			button:setScl(config.Screen.scale,config.Screen.scale,1)
			button:setRight(width)
		end
		
		titleGroup:resizeForChildren()
		titleGroup:setParent(scroller)

		local colorCategory = { default = { 150/255, 160/255, 180/255 }, }
		local colorRow =  { default = { 192/255, 192/255, 192/255 },
								over = { 30/255, 144/255, 255/255 }, }
		local colorLine = { 220/255, 220/255, 220/255 }
		local heightCategory = 30*config.Screen.scale*2
		local heightValue = 60*config.Screen.scale
		local pad = 5*config.Screen.scale
		
		local openGroup = false
		for i, v in ipairs(groups) do
			local button
			if v.isGroup then
				button = Group {}
				local titleBackground = Graphics {width = guiView:getWidth(), height = heightCategory, left = 0, top = 0}
				titleBackground:setPenColor(unpack(colorCategory.default)):fillRect()
				--titleBackground:setPriority(2000000000)
				button:addChild(titleBackground)
	--[[			local text = TextLabel{
					text=tostring(v.id)..' - '..tostring(v.desc),
					textSize = 22*config.Screen.scale,
					size = {guiView:getWidth(), heightCategory},
					color = {0,0,0},
					parent=button,
					align = {"center", "center"},
				}
				text:fitSize()
				if text:getWidth() > guiView:getWidth()-pad*2 then
					text:setWidth(guiView:getWidth()-pad*2)
					text:setColor(1,0,0)
				end
				text:setLeft(pad) text:setTop((heightCategory-text:getHeight())/2)
	]]


				local rowTitle  = TextLabel{
					text=v.id,
					textSize = 29*config.Screen.scale,
					size = {guiView:getWidth(), heightValue},
					color = {0,0,0},
					parent=button,
					align = {"center", "top"},
				}
				rowTitle:fitSize()
				rowTitle:setLeft((guiView:getWidth()-rowTitle:getWidth())/2) rowTitle:setTop(0)

				local rowText  = TextLabel{
					text=v.desc,
					textSize = 20*config.Screen.scale,
					size = {guiView:getWidth(), heightValue},
					color = {0,0,0},
					parent=button,
					align = {"center", "bottom"},
				--rowText.y = row.contentHeight - (row.contentHeight - rowTitle.contentHeight) * 0.5
				}
				rowText:fitSize()
				if rowText:getWidth() > guiView:getWidth()-pad*2 then
					rowText:setWidth(guiView:getWidth()-pad*2)
					rowText:setColor(1,0,0)
				end
				rowText:setLeft((guiView:getWidth()-rowText:getWidth())/2) rowText:setBottom(heightValue-2)


				button:resizeForChildren()
				button:setParent(scroller)
				button:addEventListener("touchUp",
										function(e)
											if e.isTap then
													local x,y = button:getPos()
													print(v.id..' tapped at '..tostring(x)..","..tostring(y))
													v.isOpen = not v.isOpen
													scrollY = y - button:getHeight()/2
													buildScroller()
											end
										end)
				openGroup = v.isOpen
			elseif v.group ~= nilGroup and openGroup then
				button = Group {}

				local titleBackground = Graphics {width = width, height = heightValue, left = 0, top = 0}
				titleBackground:setPenColor(unpack(colorRow.default)):fillRect()
				--titleBackground:setPriority(2000000000)
				button:addChild(titleBackground)

				local grpID = v.group.id
				local useID = v.id
				if useID:sub(1,#grpID) == grpID and useID:sub(#grpID+1,#grpID+1) == '.' then
					useID = useID:sub(#grpID+2)
				end

				local rowTitle  = TextLabel{
					text=useID,
					textSize = 29*config.Screen.scale,
					size = {guiView:getWidth(), heightValue},
					color = {0,0,0},
					parent=button,
					align = {"left", "top"},
				}
				rowTitle:fitSize()
				rowTitle:setLeft(pad) rowTitle:setTop(0)

				local rowText  = TextLabel{
					text=v.desc,
					textSize = 20*config.Screen.scale,
					size = {guiView:getWidth(), heightValue},
					color = {0,0,0},
					parent=button,
					align = {"left", "bottom"},
				--rowText.y = row.contentHeight - (row.contentHeight - rowTitle.contentHeight) * 0.5
				}
				rowText:fitSize()
				if rowText:getWidth() > guiView:getWidth()-pad*2 then
					rowText:setWidth(guiView:getWidth()-pad*2)
					rowText:setColor(1,0,0)
				end
				rowText:setLeft(pad) rowText:setBottom(heightValue-2)
				local text = tostring(config[v.id])
				if v.isNumberF and not string.find('%.',text) and tonumber(text) then
					text = string.format('%.1f', tonumber(text))
				end
				local rowValue = TextLabel{
					text=text,
					textSize = 36*config.Screen.scale,
					size = {guiView:getWidth()/2, heightValue},
					color = {0,0,0},
					parent=button,
					align = {"right", "center"},
					wordBreak = MOAITextBox.WORD_BREAK_CHAR,
				--rowText.y = row.contentHeight - (row.contentHeight - rowTitle.contentHeight) * 0.5
				}
				--rowValue:fitSize()
				if #text > 0 then
					rowValue:fitSize()
					local useWidth = guiView:getWidth()-pad*2-rowTitle:getWidth()
					local xs, ys = rowValue:getSize()
					if xs > useWidth then
					print(useID..' is '..tostring(xs)..'x'..tostring(ys)..' vs '..useWidth..'x'..heightValue)
						local scale = useWidth/xs*0.95
				rowValue:dispose()
				rowValue = TextLabel{
					text=text,
					textSize = 36*config.Screen.scale*scale,
					size = {guiView:getWidth()/2, heightValue},
					color = {0,0,0},
					parent=button,
					align = {"right", "center"},
					wordBreak = MOAITextBox.WORD_BREAK_CHAR,
				}
				rowValue:fitSize()
						local xs, ys = rowValue:getSize()
						print('Filter is now '..tostring(xs)..'x'..tostring(ys)..' vs '..useWidth..'x'..heightValue)
					end
					rowValue:setWidth(useWidth)
				end
				rowValue:setRight(guiView:getWidth()-pad)
				--rowValue:setLeft(0)
				rowValue:setTop(0)
				button:resizeForChildren()
				button:setParent(scroller)

				local configType = type(config[v.id])
				if configType == 'boolean' then
	rowValue:setPriority(2000000000)
					button:addEventListener("touchUp",
							function(e)
								if e.isTap then
										print(v.id..' tapped!')
	--[[
										config:setConfig(v.id, not config[v.id])	-- toggle the boolean
										local x, y  = rowValue:getRight(), rowValue:getTop()
										rowValue:setString(tostring(config[v.id]))
										rowValue:fitSize()
										rowValue:setRight(x) rowValue:setTop(y)]]

			local entries = { { value=true, detail="Set to True"}, { value=false, detail="Set to False"} }
			local function newValue(newV)
				config:setConfig(v.id, newV)	-- set the (hopefully) boolean
				local x, y  = rowValue:getRight(), rowValue:getTop()
				rowValue:setString(tostring(config[v.id]))
				rowValue:fitSize()
				rowValue:setRight(x) rowValue:setTop(y)
			end
			SceneManager:openScene("chooser_scene", {config=config, titleText=useID.."="..tostring(config[v.id]), entries=entries, newValue=newValue, animation = "popIn", backAnimation = "popOut", })

								end
							end)
				elseif configType ~= nil then
	button:setPriority(2000000000)
					button:addEventListener("touchUp",
							function(e)
								if e.isTap then
									if v.len and v.len >= 0 then	-- Don't edit config.version!
										print(v.id..' clicked!')
										if type(v.chooser) == 'function' then
											v.chooser(config, v.id, function(newValue)
						config:setConfig(v.id, newValue)
						local x, y  = rowValue:getRight(), rowValue:getTop()
						local text = tostring(config[v.id])
						rowValue:setString(text)
						if #text > 0 then rowValue:fitSize() end
						rowValue:setRight(x) rowValue:setTop(y)
												end)
										else

	DIALOG_SIZE = { Application.viewWidth * 0.95, 250*config.Screen.scale}

		SceneManager:openScene("textentry_scene",
		{
			animation = "popIn", backAnimation = "popOut",
			scale = config.Screen.scale,
			size = DIALOG_SIZE,
			type = DialogBox.TYPE_WARNING,
			title = useID,
			text = v.desc,
			value = tostring(config[v.id]),
			buttons = {"OK", "Cancel"},
			onResult = function(e)
				if e.result == 'OK' or e.result == 'Enter' then
					if not (v.isNumber or v.isNumberF) or tonumber(e.value) then
						print("Dialog result is: '" .. e.result .. "', index " .. tostring(e.resultIndex)..", value "..tostring(e.value))
						config:setConfig(v.id, e.value)
						local x, y  = rowValue:getRight(), rowValue:getTop()
						local text = tostring(config[v.id])
						rowValue:setString(text)
						if #text > 0 then rowValue:fitSize() end
						rowValue:setRight(x) rowValue:setTop(y)
					end
				end
			end,
		})
										end
									end
								end
							end)
				end
			end
			if button then button.id = v.id end
		end

		scroller:updateLayout()
		local left, top = scroller:clipScrollPosition(0, -scrollY)
		performWithDelay(20,function() scroller:setPos(left, top) end)
	end
	for i, v in ipairs(groups) do
		v.isOpen = v.showOpen
	end
	buildScroller()
end


local function maskGroup(group, rect)
	local width, height = rect.contentWidth, rect.contentHeight

--	local mask = getMask( width, height, nil, nil, false )
--	local filename = "i-mask-"..tostring(tableRect.contentWidth).."x"..tostring(tableRect.contentHeight)..".png"
	local mask = graphics.newMask( "mask.png", system.ResourceDirectory )
	local filename = "i-mask.png"
	
	--local maskimage = display.newImage( filename, system.TemporaryDirectory, 0,0 )
	local maskimage = display.newImage( filename, system.ResourceDirectory, 0,0 )
--print(string.format("MaskImage: %i x %i vs %i x %i",
--					maskimage.contentWidth, maskimage.contentHeight,
--					width, height))
	--maskimage.x = display.contentWidth/2
	--maskimage.y = display.contentHeight*3/4
	local scaleX = (width+4)/maskimage.contentWidth
	local scaleY = (height+8)/maskimage.contentHeight
--print(string.format("MaskImage Scaled: %i x %i vs %i x %i",
--					maskimage.contentWidth*scaleX, maskimage.contentHeight*scaleY,
--					width, height))
	maskimage:removeSelf()
	group:setMask( mask ) -- false allows caching old same size
	group:setReferencePoint(display.CenterReferencePoint)
	group.maskX, group.maskY = rect.x, rect.y	-- was tableRect!
	group.maskScaleX, group.maskScaleY = scaleX, scaleY
end

--	maskGroup(tableGroup, tableRect)

self.addGroup = function(self, group, desc, showOpen)
	if not group then return nilGroup end
	if not groups[group] then
		local newGroup = {}
		groups[group] = newGroup
		groups[#groups+1] = newGroup
		newGroup.id = group
		newGroup.desc = desc
		newGroup.isGroup = true
		newGroup.showOpen = showOpen
	end
	return groups[group]
end
self.addString = function(self, group, id, desc, len, default, match, validator, onModify)
	if not groups[id] then
		local newGroup = self.addGroup(self, group, 'Defined By '..id)
		local newItem = {}
		groups[id] = newItem
		newItem.group = newGroup
		newItem.id = id
		newItem.desc = desc
		newItem.isItem = true
		newItem.isString = true
		newItem.len = len
		newItem.default = default
		newItem.match = match
		newItem.validator = validator
		newItem.action = onModify
if onModify then print('Config['..tostring(id)..'] has onModify:'..tostring(onModify)) end
	end
	groups[#groups+1] = groups[id]

	--print('addString: Group('..tostring(group)..') id('..tostring(id)..')')
	if type(self[id]) == 'nil' then
	--print('defaulting['..tostring(id)..'] to '..type(default)..'('..tostring(default)..')')
		self[id] = default
	end
end
self.addChooserString = function(self, group, id, desc, len, default, chooser, onModify)
	if not groups[id] then
		local newGroup = self.addGroup(self, group, 'Defined By '..id)
		local newItem = {}
		groups[id] = newItem
		groups[#groups+1] = newItem
		newItem.group = newGroup
		newItem.id = id
		newItem.desc = desc
		newItem.isItem = true
		newItem.isString = true
		newItem.len = len
		newItem.chooser = chooser
		newItem.validator = validator
		newItem.action = onModify
if onModify then print('Config['..tostring(id)..'] has onModify:'..tostring(onModify)) end
	end

	--print('addString: Group('..tostring(group)..') id('..tostring(id)..')')
	if type(self[id]) == 'nil' then
	--print('defaulting['..tostring(id)..'] to '..type(default)..'('..tostring(default)..')')
		self[id] = default
	end
end
self.addNumber = function(self, group, id, desc, default, minimum, maximum, onModify)
	if not groups[id] then
		local newGroup = self.addGroup(self, group, 'Defined By '..id)
		local newItem = {}
		groups[id] = newItem
		newItem.group = newGroup
		newItem.id = id
		newItem.desc = desc
		newItem.isItem = true
		newItem.isNumber = true
		newItem.default = default
		newItem.minimum = minimum
		newItem.maximum = maximum
		newItem.len = 8
		newItem.action = onModify
	end
	groups[#groups+1] = groups[id]
	--print('addNumber: Group('..tostring(group)..') id('..tostring(id)..')')
	if self[id] and (type(self[id]) == 'string') and tonumber(self[id]) then
		self[id] = tonumber(self[id])
	end
	if type(self[id]) ~= 'number' then
	--print('defaulting['..tostring(id)..'] to '..type(default)..'('..tostring(default)..')')
		self[id] = default
	end
end
self.addNumberF = function(self, group, id, desc, default, minimum, maximum, onModify)
	if not groups[id] then
		local newGroup = self.addGroup(self, group, 'Defined By '..id)
		local newItem = {}
		groups[id] = newItem
		groups[#groups+1] = newItem
		newItem.group = newGroup
		newItem.id = id
		newItem.desc = desc
		newItem.isItem = true
		newItem.isNumberF = true
		newItem.default = default
		newItem.minimum = minimum
		newItem.maximum = maximum
		newItem.len = 8
		newItem.action = onModify
	end
	--print('addNumber: Group('..tostring(group)..') id('..tostring(id)..')')
	if self[id] and (type(self[id]) == 'string') and tonumber(self[id]) then
		self[id] = tonumber(self[id])
	end
	if type(self[id]) ~= 'number' then
	--print('defaulting['..tostring(id)..'] to '..type(default)..'('..tostring(default)..')')
		self[id] = default
	end
end
self.addBoolean = function(self, group, id, desc, default, onModify)
	if not groups[id] then
		local newGroup = self.addGroup(self, group, 'Defined By '..id)
		local newItem = {}
		groups[id] = newItem
		groups[#groups+1] = newItem
		newItem.group = newGroup
		newItem.id = id
		newItem.desc = desc
		newItem.isItem = true
		newItem.isBoolean = true
		newItem.default = default
		newItem.action = onModify
	end
	--print('addBoolean: Group('..tostring(group)..') id('..tostring(id)..')')
	if type(self[id]) ~= 'boolean' then
	--print('defaulting['..tostring(id)..'] to '..type(default)..'('..tostring(default)..')')
		self[id] = default
	end
end

	if not configXML then
		print('Failed To load config from '..file..' in '..dir)
		configXML = xmlapi:loadFile( file..'-Safe', dir )
	end
	
	if configXML then
		print('Config loaded from '..file..' in directory '..dir)
		actualConfig = xmlapi:simplify( configXML )
	else
		print('Failed to load '..file..' from '..dir)
		actualConfig = {}
	end

	--#### PREVENT READ AND WRITE ACCESS TO THE RETURNED TABLE
	local mt = self

	-- PREVENT WRITE ACCESS AND ABORT APPROPRIATELY
	mt.__newindex = function(table, key, value)
		local s,e,t,v = string.find(key, '(.+)%.(.+)')
		if t and v then
			if type(actualConfig[t]) == 'nil' then
print('_newindex:Creating config['..tostring(t)..'] table')
				actualConfig[t] = {}
			end
			if type(actualConfig[t]) == 'table' then
--print('_newindex:Setting config['..tostring(t)..']['..tostring(v)..'] to '..type(value)..'('..tostring(value)..')'..' was '..type(actualConfig[t][v])..'('..tostring(actualConfig[t][v])..')')
				local newValue = (type(actualConfig[t][v]) == 'nil') or (actualConfig[t][v] ~= value)
				configChanged = configChanged or newValue
				actualConfig[t][v] = value
			else
print('_newindex:Warning: NOT setting dotted['..tostring(t)..'].['..tostring(v)..'] to value('..tostring(value)..')')
			end
		else
--print('_newindex:Setting config['..tostring(key)..'] to '..type(value)..'('..tostring(value)..')'..' was '..type(actualConfig[key])..'('..tostring(actualConfig[key])..')')
			local newValue = (type(actualConfig[key]) == 'nil') or (actualConfig[key] ~= value)
			--[[if newValue then
				print(string.format("Set config object key %s to value %s (was %s)",
					tostring(key), 
					tostring(value),
					tostring(actualConfig[key])))
			end]]
			configChanged = configChanged or newValue
			actualConfig[key] = value
		end
	end

	-- PREVENT READ ACCESS AND ABORT APPROPRIATELY
	mt.__index = function(table, key)
		if type(key) ~= "function" then
			if type(actualConfig[key]) == 'nil' then
				local s,e,t,v = string.find(key, '(.+)%.(.+)')

				local info = debug.getinfo( 2, "Sl" )
				
				local where = info.source..':'..info.currentline
				if where:sub(1,1) == '@' then where = where:sub(2) end

				if t and v then
					if type(actualConfig[t]) == 'table' then
						if type(actualConfig[t][v]) == 'nil' then
print("index:Accessing UNDEFINED config["..t.."]["..v.."] (cAsE sEnSiTiVe!) from "..where)
						end
						return actualConfig[t][v]	-- may return nil
					else
print("index:Accessing Table-less config["..t.."]["..v.."] (cAsE sEnSiTiVe!) from "..where)
					end
				else
print("index:Accessing UNDEFINED config["..tostring(key).."] (cAsE sEnSiTiVe!) from "..where)
				end
			end
			return actualConfig[key]
			-- return actualConfig[key]
		end
	end

	-- WRITE NEW __index AND __newindex TO METATABLE
	setmetatable(self, mt)

	return self         --VERY IMPORTANT, RETURN ALL THE METHODS!
end

--[[do
	local fullpath = system.pathForFile( "", system.ResourceDirectory )
	for file in lfs.dir(fullpath) do
		print( "Found file: " .. file )
	end
end]]

return myConfig
